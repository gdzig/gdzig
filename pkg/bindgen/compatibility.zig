//! Validate measured compatibility manifests before emitting method binds.

/// Test fixture, including the generated-binding fixture executable.
/// Production queries receive the parsed input manifest explicitly.
pub const manifest: compat_manifest.Manifest = @import("generated/compatibility.zon");

/// Find the exact measured release, including aliases normalized by the parser.
pub fn findExactTarget(metadata: compat_manifest.Manifest, minimum: Version) !compat_manifest.Target {
    for (metadata.targets) |target| {
        const measured = try Version.parseStrict(target.source.version);
        if (minimum.major == measured.major and minimum.minor == measured.minor and
            minimum.patch == measured.patch) return target;
    }
    return error.UnsupportedCompatibilityMinimum;
}

fn tableFor(metadata: compat_manifest.Manifest, target: compat_manifest.Target) !compat_manifest.Table {
    for (metadata.tables) |table| {
        if (std.mem.eql(u8, table.id, target.table_id)) return table;
    }
    return error.MissingCompatibilityTable;
}

/// Require the measured current API header and raw bytes for minimum selection.
pub fn validateSnapshot(metadata: compat_manifest.Manifest, header: GodotApi.Header, checksum: []const u8) !void {
    const current = try Version.parseStrict(metadata.current.version);
    if (header.version_major != current.major or header.version_minor != current.minor or
        header.version_patch != current.patch or
        !std.mem.eql(u8, header.version_status, metadata.current.status) or
        !std.mem.eql(u8, header.version_build, metadata.current.build) or
        !std.mem.eql(u8, header.precision orelse "single", metadata.current.precision) or
        !std.mem.eql(u8, checksum, metadata.current.sha256))
    {
        return error.StaleCompatibilitySnapshot;
    }
}

/// Reject malformed provenance and duplicate or dangling target/table identities.
pub fn validateManifest(metadata: compat_manifest.Manifest) !void {
    if (metadata.schema_version != 3) return error.UnsupportedCompatibilitySchema;
    try validateSource(metadata.current);
    if (metadata.current.checksum_kind != .raw_sha256) return error.InvalidCompatibilityProvenance;
    const current = try records.exactVersion(metadata.current.version);

    for (metadata.tables, 0..) |table, index| {
        _ = try records.exactVersion(table.id);
        for (metadata.tables[0..index]) |previous| {
            if (std.mem.eql(u8, table.id, previous.id)) return error.DuplicateCompatibilityTable;
        }
        for (table.overrides, 0..) |record, record_index| {
            if (record.owner.len == 0 or record.method.len == 0 or record.old_hash == 0) {
                return error.InvalidCompatibilityOverride;
            }
            for (table.overrides[0..record_index]) |previous| {
                if (record.kind == previous.kind and
                    std.mem.eql(u8, record.owner, previous.owner) and
                    std.mem.eql(u8, record.method, previous.method))
                {
                    return error.DuplicateCompatibilityOverride;
                }
            }
        }
    }
    for (metadata.targets, 0..) |target, index| {
        try validateSource(target.source);
        const version = try records.exactVersion(target.source.version);
        switch (version.order(current)) {
            .gt => return error.InvalidCompatibilityProvenance,
            .eq => {
                if (target.source.checksum_kind != .raw_sha256 or
                    !std.mem.eql(u8, target.source.sha256, metadata.current.sha256))
                {
                    return error.InvalidCompatibilityProvenance;
                }
            },
            .lt => {
                if (target.source.checksum_kind != .historical_classes_sha256) {
                    return error.InvalidCompatibilityProvenance;
                }
            },
        }
        for (metadata.targets[0..index]) |previous| {
            if (std.mem.eql(u8, target.source.version, previous.source.version)) {
                return error.DuplicateCompatibilityTarget;
            }
        }
        _ = try tableFor(metadata, target);
    }
}

fn validateSource(source: compat_manifest.Provenance) !void {
    _ = try records.exactVersion(source.version);
    if (!std.mem.eql(u8, source.status, "stable") or
        !std.mem.eql(u8, source.build, "official") or
        !std.mem.eql(u8, source.precision, "single") or source.sha256.len != 64)
    {
        return error.InvalidCompatibilityProvenance;
    }
    for (source.sha256) |byte| {
        if (!(std.ascii.isDigit(byte) or (byte >= 'a' and byte <= 'f'))) {
            return error.InvalidCompatibilityProvenance;
        }
    }
}

/// Check sparse legacy hashes against the current API's compatibility evidence.
pub fn validateOverridesAgainstApi(metadata: compat_manifest.Manifest, api: GodotApi) !void {
    try validateManifest(metadata);
    for (metadata.tables) |table| {
        for (table.overrides) |record| {
            var matched = false;
            switch (record.kind) {
                .class => for (api.classes) |owner| {
                    if (!std.mem.eql(u8, owner.name, record.owner)) continue;
                    for (owner.methods orelse &.{}) |method| {
                        if (!std.mem.eql(u8, method.name, record.method)) continue;
                        if (method.is_virtual or !validOldHash(
                            method.hash,
                            method.hash_compatibility orelse &.{},
                            record.old_hash,
                        )) return error.InvalidCompatibilityOverride;
                        matched = true;
                    }
                },
                .builtin => for (api.builtin_classes) |owner| {
                    if (!std.mem.eql(u8, owner.name, record.owner)) continue;
                    for (owner.methods orelse &.{}) |method| {
                        if (!std.mem.eql(u8, method.name, record.method)) continue;
                        if (!validOldHash(
                            method.hash,
                            method.hash_compatibility orelse &.{},
                            record.old_hash,
                        )) return error.InvalidCompatibilityOverride;
                        matched = true;
                    }
                },
            }
            if (!matched) return error.InvalidCompatibilityOverride;
        }
    }
}

fn validOldHash(primary: ?u64, compatible: []const u64, old: u64) bool {
    return primary != old and std.mem.indexOfScalar(u64, compatible, old) != null;
}

/// Select only an ABI-compatible legacy hash; generated dispatch owns shim layouts.
pub fn lookupOverride(
    metadata: compat_manifest.Manifest,
    target: compat_manifest.Target,
    kind: records.Kind,
    owner: []const u8,
    method: []const u8,
    primary: u64,
) !u64 {
    const table = try tableFor(metadata, target);
    for (table.overrides) |record| {
        if (record.kind == kind and std.mem.eql(u8, record.owner, owner) and
            std.mem.eql(u8, record.method, method))
        {
            return switch (record.layout) {
                .identical, .trailing_defaults, .abi_compatible => record.old_hash,
                .incompatible, .return_added => primary,
            };
        }
    }
    return primary;
}

test "minimum selection skips shim layouts and preserves absent modern methods" {
    const target = manifest.targets[0];
    const table = try tableFor(manifest, target);
    for (table.overrides) |record| {
        const expected: u64 = switch (record.layout) {
            .identical, .trailing_defaults, .abi_compatible => record.old_hash,
            .incompatible, .return_added => 999,
        };
        try std.testing.expectEqual(expected, try lookupOverride(
            manifest,
            target,
            record.kind,
            record.owner,
            record.method,
            999,
        ));
    }
    try std.testing.expectEqual(@as(u64, 999), try lookupOverride(
        manifest,
        target,
        .class,
        "Node",
        "new_method_not_in_older_api",
        999,
    ));
}

test "every measured target resolves exactly without inferring support from table identity" {
    for (manifest.targets) |target| {
        const minimum = try Version.parseStrict(target.source.version);
        const selected = try findExactTarget(manifest, minimum);
        try std.testing.expectEqualStrings(target.source.version, selected.source.version);
        try std.testing.expectEqualStrings(target.table_id, selected.table_id);
    }
    const alias = try findExactTarget(manifest, try Version.parseStrict("4.6"));
    try std.testing.expectEqualStrings("4.6.0", alias.source.version);
    try std.testing.expectError(
        error.UnsupportedCompatibilityMinimum,
        findExactTarget(manifest, Version.parse("4.6.99")),
    );
}

test "minimum snapshot rejects changed header family and raw checksum" {
    var header: GodotApi.Header = .{
        .version_major = 4,
        .version_minor = 7,
        .version_patch = 2,
        .version_status = "stable",
        .version_build = "official",
        .version_full_name = "Godot Engine v4.7.2.stable.official",
    };
    try validateSnapshot(manifest, header, manifest.current.sha256);
    header.version_minor = 8;
    try std.testing.expectError(
        error.StaleCompatibilitySnapshot,
        validateSnapshot(manifest, header, manifest.current.sha256),
    );
    header.version_minor = 7;
    try std.testing.expectError(error.StaleCompatibilitySnapshot, validateSnapshot(manifest, header, "changed"));
}

test "sparse hashes must be distinct measured compatibility members" {
    try std.testing.expect(validOldHash(202, &.{101}, 101));
    try std.testing.expect(!validOldHash(101, &.{101}, 101));
    try std.testing.expect(!validOldHash(202, &.{101}, 303));
}

test "manifest validation rejects malformed schema and dangling tables" {
    var fixture = manifest;
    fixture.schema_version = 999;
    try std.testing.expectError(error.UnsupportedCompatibilitySchema, validateManifest(fixture));
    fixture = manifest;
    fixture.tables = &.{};
    try std.testing.expectError(error.MissingCompatibilityTable, validateManifest(fixture));
}

const std = @import("std");

const compat_manifest = @import("compat").manifest;
const GodotApi = @import("common").GodotApi;
const records = @import("compat").records;
const Version = @import("common").Version;
