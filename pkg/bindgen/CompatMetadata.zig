pub const Override = struct {
    kind: Records.Kind,
    owner: []const u8,
    method: []const u8,
    old_hash: u64,
    layout: MethodLayout.Class,
    added_arguments: []const []const u8 = &.{},
    layout_diff: ?[]const u8 = null,
    old_arguments: ?[]const Records.Argument = null,
    old_return: ?Records.Return = null,
    old_flags: ?Flags = null,
};

pub const Flags = struct {
    is_const: bool,
    is_static: bool,
    is_vararg: bool,
};

pub const Audit = struct {
    kind: Records.Kind,
    owner: []const u8,
    method: []const u8,
    primary: u64,
    old_hash: ?u64,
    compatibility: []const u64,
};

pub const Comparison = struct {
    overrides: []const Override,
    virtual: []const Audit,
    absent: []const Audit,
    multi_compat: []const Audit,
    unresolved: []const Audit,
};

pub const ChecksumKind = enum {
    raw_sha256,
    historical_classes_sha256,
};

pub const Provenance = struct {
    version: []const u8,
    sha256: []const u8,
    checksum_kind: ChecksumKind,
    status: []const u8,
    build: []const u8,
    precision: []const u8,
};

pub const Target = struct {
    source: Provenance,
    table_id: []const u8,
};

pub const Table = struct {
    id: []const u8,
    overrides: []const Override,
};

pub const Manifest = struct {
    schema_version: u32 = 2,
    current: Provenance,
    targets: []const Target,
    tables: []const Table,
};

pub const Mode = enum {
    overwrite,
    append,
};

const Row = struct {
    source: Provenance,
    overrides: []const Override,
    version: std.SemanticVersion,
};

/// Use raw provenance for current snapshots and normalized content for history.
pub fn provenance(snapshot: Records.Snapshot, historical: bool) Provenance {
    return .{
        .version = snapshot.version,
        .sha256 = if (historical) snapshot.classes_sha256 else snapshot.raw_sha256,
        .checksum_kind = if (historical) .historical_classes_sha256 else .raw_sha256,
        .status = snapshot.status,
        .build = snapshot.build,
        .precision = snapshot.precision,
    };
}

/// Compare extracted hashes and layouts, retaining every measured ABI difference.
pub fn compare(
    allocator: Allocator,
    older: []const Records.Record,
    current: []const Records.Record,
    old_enums: []const Records.Enum,
    new_enums: []const Records.Enum,
) !Comparison {
    try validateRecords(older);
    try validateRecords(current);
    var overrides: std.ArrayList(Override) = .empty;
    var virtual: std.ArrayList(Audit) = .empty;
    var absent: std.ArrayList(Audit) = .empty;
    var multi: std.ArrayList(Audit) = .empty;
    var unresolved: std.ArrayList(Audit) = .empty;
    var old_index: usize = 0;
    for (current) |record| {
        if (record.virtual and record.hash == 0) continue;
        while (old_index < older.len and
            Records.lessRecord({}, older[old_index], record)) : (old_index += 1)
        {}
        const found = old_index < older.len and Records.sameIdentity(older[old_index], record);
        const previous: ?Records.Record = if (found) older[old_index] else null;
        const row: Audit = .{
            .kind = record.kind,
            .owner = record.owner,
            .method = record.method,
            .primary = record.hash,
            .old_hash = if (previous) |p| p.hash else null,
            .compatibility = record.compatibility,
        };
        if (record.compatibility.len > 1) try multi.append(allocator, row);
        if (previous) |p| {
            if (p.virtual != record.virtual) return error.MethodLayoutMismatch;
            if (p.hash == record.hash) continue;
            if (record.virtual) {
                try virtual.append(allocator, row);
                continue;
            }
            if (std.mem.indexOfScalar(u64, record.compatibility, p.hash) == null) {
                return error.MissingCompatibilityEvidence;
            }
            const layout = try MethodLayout.classify(allocator, p, record, old_enums, new_enums);
            var override: Override = .{
                .kind = record.kind,
                .owner = record.owner,
                .method = record.method,
                .old_hash = p.hash,
                .layout = std.meta.activeTag(layout),
            };
            // Preserve the serialized cache while consuming only the active payload.
            switch (layout) {
                .identical => {},
                .trailing_defaults => |details| {
                    override.added_arguments = details.added_arguments;
                },
                .abi_compatible => |reason| {
                    override.layout_diff = switch (reason) {
                        .const_flag => "const",
                        .renamed_enum => "enum_renamed",
                    };
                },
                .incompatible => |diff| override.layout_diff = diff,
                .return_added => {
                    const old_return = p.@"return" orelse Records.Return{ .type = "void", .meta = "" };
                    const new_return = record.@"return" orelse Records.Return{ .type = "void", .meta = "" };
                    override.layout_diff = try std.fmt.allocPrint(
                        allocator,
                        "return: {s}/{s} -> {s}/{s}",
                        .{ old_return.type, old_return.meta, new_return.type, new_return.meta },
                    );
                },
            }
            if (layout == .incompatible or layout == .return_added) {
                override.old_arguments = p.arguments;
                override.old_return = p.@"return";
                override.old_flags = .{
                    .is_const = p.is_const,
                    .is_static = p.is_static,
                    .is_vararg = p.is_vararg,
                };
            }
            try overrides.append(allocator, override);
        } else {
            try absent.append(allocator, row);
            if (record.compatibility.len > 0) try unresolved.append(allocator, row);
        }
    }
    return .{
        .overrides = try overrides.toOwnedSlice(allocator),
        .virtual = try virtual.toOwnedSlice(allocator),
        .absent = try absent.toOwnedSlice(allocator),
        .multi_compat = try multi.toOwnedSlice(allocator),
        .unresolved = try unresolved.toOwnedSlice(allocator),
    };
}

fn validateRecords(records: []const Records.Record) !void {
    for (records, 0..) |record, i| {
        if (i == 0) continue;
        if (Records.sameIdentity(records[i - 1], record)) return error.DuplicateIdentity;
        if (!Records.lessRecord({}, records[i - 1], record)) return error.UnsortedRecords;
    }
}

/// Overwrite with one target or append/replace a target, canonicalizing all tables.
pub fn merge(
    allocator: Allocator,
    current: Records.Snapshot,
    old: Records.Snapshot,
    mode: Mode,
    input: ?Manifest,
) !Manifest {
    // Validate the mode and the requested release before carrying previous targets.
    if (mode == .overwrite and input != null) return error.UnexpectedInput;
    if (mode == .append and input == null) return error.MissingInput;
    const current_version = try Records.exactVersion(current.version);
    const old_version = try Records.exactVersion(old.version);
    if (old_version.order(current_version) == .gt) return error.TargetNewerThanCurrent;

    // Retain every previous target except the release being replaced.
    var rows: std.ArrayList(Row) = .empty;
    if (input) |previous| {
        if (previous.schema_version != 2) return error.UnsupportedSchema;
        const matches = std.mem.eql(u8, previous.current.version, current.version) and
            std.mem.eql(u8, previous.current.sha256, current.raw_sha256) and
            previous.current.checksum_kind == .raw_sha256;
        if (!matches) return error.CurrentSnapshotMismatch;
        for (previous.targets) |target| {
            if (std.mem.eql(u8, target.source.version, old.version)) continue;
            var overrides: ?[]const Override = null;
            for (previous.tables) |table| {
                if (std.mem.eql(u8, target.table_id, table.id)) overrides = table.overrides;
            }
            try rows.append(allocator, .{
                .source = target.source,
                .overrides = overrides orelse return error.InvalidManifest,
                .version = try Records.exactVersion(target.source.version),
            });
        }
    }

    // Add the measured target, then sort releases into canonical order.
    const comparison = try compare(allocator, old.records, current.records, old.enums, current.enums);
    if (comparison.unresolved.len > 0) return error.UnresolvedCompatibilityEvidence;
    try rows.append(allocator, .{
        .source = provenance(old, !std.mem.eql(u8, old.version, current.version)),
        .overrides = comparison.overrides,
        .version = old_version,
    });
    std.mem.sort(Row, rows.items, {}, lessRow);

    // Share identical override tables using their first canonical release as the ID.
    var targets: std.ArrayList(Target) = .empty;
    var tables: std.ArrayList(Table) = .empty;
    for (rows.items, 0..) |row, i| {
        if (i > 0 and rows.items[i - 1].version.order(row.version) == .eq) {
            return error.DuplicateTarget;
        }
        var table_id: ?[]const u8 = null;
        for (tables.items) |table| {
            if (sameOverrides(table.overrides, row.overrides)) {
                table_id = table.id;
                break;
            }
        }
        if (table_id == null) {
            table_id = row.source.version;
            try tables.append(allocator, .{ .id = table_id.?, .overrides = row.overrides });
        }
        try targets.append(allocator, .{ .source = row.source, .table_id = table_id.? });
    }
    return .{
        .current = provenance(current, false),
        .targets = try targets.toOwnedSlice(allocator),
        .tables = try tables.toOwnedSlice(allocator),
    };
}

fn lessRow(_: void, a: Row, b: Row) bool {
    return a.version.order(b.version) == .lt;
}

fn sameOverrides(a: []const Override, b: []const Override) bool {
    if (a.len != b.len) return false;
    for (a, b) |left, right| {
        if (left.kind != right.kind or left.old_hash != right.old_hash or
            left.layout != right.layout or
            !std.mem.eql(u8, left.owner, right.owner) or
            !std.mem.eql(u8, left.method, right.method)) return false;
        if (!std.meta.eql(left.layout_diff, right.layout_diff)) {
            const left_diff = left.layout_diff orelse return false;
            const right_diff = right.layout_diff orelse return false;
            if (!std.mem.eql(u8, left_diff, right_diff)) return false;
        }
        if (left.added_arguments.len != right.added_arguments.len) return false;
        for (left.added_arguments, right.added_arguments) |before, after| {
            if (!std.mem.eql(u8, before, after)) return false;
        }
        // Compare nested signature text by value, not borrowed slice addresses.
        if (!sameSignature(left, right)) return false;
    }
    return true;
}

fn sameSignature(left: Override, right: Override) bool {
    if (!std.meta.eql(left.old_flags, right.old_flags)) return false;
    if ((left.old_return == null) != (right.old_return == null)) return false;
    if (left.old_return) |before| {
        const after = right.old_return.?;
        if (!std.mem.eql(u8, before.type, after.type) or
            !std.mem.eql(u8, before.meta, after.meta))
        {
            return false;
        }
    }
    if ((left.old_arguments == null) != (right.old_arguments == null)) return false;
    const before = left.old_arguments orelse return true;
    const after = right.old_arguments.?;
    if (before.len != after.len) return false;
    for (before, after) |a, b| {
        if (!std.mem.eql(u8, a.name, b.name) or
            !std.mem.eql(u8, a.type, b.type) or
            !std.mem.eql(u8, a.meta, b.meta) or
            a.has_default != b.has_default)
        {
            return false;
        }
    }
    return true;
}

/// Write generated ZON with its reproducible maintenance command.
pub fn writeManifest(writer: *std.Io.Writer, manifest: Manifest) !void {
    try writer.writeAll("// Generated by zig build update-compat-metadata -Dold=all. Do not edit.\n");
    try std.zon.stringify.serialize(manifest, .{}, writer);
    try writer.writeByte('\n');
}

/// Return a named error when a candidate differs from the expected cache bytes.
pub fn checkExpected(actual: []const u8, expected: []const u8) !void {
    if (!std.mem.eql(u8, actual, expected)) return error.StaleCompatibilityMetadata;
}

fn fixtureSnapshot(version: []const u8, records: []const Records.Record) Records.Snapshot {
    return .{
        .version = version,
        .status = "stable",
        .build = "official",
        .precision = "single",
        .raw_sha256 = "raw",
        .classes_sha256 = "classes",
        .records = records,
        .enums = &.{},
    };
}

fn fixtureRecord(hash: u64, compatibility: []const u64) Records.Record {
    return .{
        .kind = .class,
        .owner = "Owner",
        .method = "method",
        .hash = hash,
        .compatibility = compatibility,
        .virtual = false,
        .is_const = false,
        .is_static = false,
        .is_vararg = false,
        .arguments = &.{},
        .@"return" = null,
    };
}

test "shim-layout overrides serialize their original signature and flags" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var old = fixtureRecord(101, &.{});
    old.arguments = &.{.{ .name = "value", .type = "String" }};
    var modern = fixtureRecord(202, &.{101});
    modern.arguments = &.{.{ .name = "value", .type = "StringName" }};
    const manifest = try merge(
        allocator,
        fixtureSnapshot("4.7.2", &.{modern}),
        fixtureSnapshot("4.6.0", &.{old}),
        .overwrite,
        null,
    );
    var output: std.Io.Writer.Allocating = .init(allocator);
    try writeManifest(&output.writer, manifest);
    try std.testing.expect(std.mem.indexOf(u8, output.written(), ".old_arguments") != null);
    try std.testing.expect(std.mem.indexOf(u8, output.written(), ".old_flags") != null);
    try std.testing.expect(std.mem.indexOf(u8, output.written(), "\"String\"") != null);
}

test "merge overwrite append replacement table cleanup and order-independent bytes" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const current = fixtureSnapshot("4.7.2", &.{fixtureRecord(202, &.{ 101, 303 })});
    const first = fixtureSnapshot("4.6.0", &.{fixtureRecord(101, &.{})});
    const second = fixtureSnapshot("4.6.1", &.{fixtureRecord(101, &.{})});
    const changed = fixtureSnapshot("4.6.0", &.{fixtureRecord(303, &.{})});
    const one = try merge(a, current, first, .overwrite, null);
    const two = try merge(a, current, second, .append, one);
    const reverse = try merge(a, current, first, .append, try merge(a, current, second, .overwrite, null));
    var left: std.Io.Writer.Allocating = .init(a);
    var right: std.Io.Writer.Allocating = .init(a);
    try writeManifest(&left.writer, two);
    try writeManifest(&right.writer, reverse);
    try std.testing.expectEqualStrings(left.written(), right.written());
    try std.testing.expectEqual(@as(usize, 1), two.tables.len);
    try std.testing.expectEqualStrings("4.6.0", two.tables[0].id);
    const replaced = try merge(a, current, changed, .append, one);
    try std.testing.expectEqual(@as(usize, 1), replaced.targets.len);
    try std.testing.expectEqual(@as(usize, 1), replaced.tables.len);
    try std.testing.expectEqual(@as(u64, 303), replaced.tables[0].overrides[0].old_hash);
    try std.testing.expectError(error.UnexpectedInput, merge(a, current, first, .overwrite, one));
    try std.testing.expectError(error.MissingInput, merge(a, current, first, .append, null));
    var mismatch = current;
    mismatch.raw_sha256 = "changed";
    try std.testing.expectError(error.CurrentSnapshotMismatch, merge(a, mismatch, first, .append, one));
    mismatch = current;
    mismatch.version = "4.7.1";
    try std.testing.expectError(error.CurrentSnapshotMismatch, merge(a, mismatch, first, .append, one));
    try std.testing.expectError(error.TargetNewerThanCurrent, merge(a, current, fixtureSnapshot("4.8.0", first.records), .overwrite, null));
}

test "hash comparison preserves primary membership virtual absent multi and duplicate rules" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const current = [_]Records.Record{fixtureRecord(202, &.{ 101, 303 })};
    const old = [_]Records.Record{fixtureRecord(101, &.{})};
    const result = try compare(a, &old, &current, &.{}, &.{});
    try std.testing.expectEqual(@as(u64, 101), result.overrides[0].old_hash);
    try std.testing.expectEqual(@as(usize, 1), result.multi_compat.len);
    try std.testing.expectEqual(@as(usize, 0), (try compare(a, &current, &current, &.{}, &.{})).overrides.len);
    try std.testing.expectError(error.MissingCompatibilityEvidence, compare(a, &old, &.{fixtureRecord(202, &.{303})}, &.{}, &.{}));
    try std.testing.expectError(error.DuplicateIdentity, compare(a, &.{ old[0], old[0] }, &current, &.{}, &.{}));
    var virtual = current[0];
    virtual.virtual = true;
    var old_virtual = old[0];
    old_virtual.virtual = true;
    try std.testing.expectEqual(@as(usize, 1), (try compare(a, &.{old_virtual}, &.{virtual}, &.{}, &.{})).virtual.len);
    const absent = try compare(a, &.{}, &current, &.{}, &.{});
    try std.testing.expectEqual(@as(usize, 1), absent.absent.len);
    try std.testing.expectEqual(@as(usize, 1), absent.unresolved.len);
    try checkExpected("candidate", "candidate");
    try std.testing.expectError(error.StaleCompatibilityMetadata, checkExpected("candidate", "candidatf"));
}

test "return-added union classification preserves serialized diff and legacy flags" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const old = fixtureRecord(101, &.{});
    var current = fixtureRecord(202, &.{101});
    current.@"return" = .{ .type = "bool", .meta = "" };
    const result = try compare(arena.allocator(), &.{old}, &.{current}, &.{}, &.{});
    const override = result.overrides[0];
    try std.testing.expectEqual(MethodLayout.Class.return_added, override.layout);
    try std.testing.expectEqualStrings("return: void/ -> bool/", override.layout_diff.?);
    try std.testing.expectEqual(@as(usize, 0), override.old_arguments.?.len);
    try std.testing.expect(override.old_return == null);
    try std.testing.expect(!override.old_flags.?.is_static);

    current.@"return" = null;
    current.is_const = true;
    const const_result = try compare(arena.allocator(), &.{old}, &.{current}, &.{}, &.{});
    try std.testing.expectEqualStrings("const", const_result.overrides[0].layout_diff.?);
    try std.testing.expect(const_result.overrides[0].old_flags == null);
}

const std = @import("std");
const Allocator = std.mem.Allocator;

const Records = @import("CompatRecords.zig");
const MethodLayout = @import("MethodLayout.zig");
