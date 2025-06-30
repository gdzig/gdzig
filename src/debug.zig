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

pub fn assertIsObject(comptime T: type) void {
    assertIs(godot.core.Object, T);
}

pub fn assertPathLike(comptime T: type) void {
    assertIsAny(
        .{ godot.core.NodePath, []const u8, [:0]const u8 },
        T,
    );
}

pub fn assertStringLike(comptime T: type) void {
    assertIsAny(
        .{ godot.core.String, godot.core.StringName, []const u8, [:0]const u8 },
        T,
    );
}

pub fn assertVariantLike(comptime T: type) void {
    // TODO: other types
    assertIsAny(
        .{godot.core.Variant},
        T,
    );
}

const std = @import("std");
const fmt = std.fmt;

const godot = @import("root.zig");
