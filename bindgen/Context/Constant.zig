const Constant = @This();

doc: ?[]const u8 = null,
name: []const u8 = "_",
type: Type = .void,
value: []const u8 = "{}",

pub fn fromBuiltin(allocator: Allocator, api: GodotApi.Builtin.Constant, ctx: *const Context) !Constant {
    var self: Constant = .{};
    errdefer self.deinit(allocator);

    // TODO: normalization
    self.name = try allocator.dupe(u8, api.name);
    self.type = try Type.from(allocator, api.type, false, ctx);
    self.value = try allocator.dupe(u8, api.value);

    return self;
}

pub fn fromClass(allocator: Allocator, api: GodotApi.Class.Constant, ctx: *const Context) !Constant {
    var self: Constant = .{};
    errdefer self.deinit(allocator);

    // TODO: normalization
    self.name = try allocator.dupe(u8, api.name);
    self.type = try .from(allocator, "int", false, ctx);
    self.value = try std.fmt.allocPrint(allocator, "{d}", .{api.value});

    return self;
}

pub fn deinit(self: *Constant, allocator: Allocator) void {
    if (self.doc) |doc| allocator.free(doc);
    allocator.free(self.name);
    self.type.deinit(allocator);
    allocator.free(self.value);

    self.* = .{};
}

const std = @import("std");
const Allocator = std.mem.Allocator;

const Context = @import("../Context.zig");
const Imports = Context.Imports;
const Type = Context.Type;
const GodotApi = @import("../GodotApi.zig");
