const Field = @This();

doc: ?[]const u8 = null,
name: []const u8 = "",
type: Type = .void,
offset: ?usize = null,

pub fn init(allocator: Allocator, doc: ?[]const u8, name: []const u8, @"type": []const u8, meta: ?[]const u8, offset: ?usize, ctx: *const Context) !Field {
    var self: Field = .{};
    errdefer self.deinit(allocator);

    self.doc = if (doc) |d| try allocator.dupe(u8, d) else null;
    self.name = try allocator.dupe(u8, name);
    self.type = try Type.from(allocator, meta orelse @"type", meta != null, ctx);
    self.offset = offset;

    return self;
}

pub fn deinit(self: *Field, allocator: Allocator) void {
    if (self.doc) |doc| allocator.free(doc);
    allocator.free(self.name);
    self.type.deinit(allocator);
}

const std = @import("std");
const Allocator = std.mem.Allocator;

const Context = @import("../Context.zig");
const Type = Context.Type;
