pub inline fn assertIs(comptime T: type, comptime U: type) void {
    comptime {
        if (!godot.meta.isA(T, U)) {
            const message = fmt.comptimePrint("expected type '{s}', found '{s}'", .{ @typeName(T), @typeName(U) });
            @compileError(message);
        }
    }
}

pub inline fn assertIsAny(comptime types: anytype, comptime U: type) void {
    comptime {
        if (!godot.meta.isAny(types, U)) {
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
}

pub inline fn assertPathLike(comptime T: type) void {
    assertIsAny(
        .{ godot.core.NodePath, []const u8, [:0]const u8 },
        T,
    );
}

pub inline fn assertStringLike(comptime T: type) void {
    assertIsAny(
        .{ godot.core.String, godot.core.StringName, []const u8, [:0]const u8 },
        T,
    );
}

pub inline fn assertVariantLike(comptime T: type) void {
    // TODO: other types
    assertIsAny(
        .{godot.core.Variant},
        T,
    );
}

const std = @import("std");
const debug = std.debug;
const fmt = std.fmt;
const mem = std.mem;

const godot = @import("root.zig");
