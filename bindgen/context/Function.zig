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

pub fn fromUtilityFunction(allocator: Allocator, function: GodotApi.UtilityFunction) !Function {
    const doc = if (function.description) |desc| try docs.convertDocsToMarkdown(allocator, desc) else null;
    errdefer allocator.free(doc orelse "");

    const name = try case.allocTo(allocator, .camel, function.name);
    errdefer allocator.free(name);

    var parameters = try ArrayList(Parameter).initCapacity(allocator, if (function.arguments) |args| args.len else 0);
    errdefer parameters.deinit(allocator);

    for (function.arguments orelse &.{}) |arg| {
        try parameters.append(allocator, .{
            .name = try case.allocTo(allocator, .snake, arg.name),
            .type = try allocator.dupe(u8, arg.type),
            .default = null,
        });
    }

    const return_type = try allocator.dupe(u8, function.return_type);
    errdefer allocator.free(return_type);

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
    type: []const u8,
    default: ?[]const u8,

    pub fn deinit(self: *Parameter, allocator: Allocator) void {
        allocator.free(self.name);
        allocator.free(self.type);
        allocator.free(self.default orelse &.{});
    }
};

const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayListUnmanaged;

const case = @import("case");

const GodotApi = @import("../GodotApi.zig");
const docs = @import("docs.zig");
