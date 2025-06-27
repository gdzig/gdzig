const Module = @This();

name: []const u8,
functions: []Context.Function,
imports: Context.Imports = .empty,

pub fn init(allocator: Allocator, name: []const u8) !Module {
    return Module{
        .name = try allocator.dupe(u8, name),
        .functions = &.{},
    };
}

pub fn deinit(self: *Module, allocator: Allocator) void {
    allocator.free(self.name);
    allocator.free(self.functions);
}

const std = @import("std");
const Allocator = std.mem.Allocator;

const Context = @import("../Context.zig");
const GodotApi = @import("../GodotApi.zig");
