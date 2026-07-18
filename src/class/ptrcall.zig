/// Marshalling helpers for Godot's `ptrcall` ABI (used for virtual method
/// dispatch and for extension methods bound through ClassDB).
///
/// Per godot-cpp's `method_ptrcall.h` conventions, ptrcall does not pass
/// scalars at their declared C width. Instead:
///
/// - every integer type (bool included), and every enum or packed flag
///   struct narrower than 64 bits, travels as a full `int64_t` (8 bytes)
/// - `u64` (and enums/flags backed by `u64`) travels as `uint64_t`
/// - `bool` travels as `uint8_t`
/// - `f32` and `f64` both travel as `double` (8 bytes)
///
/// A Zig virtual method or bound method declared with a narrower type (say,
/// `i32` or `f32`) must still read/write the full slot width, or it will
/// read stack garbage out of the high bytes (params) or leave garbage in
/// the high bytes for the engine to read back (returns).
///
/// Non-scalar types (structs like `String`/`Vector2`, object pointers,
/// optionals of object pointers, etc.) are passed at their real, declared
/// layout and are read/written directly.
///
/// This is the runtime-side half of the ABI width rule; `wideSlot` in
/// `pkg/bindgen/codegen.zig` is the emission side, deciding which generated
/// call sites need a widened slot in the first place.
const std = @import("std");

/// Reads a single ptrcall argument slot as `T`, applying the width conventions described
/// above. `raw_p_arg` accepts both the optional `GDExtensionConstTypePtr` the engine hands us
/// directly and the already-unwrapped `*const anyopaque` that higher-level callers may have
/// narrowed it to.
pub fn readArg(comptime T: type, raw_p_arg: ?*const anyopaque) T {
    const p_arg: *const anyopaque = @ptrCast(raw_p_arg);
    return switch (@typeInfo(T)) {
        .bool => @as(*const u8, @ptrCast(p_arg)).* != 0,
        .int => @intCast(readIntSlot(T, p_arg)),
        .float => @floatCast(@as(*const f64, @ptrCast(@alignCast(p_arg))).*),
        .@"enum" => |info| @enumFromInt(@as(info.tag_type, @intCast(readIntSlot(info.tag_type, p_arg)))),
        .@"struct" => |info| blk: {
            if (info.layout != .@"packed") break :blk @as(*const T, @ptrCast(@alignCast(p_arg))).*;
            const Backing = info.backing_integer.?;
            break :blk @bitCast(@as(Backing, @intCast(readIntSlot(Backing, p_arg))));
        },
        else => @as(*const T, @ptrCast(@alignCast(p_arg))).*,
    };
}

/// Writes `value` (of declared type `T`) into a ptrcall return slot, applying the width
/// conventions described above. The full slot width is always written so no garbage remains
/// in the high bytes. `raw_p_ret` accepts both the optional `GDExtensionTypePtr` the engine
/// hands us directly and the already-unwrapped `*anyopaque` that higher-level callers may have
/// narrowed it to.
pub fn writeReturn(comptime T: type, raw_p_ret: ?*anyopaque, value: T) void {
    const p_ret: *anyopaque = @ptrCast(raw_p_ret);
    switch (@typeInfo(T)) {
        .bool => @as(*u8, @ptrCast(p_ret)).* = @intFromBool(value),
        .int => writeIntSlot(T, p_ret, value),
        .float => @as(*f64, @ptrCast(@alignCast(p_ret))).* = value,
        .@"enum" => |info| writeIntSlot(info.tag_type, p_ret, @intFromEnum(value)),
        .@"struct" => |info| {
            if (info.layout != .@"packed") {
                @as(*T, @ptrCast(@alignCast(p_ret))).* = value;
                return;
            }
            const Backing = info.backing_integer.?;
            writeIntSlot(Backing, p_ret, @as(Backing, @bitCast(value)));
        },
        else => @as(*T, @ptrCast(@alignCast(p_ret))).* = value,
    }
}

/// `u64` is the only integer width that gets its own native slot; every
/// other integer (regardless of signedness or width, up to 64 bits) travels
/// as `int64_t`.
fn isU64Like(bits: u16, signedness: std.builtin.Signedness) bool {
    return bits == 64 and signedness == .unsigned;
}

fn readIntSlot(comptime Int: type, p_arg: *const anyopaque) i128 {
    const info = @typeInfo(Int).int;
    if (comptime info.bits > 64) @compileError("ptrcall does not support integers wider than 64 bits");
    if (comptime isU64Like(info.bits, info.signedness)) {
        return @as(*const u64, @ptrCast(@alignCast(p_arg))).*;
    }
    return @as(*const i64, @ptrCast(@alignCast(p_arg))).*;
}

fn writeIntSlot(comptime Int: type, p_ret: *anyopaque, value: anytype) void {
    const info = @typeInfo(Int).int;
    if (comptime info.bits > 64) @compileError("ptrcall does not support integers wider than 64 bits");
    if (comptime isU64Like(info.bits, info.signedness)) {
        @as(*u64, @ptrCast(@alignCast(p_ret))).* = @intCast(value);
    } else {
        @as(*i64, @ptrCast(@alignCast(p_ret))).* = @intCast(value);
    }
}
