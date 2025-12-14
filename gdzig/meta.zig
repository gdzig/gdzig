//! This module is private API. It is not exported for end-users.

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
