const Function = @This();

doc: ?[]const u8,
name: []const u8,

offset: ?u32,
hash: u64,

parameters: []Parameter,
return_type: ?[]const u8,

is_static: bool,
is_const: bool,
is_vararg: bool,

pub fn fromUtilityFunction(allocator: Allocator, function: GodotApi.UtilityFunction, ctx: *const Context) !Function {
    const doc = if (function.description) |desc| try allocator.dupe(u8, desc) else null;
    errdefer allocator.free(doc orelse "");

    const name = try case.allocTo(allocator, .camel, function.name);
    errdefer allocator.free(name);

    var parameters = try ArrayList(Parameter).initCapacity(allocator, if (function.arguments) |args| args.len else 0);
    errdefer parameters.deinit(allocator);

    for (function.arguments orelse &.{}) |arg| {
        try parameters.append(allocator, try .fromFunctionArgument(allocator, arg, ctx));
    }

    const return_type = if (function.return_type.len == 0) null else try allocator.dupe(u8, function.return_type);
    errdefer allocator.free(return_type orelse &.{});

    return Function{
        .doc = doc,
        .name = name,
        .offset = null,
        .hash = function.hash,
        .parameters = try parameters.toOwnedSlice(allocator),
        .return_type = return_type,
        .is_static = true,
        .is_const = false,
        .is_vararg = function.is_vararg,
    };
}

pub fn deinit(self: *Function, allocator: Allocator) void {
    allocator.free(self.doc orelse "");
    allocator.free(self.name);
    for (self.parameters) |param| {
        param.deinit(allocator);
    }
    self.parameters.deinit(allocator);
    allocator.free(self.return_type orelse &.{});
}

pub const Parameter = struct {
    name: []const u8,
    type: Type,
    default: ?[]const u8,

    pub fn fromFunctionArgument(allocator: Allocator, arg: GodotApi.UtilityFunction.Argument, ctx: *const Context) !Parameter {
        const name = blk: {
            const camel = try case.allocTo(allocator, .camel, arg.name);
            if (std.zig.Token.keywords.has(camel)) {
                defer allocator.free(camel);
                break :blk try std.fmt.allocPrint(allocator, "@\"{s}\"", .{camel});
            }
            break :blk camel;
        };
        errdefer allocator.free(name);

        const @"type" = try Type.from(allocator, arg.type, ctx);
        errdefer @"type".deinit(allocator);

        return Parameter{
            .name = name,
            .type = @"type",
            .default = null,
        };
    }

    pub fn deinit(self: *Parameter, allocator: Allocator) void {
        allocator.free(self.name);
        self.type.deinit(allocator);
        allocator.free(self.default orelse &.{});
    }
};

const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayListUnmanaged;

const case = @import("case");

const Context = @import("../Context.zig");
const GodotApi = @import("../GodotApi.zig");
const Type = Context.Type;
