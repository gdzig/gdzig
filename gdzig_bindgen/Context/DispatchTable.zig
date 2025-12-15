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
    since: []const u8,

    pub fn isRequired(self: Function) bool {
        return std.mem.eql(u8, self.since, "4.1");
    }
};

const std = @import("std");
const ArrayList = std.ArrayListUnmanaged;

const Context = @import("../Context.zig");
const Imports = Context.Imports;
const StringHashMap = std.StringHashMapUnmanaged;
