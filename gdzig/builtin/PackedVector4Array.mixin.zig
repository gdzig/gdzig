/// Gets a pointer to a Vector4 in a PackedVector4Array.
///
/// - **index**: The index of the Vector4 to get.
///
/// **Since Godot 4.3**
pub inline fn index(self: *PackedVector4Array, index_: usize) *Vector4 {
    return @ptrCast(raw.packedVector4ArrayOperatorIndex(self.ptr(), @intCast(index_)));
}

/// Gets a const pointer to a Vector4 in a PackedVector4Array.
///
/// - **index**: The index of the Vector4 to get.
///
/// **Since Godot 4.3**
pub inline fn indexConst(self: *const PackedVector4Array, index_: usize) *const Vector4 {
    return @ptrCast(raw.packedVector4ArrayOperatorIndexConst(self.constPtr(), @intCast(index_)));
}

// @mixin stop

const Self = gdzig.builtin.PackedVector4Array;

const gdzig = @import("gdzig");
const raw = &gdzig.raw;
const PackedVector4Array = gdzig.builtin.PackedVector4Array;
const StringName = gdzig.builtin.StringName;
const Variant = gdzig.builtin.Variant;
const Vector4 = gdzig.builtin.Vector4;
