/// Recursively dereferences a type to its base; e.g. `Child(?*?*?*T)` returns `T`.
pub fn RecursiveChild(comptime T: type) type {
    return switch (@typeInfo(T)) {
        .optional => |info| RecursiveChild(info.child),
        .pointer => |info| RecursiveChild(info.child),
        else => T,
    };
}

pub fn typeShortName(comptime T: type) [:0]const u8 {
    const full = @typeName(T);
    const pos = std.mem.lastIndexOfScalar(u8, full, '.') orelse return full;
    return full[pos + 1 ..];
}

const std = @import("std");

const godot = @import("gdzig.zig");
const StringName = godot.builtin.StringName;
pub const typeName = godot.typeName;
