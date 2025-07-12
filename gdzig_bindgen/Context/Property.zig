const Property = @This();

name: []const u8 = "_",
name_api: []const u8 = "_",
index: ?usize = null,
type: Type = .void,
getter: Function = .{},
setter: ?Function = null,

pub fn fromClass(allocator: Allocator, class_name: []const u8, api: GodotApi.Class.Property, is_singleton: bool, ctx: *const Context) !Property {
    var self = Property{};
    errdefer self.deinit(allocator);

    self.name = blk: {
        // TODO: normalize
        break :blk try allocator.dupe(u8, api.name);
    };
    self.name_api = api.name;
    self.index = if (api.index < 0) null else @intCast(api.index);
    self.type = try Type.from(allocator, api.type, false, ctx);
    self.getter = try Function.fromClassGetter(allocator, class_name, api.getter, self.type, is_singleton);
    self.setter = if (api.setter.len > 0) try Function.fromClassSetter(allocator, class_name, is_singleton, api.setter, self.type) else null;

    return self;
}

pub fn deinit(self: *Property, allocator: Allocator) void {
    allocator.free(self.name);
    self.type.deinit(allocator);
    self.getter.deinit(allocator);
    if (self.setter) |*setter| setter.deinit(allocator);

    self.* = .{};
}

const std = @import("std");
const Allocator = std.mem.Allocator;

const Context = @import("../Context.zig");
const Function = Context.Function;
const Type = Context.Type;

const GodotApi = @import("../GodotApi.zig");
