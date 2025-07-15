/// Gets a pointer to a 32-bit float in a PackedFloat32Array.
///
/// - **index**: The index of the float to get.
///
/// **Since Godot 4.1**
pub inline fn index(self: *PackedFloat32Array, index_: usize) *f32 {
    return @ptrCast(raw.packedFloat32ArrayOperatorIndex(self.ptr(), @intCast(index_)));
}

/// Gets a const pointer to a 32-bit float in a PackedFloat32Array.
///
/// - **index**: The index of the float to get.
///
/// **Since Godot 4.1**
pub inline fn indexConst(self: *const PackedFloat32Array, index_: usize) *const f32 {
    return @ptrCast(raw.packedFloat32ArrayOperatorIndexConst(self.constPtr(), @intCast(index_)));
}

// @mixin stop

const raw: *Interface = &@import("../gdzig_bindings.zig").raw;

const typeName = @import("../gdzig_bindings.zig").typeName;
const Interface = @import("../Interface.zig");
const PackedFloat32Array = @import("./packed_float32_array.zig").PackedFloat32Array;
const StringName = @import("./string_name.zig").StringName;
const Variant = @import("./variant.zig").Variant;
