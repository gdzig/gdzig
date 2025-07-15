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

const raw: *Interface = &@import("../gdzig_bindings.zig").raw;

const typeName = @import("../gdzig_bindings.zig").typeName;
const Interface = @import("../Interface.zig");
const PackedVector3Array = @import("./packed_vector3_array.zig").PackedVector3Array;
const StringName = @import("./string_name.zig").StringName;
const Variant = @import("./variant.zig").Variant;
const Vector3 = @import("./vector3.zig").Vector3;
