/// Gets a pointer to a Vector3 in a PackedVector3Array.
///
/// - **index**: The index of the Vector3 to get.
///
/// **Since Godot 4.1**
pub inline fn index(self: *PackedVector3Array, index_: usize) *Vector3 {
    return @ptrCast(raw.packedVector3ArrayOperatorIndex(self.ptr(), @intCast(index_)));
}

/// Gets a const pointer to a Vector3 in a PackedVector3Array.
///
/// - **index**: The index of the Vector3 to get.
///
/// **Since Godot 4.1**
pub inline fn indexConst(self: *const PackedVector3Array, index_: usize) *const Vector3 {
    return @ptrCast(raw.packedVector3ArrayOperatorIndexConst(self.constPtr(), @intCast(index_)));
}

// @mixin stop

const Self = gdzig.builtin.PackedVector3Array;

const gdzig = @import("gdzig");
const raw = &gdzig.raw;
const PackedVector3Array = gdzig.builtin.PackedVector3Array;
const StringName = gdzig.builtin.StringName;
const Variant = gdzig.builtin.Variant;
const Vector3 = gdzig.builtin.Vector3;
