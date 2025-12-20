/// Gets a pointer to a Vector2 in a PackedVector2Array.
///
/// - **index**: The index of the Vector2 to get.
///
/// **Since Godot 4.1**
pub inline fn index(self: *PackedVector2Array, index_: usize) *Vector2 {
    return @ptrCast(raw.packedVector2ArrayOperatorIndex(self.ptr(), @intCast(index_)));
}

/// Gets a const pointer to a Vector2 in a PackedVector2Array.
///
/// - **index**: The index of the Vector2 to get.
///
/// **Since Godot 4.1**
pub inline fn indexConst(self: *const PackedVector2Array, index_: usize) *const Vector2 {
    return @ptrCast(raw.packedVector2ArrayOperatorIndexConst(self.constPtr(), @intCast(index_)));
}

// @mixin stop

const Self = gdzig.builtin.PackedVector2Array;

const gdzig = @import("gdzig");
const raw = &gdzig.raw;
const PackedVector2Array = gdzig.builtin.PackedVector2Array;
const StringName = gdzig.builtin.StringName;
const Variant = gdzig.builtin.Variant;
const Vector2 = gdzig.builtin.Vector2;
