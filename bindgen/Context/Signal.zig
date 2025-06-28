const Signal = @This();

name: []const u8 = "_",
name_api: []const u8 = "_",
parameters: StringArrayHashMap(Parameter) = .empty,

pub fn fromClass(allocator: Allocator, api: GodotApi.Class.Signal, ctx: *const Context) !Signal {
    var self = Signal{};

    self.name = blk: {
        // TODO: normalize
        break :blk try allocator.dupe(u8, api.name);
    };
    self.name_api = api.name;

    for (api.arguments orelse &.{}) |arg| {
        try self.parameters.put(allocator, arg.name, try Parameter.fromClass(allocator, arg, ctx));
    }

    return self;
}

pub fn deinit(self: *Signal, allocator: Allocator) void {
    allocator.free(self.name);
    for (self.parameters.values()) |*parameter| {
        parameter.deinit(allocator);
    }
    self.parameters.deinit(allocator);

    self.* = .{};
}

pub const Parameter = struct {
    name: []const u8 = "_",
    type: Type = .void,

    pub fn fromClass(allocator: Allocator, api: GodotApi.Class.Signal.Argument, ctx: *const Context) !Parameter {
        var self = Parameter{};

        self.name = blk: {
            // TODO: normalize
            break :blk try allocator.dupe(u8, api.name);
        };
        self.type = try Type.from(allocator, api.type, false, ctx);

        return self;
    }

    pub fn deinit(self: *Parameter, allocator: Allocator) void {
        allocator.free(self.name);
        self.type.deinit(allocator);

        self.* = .{};
    }
};

const std = @import("std");
const Allocator = std.mem.Allocator;
const StringArrayHashMap = std.StringArrayHashMapUnmanaged;

const Context = @import("../Context.zig");
const Type = Context.Type;

const GodotApi = @import("../GodotApi.zig");
