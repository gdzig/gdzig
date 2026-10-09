//! Validate measured compatibility manifests before emitting method binds.

pub const manifest: Metadata.Manifest = @import("generated/compatibility.zon");

/// Return owned legacy ranges and conventional adapter names for one API method.
/// This query describes measured layouts without requiring any adapter source.
pub fn groups(
    allocator: std.mem.Allocator,
    metadata: Metadata.Manifest,
    owner: []const u8,
    method: []const u8,
    zig_name: []const u8,
) !VersionDispatch.Groups {
    return VersionDispatch.collect(allocator, metadata, owner, method, zig_name, &.{});
}

fn tableFor(metadata: Metadata.Manifest, target: Metadata.Target) !Metadata.Table {
    for (metadata.tables) |table| {
        if (std.mem.eql(u8, table.id, target.table_id)) return table;
    }
    return error.MissingCompatibilityTable;
}

/// Reject malformed provenance and duplicate or dangling target/table identities.
pub fn validateManifest(metadata: Metadata.Manifest) !void {
    if (metadata.schema_version != 2) return error.UnsupportedCompatibilitySchema;
    try validateSource(metadata.current);
    if (metadata.current.checksum_kind != .raw_sha256) return error.InvalidCompatibilityProvenance;
    const current = try Records.exactVersion(metadata.current.version);

    for (metadata.tables, 0..) |table, index| {
        _ = try Records.exactVersion(table.id);
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
        const version = try Records.exactVersion(target.source.version);
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

fn validateSource(source: Metadata.Provenance) !void {
    _ = try Records.exactVersion(source.version);
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
pub fn validateOverridesAgainstApi(metadata: Metadata.Manifest, api: GodotApi) !void {
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

const VersionDispatch = @import("VersionDispatch.zig");
const Metadata = @import("CompatMetadata.zig");
const GodotApi = @import("GodotApi.zig");
const Records = @import("CompatRecords.zig");
