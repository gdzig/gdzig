pub fn assertIs(comptime T: type, comptime U: type) void {
    if (comptime !godot.meta.isA(T, U)) {
        const message = fmt.comptimePrint("expected type '{s}', found '{s}'", .{ @typeName(T), @typeName(U) });
        @compileError(message);
    }
}

pub fn assertIsAny(comptime types: anytype, comptime U: type) void {
    if (comptime !godot.meta.isAny(types, U)) {
        var names: []const u8 = "";
        for (if (@hasField(types, "len")) types else .{types}, 0..) |t, i| {
            if (i == 0) {
                names = names ++ "'" ++ @typeName(t) ++ "'";
            } else if (i == types.len - 1) {
                names = names ++ ", or '" ++ @typeName(t) ++ "'";
            } else {
                names = names ++ ", '" ++ @typeName(t) ++ "'";
            }
        }
        const message = fmt.comptimePrint("expected type {s}, found '{s}'", .{ names, @typeName(U) });
        @compileError(message);
    }
}

pub fn assertIsObjectType(comptime T: type) void {
    assertIs(godot.class.Object, T);
}

pub fn assertIsObjectPtr(comptime T: type) void {
    assertIs(godot.class.Object, Child(T));
}

const std = @import("std");
const fmt = std.fmt;

const godot = @import("gdzig.zig");
const Child = godot.meta.Child;
