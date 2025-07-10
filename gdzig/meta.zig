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

pub fn signalName(comptime S: type) [:0]const u8 {
    @setEvalBranchQuota(10_000);
    comptime var signal_type: []const u8 = typeShortName(S);
    if (comptime std.mem.endsWith(u8, signal_type, "Signal")) {
        signal_type = comptime signal_type[0 .. signal_type.len - "Signal".len];
    }
    const signal_type_snake = comptime case.comptimeTo(.snake, signal_type) catch unreachable;
    return comptime std.fmt.comptimePrint("{s}", .{signal_type_snake});
}

const std = @import("std");
const case = @import("case");

const godot = @import("gdzig.zig");
const StringName = godot.builtin.StringName;
pub const typeName = godot.typeName;
