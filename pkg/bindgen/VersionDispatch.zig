//! Version ranges and adapter names derived solely from measured manifest layouts.
pub const Group = struct {
    lower: Version,
    upper: Version,
    old_hash: u64,
    layout: method_layout.Class,
    difference: []const u8,
    adapter: []const u8,
    available: bool,
    signature: ?manifest.Override = null,
};

/// Owned range names; layout text borrows the manifest.
pub const Groups = struct {
    items: []Group,

    /// Release the range names and their container.
    pub fn deinit(self: Groups, allocator: Allocator) void {
        for (self.items) |group| {
            allocator.free(group.adapter);
        }
        allocator.free(self.items);
    }
};

/// Group consecutive measured legacy layouts and match naming-only adapters.
pub fn collect(
    allocator: Allocator,
    metadata: manifest.Manifest,
    owner: []const u8,
    method: []const u8,
    zig_name: []const u8,
    declarations: []const []const u8,
) !Groups {
    // Canonical numeric ordering makes range boundaries independent of table order.
    const targets = try allocator.dupe(manifest.Target, metadata.targets);
    defer allocator.free(targets);
    for (targets) |target| {
        _ = try Version.parseStrict(target.source.version);
    }
    std.mem.sort(manifest.Target, targets, {}, targetLess);
    var groups: std.ArrayList(Group) = .empty;
    errdefer {
        for (groups.items) |group| {
            allocator.free(group.adapter);
        }
        groups.deinit(allocator);
    }
    var active: ?usize = null;
    const current = try Version.parseStrict(metadata.current.version);

    // Plain layouts end a legacy range but need no adapter themselves.
    for (targets) |target| {
        const version = try Version.parseStrict(target.source.version);
        const record = findOverride(metadata, target, owner, method);
        const legacy = if (record) |value| requiresAdapter(value.layout) else false;
        if (active) |index| {
            if (legacy and sameLayout(groups.items[index], record.?)) continue;
            groups.items[index].upper = version;
            active = null;
        }
        if (!legacy) continue;

        // A later distinct range in the same minor needs a patch suffix.
        var patch_suffix = false;
        for (groups.items) |group| {
            if (group.lower.major == version.major and group.lower.minor == version.minor) {
                patch_suffix = true;
            }
        }
        const adapter = if (patch_suffix)
            try std.fmt.allocPrint(allocator, "{s}_{d}_{d}_{d}", .{
                zig_name, version.major, version.minor, version.patch,
            })
        else
            try std.fmt.allocPrint(allocator, "{s}_{d}_{d}", .{
                zig_name, version.major, version.minor,
            });
        errdefer allocator.free(adapter);
        var available = false;
        for (declarations) |name| {
            if (std.mem.eql(u8, name, adapter)) available = true;
        }
        try groups.append(allocator, .{
            .lower = version,
            .upper = current,
            .old_hash = record.?.old_hash,
            .layout = record.?.layout,
            .difference = record.?.layout_diff orelse "incompatible layout",
            .adapter = adapter,
            .available = available,
            .signature = record.?,
        });
        active = groups.items.len - 1;
    }
    return .{ .items = try groups.toOwnedSlice(allocator) };
}

fn targetLess(_: void, lhs: manifest.Target, rhs: manifest.Target) bool {
    const left = Version.parseStrict(lhs.source.version) catch
        std.debug.panic("invalid manifest target version {s}", .{lhs.source.version});
    const right = Version.parseStrict(rhs.source.version) catch
        std.debug.panic("invalid manifest target version {s}", .{rhs.source.version});
    return left.lt(right);
}

fn findOverride(
    metadata: manifest.Manifest,
    target: manifest.Target,
    owner: []const u8,
    method: []const u8,
) ?manifest.Override {
    for (metadata.tables) |table| {
        if (!std.mem.eql(u8, table.id, target.table_id)) continue;
        for (table.overrides) |record| {
            if (record.kind == .class and std.mem.eql(u8, record.owner, owner) and
                std.mem.eql(u8, record.method, method))
            {
                return record;
            }
        }
    }
    return null;
}

fn requiresAdapter(layout: method_layout.Class) bool {
    return layout == .incompatible or layout == .return_added;
}

fn sameLayout(group: Group, record: manifest.Override) bool {
    return group.old_hash == record.old_hash and group.layout == record.layout;
}

fn allocationProbe(allocator: Allocator) !void {
    const result = try collect(
        allocator,
        cached,
        "Object",
        "is_class",
        "isClass",
        &.{},
    );
    defer result.deinit(allocator);
    try std.testing.expectEqual(@as(usize, 1), result.items.len);
}

test "Compatibility range query releases every allocation on success and failure" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, allocationProbe, .{});
}

test "numeric ordering separates distinct patch ranges and names later adapters" {
    var metadata = cached;
    const first: manifest.Override = .{
        .kind = .class,
        .owner = "Probe",
        .method = "probe",
        .old_hash = 101,
        .layout = .incompatible,
    };
    var second = first;
    second.old_hash = 202;
    metadata.tables = &.{
        .{ .id = "first", .overrides = &.{first} },
        .{ .id = "second", .overrides = &.{second} },
    };
    var early = metadata.targets[0];
    early.source.version = "4.6.0";
    early.table_id = "first";
    var later = early;
    later.source.version = "4.6.2";
    later.table_id = "second";
    metadata.targets = &.{ later, early };
    const groups = try collect(std.testing.allocator, metadata, "Probe", "probe", "probe", &.{});
    defer groups.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 2), groups.items.len);
    try std.testing.expectEqualStrings("probe_4_6", groups.items[0].adapter);
    try std.testing.expectEqualStrings("probe_4_6_2", groups.items[1].adapter);
    try std.testing.expectEqual(@as(u32, 2), groups.items[0].upper.patch);
    try std.testing.expectEqual(@as(u64, 202), groups.items[1].old_hash);
}

test "measured Object layout forms one range with a naming-only adapter" {
    const groups = try collect(
        std.testing.allocator,
        cached,
        "Object",
        "is_class",
        "isClass",
        &.{"isClass_4_6"},
    );
    defer groups.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 1), groups.items.len);
    const group = groups.items[0];
    try std.testing.expectEqual(@as(u32, 6), group.lower.minor);
    try std.testing.expectEqual(@as(u32, 7), group.upper.minor);
    try std.testing.expectEqual(@as(u64, 3927539163), group.old_hash);
    try std.testing.expectEqualStrings("isClass_4_6", group.adapter);
    try std.testing.expect(group.available);
}

test "plain measured layouts do not introduce adapter dispatch" {
    const groups = try collect(
        std.testing.allocator,
        cached,
        "Resource",
        "duplicate",
        "duplicate",
        &.{},
    );
    defer groups.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 0), groups.items.len);
}

const std = @import("std");
const Allocator = std.mem.Allocator;

const Version = @import("common").Version;
const manifest = @import("compat").manifest;
const method_layout = @import("compat").method_layout;
const cached: manifest.Manifest = @import("generated/compatibility.zon");
