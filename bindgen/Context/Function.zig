const Function = @This();

doc: ?[]const u8 = null,
name: []const u8 = "_",
api_name: ?[]const u8 = null,

index: ?usize = null,
hash: ?u64 = null,

parameters: StringArrayHashMap(Parameter) = .empty,
return_type: Type = .void,

is_static: bool = true,
is_const: bool = false,
is_vararg: bool = false,

pub fn fromBuiltinConstructor(allocator: Allocator, builtin_name: []const u8, constructor: GodotApi.Builtin.Constructor, ctx: *const Context) !Function {
    var self = Function{};
    errdefer self.deinit(allocator);

    self.doc = if (constructor.description) |doc| try allocator.dupe(u8, doc) else null;
    self.name = blk: {
        var buf: ArrayList(u8) = .empty;
        errdefer buf.deinit(allocator);

        var args = constructor.arguments orelse &.{};

        if (args.len == 1 and std.mem.eql(u8, builtin_name, args[0].type)) {
            try buf.appendSlice(allocator, "copy");
            break :blk try buf.toOwnedSlice(allocator);
        } else if (args.len > 0 and std.mem.eql(u8, "from", args[0].name)) {
            try buf.appendSlice(allocator, "from");
            var stream = std.io.fixedBufferStream(args[0].type);
            var reader = stream.reader();
            var writer = buf.writer(allocator);
            try case.to(.pascal, &reader, &writer);
            args = args[1..];
        } else {
            try buf.appendSlice(allocator, "init");
        }

        for (args) |arg| {
            var stream = std.io.fixedBufferStream(arg.name);
            var reader = stream.reader();
            var writer = buf.writer(allocator);
            try case.to(.pascal, &reader, &writer);
        }

        break :blk try buf.toOwnedSlice(allocator);
    };
    self.index = @intCast(constructor.index);

    for (constructor.arguments orelse &.{}) |arg| {
        try self.parameters.put(allocator, arg.name, try .fromNameType(allocator, arg.name, arg.type, ctx));
    }

    self.return_type = try .from(allocator, builtin_name, false, ctx);

    return self;
}

pub fn fromBuiltinMethod(allocator: Allocator, method: GodotApi.Builtin.Method, ctx: *const Context) !Function {
    var self = Function{};
    errdefer self.deinit(allocator);

    self.doc = if (method.description) |doc| try allocator.dupe(u8, doc) else null;
    self.name = try case.allocTo(allocator, .camel, method.name);
    self.api_name = method.name;
    self.hash = method.hash;
    self.is_static = method.is_static;
    self.is_const = method.is_const;
    self.is_vararg = method.is_vararg;

    for (method.arguments orelse &.{}) |arg| {
        const parameter: Parameter = if (arg.default_value.len > 0)
            try .fromNameTypeDefault(allocator, arg.name, arg.type, arg.default_value, ctx)
        else
            try .fromNameType(allocator, arg.name, arg.type, ctx);
        try self.parameters.put(allocator, arg.name, parameter);
    }
    self.return_type = try .from(allocator, method.return_type, false, ctx);

    return self;
}

pub fn fromUtilityFunction(allocator: Allocator, function: GodotApi.UtilityFunction, ctx: *const Context) !Function {
    var self: Function = .{};
    errdefer self.deinit(allocator);

    self.doc = if (function.description) |desc| try allocator.dupe(u8, desc) else null;
    self.name = try case.allocTo(allocator, .camel, function.name);
    self.api_name = function.name;
    self.hash = function.hash;
    self.is_static = true;
    self.is_const = false;
    self.is_vararg = function.is_vararg;
    for (function.arguments orelse &.{}) |arg| {
        try self.parameters.put(allocator, arg.name, try .fromNameType(allocator, arg.name, arg.type, ctx));
    }
    self.return_type = if (function.return_type.len > 0) try .from(allocator, function.return_type, false, ctx) else .void;

    return self;
}

pub fn deinit(self: *Function, allocator: Allocator) void {
    if (self.doc) |doc| allocator.free(doc);
    allocator.free(self.name);
    for (self.parameters.values()) |*param| {
        param.deinit(allocator);
    }
    self.parameters.deinit(allocator);
    self.return_type.deinit(allocator);
}

pub const Parameter = struct {
    name: []const u8 = "_",
    type: Type = .void,
    default: ?[]const u8 = null,

    pub fn fromNameType(allocator: Allocator, api_name: []const u8, api_type: []const u8, ctx: *const Context) !Parameter {
        const name = blk: {
            const camel = try case.allocTo(allocator, .camel, api_name);
            defer allocator.free(camel);
            break :blk try std.fmt.allocPrint(allocator, "{s}_", .{camel});
        };
        errdefer allocator.free(name);

        const @"type" = try Type.from(allocator, api_type, false, ctx);
        errdefer @"type".deinit(allocator);

        return Parameter{
            .name = name,
            .type = @"type",
        };
    }

    pub fn fromNameTypeDefault(allocator: Allocator, api_name: []const u8, api_type: []const u8, default: []const u8, ctx: *const Context) !Parameter {
        var self = try fromNameType(allocator, api_name, api_type, ctx);
        self.default = default;
        return self;
    }

    pub fn deinit(self: *Parameter, allocator: Allocator) void {
        allocator.free(self.name);
        self.type.deinit(allocator);
        if (self.default) |default| allocator.free(default);
    }
};

const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayListUnmanaged;
const StringArrayHashMap = std.StringArrayHashMapUnmanaged;

const case = @import("case");

const Context = @import("../Context.zig");
const Imports = Context.Imports;
const Type = Context.Type;
const GodotApi = @import("../GodotApi.zig");
