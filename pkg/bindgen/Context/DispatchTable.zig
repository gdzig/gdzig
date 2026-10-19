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
    /// First measured release that provides this interface.
    gate: Version,
    /// True for interfaces present in every measured target and tagged 4.1.
    required: bool,

    pub fn isRequired(self: Function) bool {
        return self.required;
    }
};

const std = @import("std");
const ArrayList = std.ArrayListUnmanaged;

const Context = @import("../Context.zig");
const Imports = Context.Imports;
const Version = @import("common").Version;
const StringHashMap = std.StringHashMapUnmanaged;
