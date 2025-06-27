const Imports = @This();

map: StringHashMap(void) = .empty,
skip: ?[]const u8 = null,

pub const empty: Imports = .{};

pub const Iterator = StringHashMap(void).KeyIterator;

pub fn deinit(self: *Imports, allocator: Allocator) void {
    self.map.deinit(allocator);
}

pub fn put(self: *Imports, allocator: Allocator, name: []const u8) !void {
    if (name.len == 0) return;

    var resolved = util.childType(name);

    if (std.mem.startsWith(u8, resolved, "TypedArray")) {
        resolved = resolved[11 .. resolved.len - 1];
        try self.map.put(allocator, "Array", {});
    }

    if (std.mem.startsWith(u8, resolved, "Ref(")) {
        resolved = resolved[4 .. resolved.len - 1];
        try self.map.put(allocator, "Ref", {});
    }

    const pos = std.mem.indexOf(u8, resolved, ".");

    if (pos) |p| {
        resolved = resolved[0..p];
    }

    if (util.isBuiltinType(resolved)) return;
    if (std.mem.eql(u8, "Self", resolved)) return;
    if (self.skip) |skip| {
        if (std.mem.eql(u8, skip, resolved)) return;
    }

    try self.map.put(allocator, resolved, {});
}

pub fn merge(self: *Imports, allocator: Allocator, other: *const Imports) !void {
    var iter = other.iterator();
    while (iter.next()) |key| {
        try self.put(allocator, key.*);
    }
}

pub fn iterator(self: *const Imports) Iterator {
    return self.map.keyIterator();
}

const std = @import("std");
const Allocator = std.mem.Allocator;
const StringHashMap = std.StringHashMapUnmanaged;

const util = @import("../util.zig");
