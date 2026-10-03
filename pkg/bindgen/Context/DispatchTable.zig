const DispatchTable = @This();

pub const empty: DispatchTable = .{};

functions: ArrayList(Function) = .empty,
imports: Imports = .empty,
typedefs: StringHashMap(void) = .empty,

pub const Function = struct {
    docs: ?[]const u8,
    name: []const u8,
    api_name: []const u8,
    ptr_type: []const u8,
    since: std.SemanticVersion,

    pub fn isRequired(self: Function) bool {
        return self.since.order(.{ .major = 4, .minor = 1, .patch = 0 }) == .eq;
    }
};

const std = @import("std");
const ArrayList = std.ArrayListUnmanaged;

const Context = @import("../Context.zig");
const Imports = Context.Imports;
const StringHashMap = std.StringHashMapUnmanaged;
