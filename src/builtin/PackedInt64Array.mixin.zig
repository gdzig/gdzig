/// Gets a pointer to a 64-bit integer in a PackedInt64Array.
///
/// - **index**: The index of the integer to get.
///
/// **Since Godot 4.1**
pub inline fn index(self: *PackedInt64Array, index_: usize) *i64 {
    return @ptrCast(raw.packedInt64ArrayOperatorIndex(self.ptr(), @intCast(index_)));
}

/// Gets a const pointer to a 64-bit integer in a PackedInt64Array.
///
/// - **index**: The index of the integer to get.
///
/// **Since Godot 4.1**
pub inline fn indexConst(self: *const PackedInt64Array, index_: usize) *const i64 {
    return @ptrCast(raw.packedInt64ArrayOperatorIndexConst(self.constPtr(), @intCast(index_)));
}

// @mixin stop

const Self = gdzig.builtin.PackedInt64Array;

const gdzig = @import("gdzig");
const raw = &gdzig.raw;
const PackedInt64Array = gdzig.builtin.PackedInt64Array;
const StringName = gdzig.builtin.StringName;
const Variant = gdzig.builtin.Variant;
