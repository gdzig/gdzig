/// Gets a pointer to a 32-bit integer in a PackedInt32Array.
///
/// - **index**: The index of the integer to get.
///
/// **Since Godot 4.1**
pub inline fn index(self: *PackedInt32Array, index_: usize) *i32 {
    return @ptrCast(raw.packedInt32ArrayOperatorIndex(self.ptr(), @intCast(index_)));
}

/// Gets a const pointer to a 32-bit integer in a PackedInt32Array.
///
/// - **index**: The index of the integer to get.
///
/// **Since Godot 4.1**
pub inline fn indexConst(self: *const PackedInt32Array, index_: usize) *const i32 {
    return @ptrCast(raw.packedInt32ArrayOperatorIndexConst(self.constPtr(), @intCast(index_)));
}

// @mixin stop

const Self = gdzig.builtin.PackedInt32Array;

const gdzig = @import("gdzig");
const raw = &gdzig.raw;
const PackedInt32Array = gdzig.builtin.PackedInt32Array;
const StringName = gdzig.builtin.StringName;
const Variant = gdzig.builtin.Variant;
