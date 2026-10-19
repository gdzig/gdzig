/// One measured method hash with exactly the data required by its layout.
pub const Override = struct {
    kind: records.Kind,
    owner: []const u8,
    method: []const u8,
    old_hash: u64,
    layout: Layout,
};

/// A measured layout with only its corresponding payload.
pub const Layout = union(enum) {
    identical,
    trailing_defaults: struct {
        added_arguments: []const []const u8,
    },
    abi_compatible: method_layout.Reason,
    return_added: Legacy,
    incompatible: Legacy,

    /// Retain a classifier result and the original signature for adapter layouts.
    pub fn fromResult(
        allocator: Allocator,
        result: method_layout.Result,
        previous: records.Record,
        current: records.Record,
    ) !Layout {
        return switch (result) {
            .identical => .identical,
            .trailing_defaults => |details| .{
                .trailing_defaults = .{
                    .added_arguments = details.added_arguments,
                },
            },
            .abi_compatible => |reason| .{ .abi_compatible = reason },
            .incompatible => |difference| .{ .incompatible = .fromRecord(previous, difference) },
            .return_added => blk: {
                const before = previous.@"return" orelse records.Return{ .type = "void", .meta = "" };
                const after = current.@"return" orelse records.Return{ .type = "void", .meta = "" };
                const difference = try std.fmt.allocPrint(
                    allocator,
                    "return: {s}/{s} -> {s}/{s}",
                    .{ before.type, before.meta, after.type, after.meta },
                );
                break :blk .{ .return_added = .fromRecord(previous, difference) };
            },
        };
    }
};

/// The old signature, needed to emit a legacy binding.
pub const Legacy = struct {
    difference: []const u8,
    arguments: []const records.Argument,
    @"return": ?records.Return,
    flags: Flags,

    /// Preserve the positional signature and flags of one extracted method.
    pub fn fromRecord(record: records.Record, difference: []const u8) Legacy {
        return .{
            .difference = difference,
            .arguments = record.arguments,
            .@"return" = record.@"return",
            .flags = .{
                .is_const = record.is_const,
                .is_static = record.is_static,
                .is_vararg = record.is_vararg,
            },
        };
    }
};

/// Calling flags of the measured old method.
pub const Flags = struct {
    is_const: bool,
    is_static: bool,
    is_vararg: bool,
};

/// Method hash evidence that is not a selected override.
pub const Audit = struct {
    kind: records.Kind,
    owner: []const u8,
    method: []const u8,
    primary: u64,
    old_hash: ?u64,
    compatibility: []const u64,
};

/// How a snapshot provenance checksum was computed.
pub const ChecksumKind = enum {
    raw_sha256,
    historical_classes_sha256,
};

/// One measured release and the table it selects.
pub const Target = struct {
    source: Provenance,
    table_id: []const u8,
};

/// A shared set of canonical method overrides.
pub const Table = struct {
    id: []const u8,
    overrides: []const Override,
};

/// Whether to replace the cache or append one measured release.
pub const Mode = enum {
    overwrite,
    append,
};

/// The interface names a release's own header lacks, measured as a delta.
pub const InterfaceTable = struct {
    id: []const u8,
    not_in_snapshot: []const []const u8,
};

const Row = struct {
    source: Provenance,
    overrides: []const Override,
    not_in_snapshot: []const []const u8,
    version: std.SemanticVersion,
};

/// Snapshot identity and precision used to establish measured hashes.
pub const Provenance = struct {
    version: []const u8,
    sha256: []const u8,
    checksum_kind: ChecksumKind,
    status: []const u8,
    build: []const u8,
    precision: []const u8,

    /// Use raw provenance for current snapshots and normalized content for history.
    pub fn fromSnapshot(snapshot: records.Snapshot, historical: bool) Provenance {
        return .{
            .version = snapshot.version,
            .sha256 = if (historical) snapshot.classes_sha256 else snapshot.raw_sha256,
            .checksum_kind = if (historical) .historical_classes_sha256 else .raw_sha256,
            .status = snapshot.status,
            .build = snapshot.build,
            .precision = snapshot.precision,
        };
    }
};

/// Measured overrides and complete comparison evidence.
pub const Comparison = struct {
    overrides: []const Override,
    virtual: []const Audit,
    absent: []const Audit,
    multi_compat: []const Audit,
    unresolved: []const Audit,

    /// Compare extracted hashes and layouts, retaining every measured ABI difference.
    pub fn compare(
        allocator: Allocator,
        older: []const records.Record,
        current: []const records.Record,
        old_enums: []const records.Enum,
        new_enums: []const records.Enum,
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
                records.lessRecord({}, older[old_index], record)) : (old_index += 1)
            {}
            const found = old_index < older.len and records.sameIdentity(older[old_index], record);
            const previous: ?records.Record = if (found) older[old_index] else null;
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
                const result = try method_layout.classify(allocator, p, record, old_enums, new_enums);
                try overrides.append(allocator, .{
                    .kind = record.kind,
                    .owner = record.owner,
                    .method = record.method,
                    .old_hash = p.hash,
                    .layout = try .fromResult(allocator, result, p, record),
                });
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
};

fn validateRecords(items: []const records.Record) !void {
    for (items, 0..) |record, i| {
        if (i == 0) continue;
        if (records.sameIdentity(items[i - 1], record)) return error.DuplicateIdentity;
        if (!records.lessRecord({}, items[i - 1], record)) return error.UnsortedRecords;
    }
}

/// Canonical schema-four compatibility cache consumed by bindgen.
pub const Manifest = struct {
    schema_version: u32 = 4,
    current: Provenance,
    /// Digest of the current header's sorted interface names.
    current_interfaces_sha256: []const u8 = "",
    targets: []const Target,
    interfaces: []const InterfaceTable = &.{},
    tables: []const Table,

    /// Overwrite with one target or append/replace a target, canonicalizing all tables.
    pub fn merge(
        allocator: Allocator,
        current: records.Snapshot,
        old: records.Snapshot,
        mode: Mode,
        input: ?Manifest,
    ) !Manifest {
        // Validate the mode and the requested release before carrying previous targets.
        if (mode == .overwrite and input != null) return error.UnexpectedInput;
        if (mode == .append and input == null) return error.MissingInput;
        const current_version = try records.exactVersion(current.version);
        const old_version = try records.exactVersion(old.version);
        if (old_version.order(current_version) == .gt) return error.TargetNewerThanCurrent;
        if (input) |previous| {
            if (previous.schema_version != 4) return error.UnsupportedSchema;
            const matches = std.mem.eql(u8, previous.current.version, current.version) and
                std.mem.eql(u8, previous.current.sha256, current.raw_sha256) and
                previous.current.checksum_kind == .raw_sha256;
            if (!matches) return error.CurrentSnapshotMismatch;
        }

        // Measure the interface evidence before touching previous targets.
        const current_interfaces = try requireInterfaces(allocator, current.interfaces);
        const old_interfaces = try requireInterfaces(allocator, old.interfaces);
        const current_digest = try interface_names.digest(allocator, current_interfaces);
        if (input) |previous| {
            if (!std.mem.eql(u8, previous.current_interfaces_sha256, current_digest)) {
                return error.InterfaceSnapshotMismatch;
            }
        }

        // Retain every previous target except the release being replaced.
        var rows: std.ArrayList(Row) = .empty;
        if (input) |previous| {
            for (previous.targets) |target| {
                if (std.mem.eql(u8, target.source.version, old.version)) continue;
                var overrides: ?[]const Override = null;
                for (previous.tables) |table| {
                    if (std.mem.eql(u8, target.table_id, table.id)) overrides = table.overrides;
                }
                const delta = previous.tableDelta(target.table_id) orelse
                    return error.InvalidInterfaceEvidence;
                try rows.append(allocator, .{
                    .source = target.source,
                    .overrides = overrides orelse return error.InvalidManifest,
                    .not_in_snapshot = delta,
                    .version = try records.exactVersion(target.source.version),
                });
            }
        }

        // Add the measured target, then sort releases into canonical order.
        const comparison = try Comparison.compare(allocator, old.records, current.records, old.enums, current.enums);
        if (comparison.unresolved.len > 0) return error.UnresolvedCompatibilityEvidence;
        try rows.append(allocator, .{
            .source = .fromSnapshot(old, !std.mem.eql(u8, old.version, current.version)),
            .overrides = comparison.overrides,
            .not_in_snapshot = try interface_names.delta(allocator, current_interfaces, old_interfaces),
            .version = old_version,
        });
        std.mem.sort(Row, rows.items, {}, lessRow);

        // Share a table only when both its overrides and its interface delta match.
        var targets: std.ArrayList(Target) = .empty;
        var tables: std.ArrayList(Table) = .empty;
        var interfaces: std.ArrayList(InterfaceTable) = .empty;
        for (rows.items, 0..) |row, i| {
            if (i > 0 and rows.items[i - 1].version.order(row.version) == .eq) {
                return error.DuplicateTarget;
            }
            var shared: ?usize = null;
            for (tables.items, interfaces.items, 0..) |table, evidence, index| {
                if (sameOverrides(table.overrides, row.overrides) and
                    interface_names.same(evidence.not_in_snapshot, row.not_in_snapshot))
                {
                    shared = index;
                    break;
                }
            }
            if (shared == null) {
                shared = tables.items.len;
                try tables.append(allocator, .{ .id = row.source.version, .overrides = row.overrides });
                try interfaces.append(allocator, .{
                    .id = row.source.version,
                    .not_in_snapshot = row.not_in_snapshot,
                });
            }
            try targets.append(allocator, .{
                .source = row.source,
                .table_id = tables.items[shared.?].id,
            });
        }
        const result: Manifest = .{
            .current = .fromSnapshot(current, false),
            .current_interfaces_sha256 = current_digest,
            .targets = try targets.toOwnedSlice(allocator),
            .interfaces = try interfaces.toOwnedSlice(allocator),
            .tables = try tables.toOwnedSlice(allocator),
        };
        try result.validateInterfaceShape();
        return result;
    }

    /// Resolve one interface against the measured target window.
    pub fn interfaceAvailability(self: Manifest, name: []const u8) !InterfaceAvailability {
        const current = try Version.parseStrict(self.current.version);
        var last_absent: ?Version = null;
        var gate: ?Version = null;
        for (self.targets) |target| {
            const version = try Version.parseStrict(target.source.version);
            const delta = self.tableDelta(target.table_id) orelse
                return error.InvalidInterfaceEvidence;
            if (interface_names.contains(delta, name)) {
                last_absent = version;
            } else if (gate == null) {
                gate = version;
            }
        }
        return .{
            // No measured release provides it, so never imply support.
            .gate = gate orelse current,
            .last_absent = last_absent,
            .present_in_oldest = last_absent == null,
        };
    }

    /// Cross-check one header `@since` tag against the measured interval.
    pub fn resolveInterface(
        self: Manifest,
        name: []const u8,
        since_text: []const u8,
    ) !InterfaceGate {
        const tag = try parseSinceTag(since_text);
        const availability = try self.interfaceAvailability(name);
        if (availability.last_absent) |absent| {
            if (tag.has_patch) {
                if (!tag.version.gt(absent)) return error.InterfaceAvailabilityDisagreement;
            } else if (minorOrder(tag.version, absent) == .lt) {
                return error.InterfaceAvailabilityDisagreement;
            }
        }
        if (tag.has_patch) {
            if (tag.version.gt(availability.gate)) return error.InterfaceAvailabilityDisagreement;
        } else if (minorOrder(tag.version, availability.gate) == .gt) {
            return error.InterfaceAvailabilityDisagreement;
        }
        return .{
            .gate = availability.gate,
            .required = availability.present_in_oldest and tag.version.eql(required_interface_version),
        };
    }

    /// Reject malformed schema-four evidence, dangling tables and non-monotonic deltas.
    pub fn validateInterfaceShape(self: Manifest) !void {
        if (self.schema_version != 4) return error.UnsupportedSchema;
        try validateDigest(self.current_interfaces_sha256);
        if (self.interfaces.len != self.tables.len) return error.InvalidInterfaceEvidence;
        for (self.interfaces, self.tables, 0..) |evidence, table, index| {
            if (!std.mem.eql(u8, evidence.id, table.id)) return error.InvalidInterfaceEvidence;
            for (self.tables[0..index]) |previous| {
                if (std.mem.eql(u8, table.id, previous.id)) return error.InvalidInterfaceEvidence;
            }
            try validateDelta(evidence.not_in_snapshot);
        }

        // Availability only ever grows, so a newer target cannot drop a name.
        var newer: ?[]const []const u8 = null;
        for (self.targets) |target| {
            const delta = self.tableDelta(target.table_id) orelse
                return error.InvalidInterfaceEvidence;
            if (newer) |older| {
                for (delta) |name| {
                    if (!interface_names.contains(older, name)) {
                        return error.NonMonotonicInterfaceEvidence;
                    }
                }
            }
            newer = delta;
        }
    }

    /// Check one parsed header against the measured manifest evidence.
    pub fn validateInterfaces(
        self: Manifest,
        allocator: Allocator,
        names: []const []const u8,
    ) !void {
        const parsed = try interface_names.canonicalize(allocator, names);
        const digest = try interface_names.digest(allocator, parsed);
        if (!std.mem.eql(u8, digest, self.current_interfaces_sha256)) {
            return error.StaleCompatibilityInterfaces;
        }
        for (self.interfaces) |evidence| {
            for (evidence.not_in_snapshot) |name| {
                if (!interface_names.contains(parsed, name)) return error.InvalidInterfaceEvidence;
            }
        }
        for (parsed) |name| _ = try self.interfaceAvailability(name);
    }

    /// Return the interface delta stored for one table id.
    pub fn tableDelta(self: Manifest, table_id: []const u8) ?[]const []const u8 {
        for (self.interfaces) |evidence| {
            if (std.mem.eql(u8, evidence.id, table_id)) return evidence.not_in_snapshot;
        }
        return null;
    }

    /// Write generated ZON with its reproducible maintenance command.
    pub fn write(self: Manifest, writer: *std.Io.Writer) !void {
        try writer.writeAll("// Generated by zig build update-compat-metadata -Dold=all. Do not edit.\n");
        try std.zon.stringify.serialize(self, .{}, writer);
        try writer.writeByte('\n');
    }

    /// Return a named error when a candidate differs from the expected cache bytes.
    pub fn checkExpected(actual: []const u8, expected: []const u8) !void {
        if (!std.mem.eql(u8, actual, expected)) return error.StaleCompatibilityMetadata;
    }
};

/// A measured optional gate and its classification.
pub const InterfaceGate = struct {
    gate: Version,
    required: bool,
};

/// Where one interface first appears in the measured window.
pub const InterfaceAvailability = struct {
    gate: Version,
    last_absent: ?Version,
    present_in_oldest: bool,
};

const required_interface_version: Version = .{ .major = 4, .minor = 1, .patch = 0 };

const SinceTag = struct {
    version: Version,
    has_patch: bool,
};

/// Parse a strict `major.minor` or `major.minor.patch` `@since` tag.
fn parseSinceTag(text: []const u8) !SinceTag {
    const trimmed = std.mem.trim(u8, text, " \t\r\n");
    var parts: [3]u32 = .{ 0, 0, 0 };
    var count: usize = 0;
    var iterator = std.mem.splitScalar(u8, trimmed, '.');
    while (iterator.next()) |part| {
        if (count == parts.len or part.len == 0) return error.InvalidInterfaceSinceTag;
        for (part) |byte| {
            if (!std.ascii.isDigit(byte)) return error.InvalidInterfaceSinceTag;
        }
        parts[count] = std.fmt.parseInt(u32, part, 10) catch return error.InvalidInterfaceSinceTag;
        count += 1;
    }
    if (count < 2) return error.InvalidInterfaceSinceTag;
    return .{
        .version = .{ .major = parts[0], .minor = parts[1], .patch = parts[2] },
        .has_patch = count == 3,
    };
}

/// Require non-empty measured interface names and canonicalize them.
fn requireInterfaces(allocator: Allocator, names: []const []const u8) ![]const []const u8 {
    if (names.len == 0) return error.UnresolvedInterfaceEvidence;
    return interface_names.canonicalize(allocator, names);
}

fn validateDigest(text: []const u8) !void {
    if (text.len != 64) return error.InvalidInterfaceEvidence;
    for (text) |byte| {
        if (!(std.ascii.isDigit(byte) or (byte >= 'a' and byte <= 'f'))) {
            return error.InvalidInterfaceEvidence;
        }
    }
}

fn validateDelta(names: []const []const u8) !void {
    for (names, 0..) |name, i| {
        if (!interface_names.isValidName(name)) return error.InvalidInterfaceEvidence;
        if (i > 0 and !std.mem.lessThan(u8, names[i - 1], name)) {
            return error.InvalidInterfaceEvidence;
        }
    }
}

/// Compare only the major and minor components of two versions.
fn minorOrder(a: Version, b: Version) std.math.Order {
    if (a.major != b.major) return if (a.major < b.major) .lt else .gt;
    if (a.minor != b.minor) return if (a.minor < b.minor) .lt else .gt;
    return .eq;
}

fn lessRow(_: void, a: Row, b: Row) bool {
    return a.version.order(b.version) == .lt;
}

fn sameOverrides(a: []const Override, b: []const Override) bool {
    if (a.len != b.len) return false;
    for (a, b) |left, right| {
        if (left.kind != right.kind or left.old_hash != right.old_hash or
            std.meta.activeTag(left.layout) != std.meta.activeTag(right.layout) or
            !std.mem.eql(u8, left.owner, right.owner) or
            !std.mem.eql(u8, left.method, right.method)) return false;

        switch (left.layout) {
            .identical => {},
            .abi_compatible => |reason| {
                if (reason != right.layout.abi_compatible) return false;
            },
            .trailing_defaults => |details| {
                const other = right.layout.trailing_defaults.added_arguments;
                if (details.added_arguments.len != other.len) return false;
                for (details.added_arguments, other) |before, after| {
                    if (!std.mem.eql(u8, before, after)) return false;
                }
            },
            .return_added => |legacy| {
                if (!sameSignature(legacy, right.layout.return_added)) return false;
            },
            .incompatible => |legacy| {
                if (!sameSignature(legacy, right.layout.incompatible)) return false;
            },
        }
    }
    return true;
}

fn sameSignature(left: Legacy, right: Legacy) bool {
    if (!std.mem.eql(u8, left.difference, right.difference) or
        !std.meta.eql(left.flags, right.flags)) return false;

    if ((left.@"return" == null) != (right.@"return" == null)) return false;
    if (left.@"return") |before| {
        const after = right.@"return".?;
        if (!std.mem.eql(u8, before.type, after.type) or
            !std.mem.eql(u8, before.meta, after.meta)) return false;
    }

    if (left.arguments.len != right.arguments.len) return false;
    for (left.arguments, right.arguments) |before, after| {
        if (!std.mem.eql(u8, before.name, after.name) or
            !std.mem.eql(u8, before.type, after.type) or
            !std.mem.eql(u8, before.meta, after.meta) or
            before.has_default != after.has_default) return false;
    }
    return true;
}

fn fixtureSnapshot(version: []const u8, items: []const records.Record) records.Snapshot {
    return fixtureSnapshotWith(version, items, &fixture_interfaces);
}

fn fixtureSnapshotWith(
    version: []const u8,
    items: []const records.Record,
    interfaces: []const []const u8,
) records.Snapshot {
    return .{
        .version = version,
        .status = "stable",
        .build = "official",
        .precision = "single",
        .raw_sha256 = "raw",
        .classes_sha256 = "classes",
        .records = items,
        .enums = &.{},
        .interfaces = interfaces,
    };
}

const fixture_interfaces = [_][]const u8{ "alpha", "bravo", "charlie" };

fn fixtureRecord(hash: u64, compatibility: []const u64) records.Record {
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
    const manifest = try Manifest.merge(
        allocator,
        fixtureSnapshot("4.7.2", &.{modern}),
        fixtureSnapshot("4.6.0", &.{old}),
        .overwrite,
        null,
    );
    var output: std.Io.Writer.Allocating = .init(allocator);
    try manifest.write(&output.writer);
    try std.testing.expect(std.mem.indexOf(u8, output.written(), ".arguments") != null);
    try std.testing.expect(std.mem.indexOf(u8, output.written(), ".flags") != null);
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
    const one = try Manifest.merge(a, current, first, .overwrite, null);
    const two = try Manifest.merge(a, current, second, .append, one);
    const reverse = try Manifest.merge(a, current, first, .append, try Manifest.merge(a, current, second, .overwrite, null));
    var left: std.Io.Writer.Allocating = .init(a);
    var right: std.Io.Writer.Allocating = .init(a);
    try two.write(&left.writer);
    try reverse.write(&right.writer);
    try std.testing.expectEqualStrings(left.written(), right.written());
    try std.testing.expectEqual(@as(usize, 1), two.tables.len);
    try std.testing.expectEqualStrings("4.6.0", two.tables[0].id);
    const replaced = try Manifest.merge(a, current, changed, .append, one);
    try std.testing.expectEqual(@as(usize, 1), replaced.targets.len);
    try std.testing.expectEqual(@as(usize, 1), replaced.tables.len);
    try std.testing.expectEqual(@as(u64, 303), replaced.tables[0].overrides[0].old_hash);
    try std.testing.expectError(error.UnexpectedInput, Manifest.merge(a, current, first, .overwrite, one));
    try std.testing.expectError(error.MissingInput, Manifest.merge(a, current, first, .append, null));
    var obsolete = one;
    obsolete.schema_version = 2;
    try std.testing.expectError(error.UnsupportedSchema, Manifest.merge(a, current, second, .append, obsolete));
    var mismatch = current;
    mismatch.raw_sha256 = "changed";
    try std.testing.expectError(error.CurrentSnapshotMismatch, Manifest.merge(a, mismatch, first, .append, one));
    mismatch = current;
    mismatch.version = "4.7.1";
    try std.testing.expectError(error.CurrentSnapshotMismatch, Manifest.merge(a, mismatch, first, .append, one));
    try std.testing.expectError(error.TargetNewerThanCurrent, Manifest.merge(a, current, fixtureSnapshot("4.8.0", first.records), .overwrite, null));
}

test "hash comparison preserves primary membership virtual absent multi and duplicate rules" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const current = [_]records.Record{fixtureRecord(202, &.{ 101, 303 })};
    const old = [_]records.Record{fixtureRecord(101, &.{})};
    const result = try Comparison.compare(a, &old, &current, &.{}, &.{});
    try std.testing.expectEqual(@as(u64, 101), result.overrides[0].old_hash);
    try std.testing.expectEqual(@as(usize, 1), result.multi_compat.len);
    try std.testing.expectEqual(@as(usize, 0), (try Comparison.compare(a, &current, &current, &.{}, &.{})).overrides.len);
    try std.testing.expectError(error.MissingCompatibilityEvidence, Comparison.compare(a, &old, &.{fixtureRecord(202, &.{303})}, &.{}, &.{}));
    try std.testing.expectError(error.DuplicateIdentity, Comparison.compare(a, &.{ old[0], old[0] }, &current, &.{}, &.{}));
    var virtual = current[0];
    virtual.virtual = true;
    var old_virtual = old[0];
    old_virtual.virtual = true;
    try std.testing.expectEqual(@as(usize, 1), (try Comparison.compare(a, &.{old_virtual}, &.{virtual}, &.{}, &.{})).virtual.len);
    const absent = try Comparison.compare(a, &.{}, &current, &.{}, &.{});
    try std.testing.expectEqual(@as(usize, 1), absent.absent.len);
    try std.testing.expectEqual(@as(usize, 1), absent.unresolved.len);
    try Manifest.checkExpected("candidate", "candidate");
    try std.testing.expectError(error.StaleCompatibilityMetadata, Manifest.checkExpected("candidate", "candidatf"));
}

test "return-added union classification preserves serialized diff and legacy flags" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const old = fixtureRecord(101, &.{});
    var current = fixtureRecord(202, &.{101});
    current.@"return" = .{ .type = "bool", .meta = "" };
    const result = try Comparison.compare(arena.allocator(), &.{old}, &.{current}, &.{}, &.{});
    const override = result.overrides[0];
    try std.testing.expect(override.layout == .return_added);
    const legacy = override.layout.return_added;
    try std.testing.expectEqualStrings("return: void/ -> bool/", legacy.difference);
    try std.testing.expectEqual(@as(usize, 0), legacy.arguments.len);
    try std.testing.expect(legacy.@"return" == null);
    try std.testing.expect(!legacy.flags.is_static);

    current.@"return" = null;
    current.is_const = true;
    const const_result = try Comparison.compare(arena.allocator(), &.{old}, &.{current}, &.{}, &.{});
    try std.testing.expectEqual(method_layout.Reason.const_flag, const_result.overrides[0].layout.abi_compatible);
}

test "every active layout compares payload contents rather than slice addresses" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var old = fixtureRecord(101, &.{});
    old.arguments = &.{.{ .name = "value", .type = "String" }};
    const legacy: Legacy = .fromRecord(old, "argument changed");
    const layouts = [_]Layout{
        .identical,
        .{ .trailing_defaults = .{ .added_arguments = &.{"enabled"} } },
        .{ .abi_compatible = .const_flag },
        .{ .abi_compatible = .renamed_enum },
        .{ .return_added = legacy },
        .{ .incompatible = legacy },
    };
    for (layouts) |layout| {
        const first: Override = .{
            .kind = .class,
            .owner = "Owner",
            .method = "method",
            .old_hash = 101,
            .layout = layout,
        };
        var second = first;
        second.owner = try allocator.dupe(u8, first.owner);
        try std.testing.expect(sameOverrides(&.{first}, &.{second}));
        second.layout = if (layout == .identical) .{ .abi_compatible = .const_flag } else .identical;
        try std.testing.expect(!sameOverrides(&.{first}, &.{second}));
    }

    var changed = legacy;
    changed.arguments = &.{.{ .name = "different", .type = "String" }};
    try std.testing.expect(!sameSignature(legacy, changed));
    changed = legacy;
    changed.difference = "another difference";
    try std.testing.expect(!sameSignature(legacy, changed));
    changed = legacy;
    changed.flags.is_const = true;
    try std.testing.expect(!sameSignature(legacy, changed));
    changed = legacy;
    changed.@"return" = .{ .type = "bool", .meta = "" };
    try std.testing.expect(!sameSignature(legacy, changed));
}

test "merge records interface deltas and shares tables only on matching evidence" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const records_current = [_]records.Record{fixtureRecord(101, &.{})};
    const current = fixtureSnapshotWith("4.7.2", &records_current, &.{ "alpha", "bravo", "charlie" });
    const first_release = fixtureSnapshotWith("4.6.0", &records_current, &.{ "alpha", "bravo" });
    const patch = fixtureSnapshotWith("4.6.1", &records_current, &.{ "alpha", "bravo" });

    const one = try Manifest.merge(a, current, first_release, .overwrite, null);
    try std.testing.expectEqual(@as(usize, 1), one.interfaces.len);
    try std.testing.expectEqualStrings("4.6.0", one.interfaces[0].id);
    try std.testing.expectEqual(@as(usize, 1), one.interfaces[0].not_in_snapshot.len);
    try std.testing.expectEqualStrings("charlie", one.interfaces[0].not_in_snapshot[0]);
    try std.testing.expectEqual(@as(usize, 64), one.current_interfaces_sha256.len);

    const two = try Manifest.merge(a, current, patch, .append, one);
    try std.testing.expectEqual(@as(usize, 2), two.targets.len);
    try std.testing.expectEqual(@as(usize, 1), two.tables.len);
    try std.testing.expectEqual(@as(usize, 1), two.interfaces.len);
    for (two.targets) |target| try std.testing.expectEqualStrings("4.6.0", target.table_id);
}

test "divergent patch interface deltas split tables rather than merge false evidence" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const records_current = [_]records.Record{fixtureRecord(101, &.{})};
    const current = fixtureSnapshotWith("4.7.2", &records_current, &.{ "alpha", "bravo", "charlie" });
    const older = fixtureSnapshotWith("4.6.0", &records_current, &.{"alpha"});
    const patch = fixtureSnapshotWith("4.6.1", &records_current, &.{ "alpha", "bravo" });

    const one = try Manifest.merge(a, current, older, .overwrite, null);
    try std.testing.expectEqual(@as(usize, 2), one.interfaces[0].not_in_snapshot.len);
    const two = try Manifest.merge(a, current, patch, .append, one);
    try std.testing.expectEqual(@as(usize, 2), two.tables.len);
    try std.testing.expectEqual(@as(usize, 2), two.interfaces.len);
    try std.testing.expectEqualStrings("4.6.0", two.interfaces[0].id);
    try std.testing.expectEqualStrings("4.6.1", two.interfaces[1].id);
    try std.testing.expectEqual(@as(usize, 1), two.interfaces[1].not_in_snapshot.len);
    try std.testing.expectEqualStrings("charlie", two.interfaces[1].not_in_snapshot[0]);
}

test "merge rejects missing and dropped interface evidence with named errors" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const items = [_]records.Record{fixtureRecord(101, &.{})};
    const good_current = fixtureSnapshotWith("4.7.2", &items, &.{ "alpha", "bravo" });
    try std.testing.expectError(
        error.UnresolvedInterfaceEvidence,
        Manifest.merge(a, fixtureSnapshotWith("4.7.2", &items, &.{}), fixtureSnapshotWith("4.6.0", &items, &.{"alpha"}), .overwrite, null),
    );
    try std.testing.expectError(
        error.UnresolvedInterfaceEvidence,
        Manifest.merge(a, good_current, fixtureSnapshotWith("4.6.0", &items, &.{}), .overwrite, null),
    );
    try std.testing.expectError(
        error.NonMonotonicInterfaceEvidence,
        Manifest.merge(a, good_current, fixtureSnapshotWith("4.6.0", &items, &.{ "alpha", "zulu" }), .overwrite, null),
    );
}

test "interface digest mismatch and dangling delta names are named errors" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const items = [_]records.Record{fixtureRecord(101, &.{})};
    const names = try interface_names.canonicalize(a, &.{ "alpha", "bravo", "charlie" });
    const current = fixtureSnapshotWith("4.7.2", &items, names);
    const old = fixtureSnapshotWith("4.6.0", &items, &.{ "alpha", "bravo", "charlie" });
    const manifest = try Manifest.merge(a, current, old, .overwrite, null);

    try manifest.validateInterfaces(a, try interface_names.canonicalize(a, &.{ "charlie", "bravo", "alpha" }));
    try std.testing.expectError(
        error.StaleCompatibilityInterfaces,
        manifest.validateInterfaces(a, try interface_names.canonicalize(a, &.{ "alpha", "bravo" })),
    );

    var dangling = manifest;
    dangling.interfaces = &.{.{ .id = "4.6.0", .not_in_snapshot = &.{"zulu"} }};
    try std.testing.expectError(error.InvalidInterfaceEvidence, dangling.validateInterfaces(a, names));
}

test "interface gates come from measured availability rather than the doc tag" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const items = [_]records.Record{fixtureRecord(101, &.{})};
    const current = fixtureSnapshotWith("4.7.2", &items, &.{ "alpha", "bravo", "zulu" });
    const one = try Manifest.merge(
        a,
        current,
        fixtureSnapshotWith("4.6.0", &items, &.{"alpha"}),
        .overwrite,
        null,
    );
    const two = try Manifest.merge(
        a,
        current,
        fixtureSnapshotWith("4.7.0", &items, &.{ "alpha", "bravo" }),
        .append,
        one,
    );

    const required = try two.interfaceAvailability("alpha");
    try std.testing.expect(required.present_in_oldest);
    try std.testing.expect(required.last_absent == null);
    try std.testing.expect(required.gate.eql(try Version.parseStrict("4.6.0")));

    const added = try two.interfaceAvailability("bravo");
    try std.testing.expect(!added.present_in_oldest);
    try std.testing.expect(added.last_absent.?.eql(try Version.parseStrict("4.6.0")));
    try std.testing.expect(added.gate.eql(try Version.parseStrict("4.7.0")));

    const unmeasured = try two.interfaceAvailability("zulu");
    try std.testing.expect(!unmeasured.present_in_oldest);
    try std.testing.expect(unmeasured.last_absent.?.eql(try Version.parseStrict("4.7.0")));
    try std.testing.expect(unmeasured.gate.eql(try Version.parseStrict("4.7.2")));
}

test "since tags are cross-checked against the measured interval" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const items = [_]records.Record{fixtureRecord(101, &.{})};
    const current = fixtureSnapshotWith("4.7.2", &items, &.{ "alpha", "bravo" });
    const one = try Manifest.merge(
        a,
        current,
        fixtureSnapshotWith("4.2.0", &items, &.{"alpha"}),
        .overwrite,
        null,
    );
    const two = try Manifest.merge(
        a,
        current,
        fixtureSnapshotWith("4.6.0", &items, &.{ "alpha", "bravo" }),
        .append,
        one,
    );

    // Present in the oldest measured target: required only at exactly 4.1.
    const required = try two.resolveInterface("alpha", "4.1");
    try std.testing.expect(required.required);
    try std.testing.expect(required.gate.eql(try Version.parseStrict("4.2.0")));
    try std.testing.expect(!(try two.resolveInterface("alpha", "4.2")).required);

    // Absent from 4.2.0 and provided by 4.6.0: a 4.3 tag is inside the interval.
    const measured = try two.resolveInterface("bravo", "4.3");
    try std.testing.expect(!measured.required);
    try std.testing.expect(measured.gate.eql(try Version.parseStrict("4.6.0")));

    try std.testing.expectError(
        error.InterfaceAvailabilityDisagreement,
        two.resolveInterface("bravo", "4.1"),
    );
    try std.testing.expectError(
        error.InterfaceAvailabilityDisagreement,
        two.resolveInterface("bravo", "4.7"),
    );
    // A patch tag must be strictly newer than the last measured absence.
    try std.testing.expectError(
        error.InterfaceAvailabilityDisagreement,
        two.resolveInterface("bravo", "4.2.0"),
    );
    try std.testing.expect(!(try two.resolveInterface("bravo", "4.2.5")).required);

    for ([_][]const u8{ "", "4", "4.x", "4.6.", "4.6.1.2" }) |tag| {
        try std.testing.expectError(error.InvalidInterfaceSinceTag, two.resolveInterface("bravo", tag));
    }
}

const std = @import("std");
const Allocator = std.mem.Allocator;

const Version = @import("common").Version;

const interface_names = @import("interfaces.zig");

const method_layout = @import("method_layout.zig");

const records = @import("records.zig");
