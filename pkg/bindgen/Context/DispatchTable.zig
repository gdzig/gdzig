const DispatchTable = @This();

pub const empty: DispatchTable = .{};

functions: ArrayList(Function) = .empty,
imports: Imports = .empty,
typedefs: StringHashMap(void) = .empty,

pub const Function = struct {
    /// Header documentation block for this interface.
    docs: ?[]const u8,
    /// Zig field name after case conversion.
    name: []const u8,
    /// Raw GDExtension interface name.
    api_name: []const u8,
    /// C function-pointer typedef for the interface.
    ptr_type: []const u8,
    /// First measured release that provides this interface.
    gate: Version,
    /// Measured requirement of this interface.
    availability: manifest.Availability,
};

const std = @import("std");
const ArrayList = std.ArrayListUnmanaged;
const StringHashMap = std.StringHashMapUnmanaged;

const Version = @import("common").Version;

const manifest = @import("compat").manifest;

const Context = @import("../Context.zig");
const Imports = Context.Imports;
