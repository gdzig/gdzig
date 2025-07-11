const Interface = @This();

pub const empty: Interface = .{};

functions: ArrayList(Function) = .empty,
imports: Imports = .empty,

pub const Function = struct {
    docs: ?[]const u8,
    name: []const u8,
    api_name: []const u8,
    ptr_type: []const u8,
};

const std = @import("std");
const ArrayList = std.ArrayListUnmanaged;

const Context = @import("../Context.zig");
const Imports = Context.Imports;
