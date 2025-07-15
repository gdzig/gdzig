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

const raw: *Interface = &@import("../gdzig_bindings.zig").raw;

const typeName = @import("../gdzig_bindings.zig").typeName;
const Interface = @import("../Interface.zig");
const PackedVector2Array = @import("./packed_vector2_array.zig").PackedVector2Array;
const StringName = @import("./string_name.zig").StringName;
const Variant = @import("./variant.zig").Variant;
const Vector2 = @import("./vector2.zig").Vector2;
