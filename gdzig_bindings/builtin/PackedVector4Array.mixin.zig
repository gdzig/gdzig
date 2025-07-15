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

const raw: *Interface = &@import("../gdzig_bindings.zig").raw;

const typeName = @import("../gdzig_bindings.zig").typeName;
const Interface = @import("../Interface.zig");
const PackedVector4Array = @import("./packed_vector4_array.zig").PackedVector4Array;
const StringName = @import("./string_name.zig").StringName;
const Variant = @import("./variant.zig").Variant;
const Vector4 = @import("./vector4.zig").Vector4;
