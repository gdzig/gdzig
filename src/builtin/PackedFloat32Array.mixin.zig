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

const Self = gdzig.builtin.PackedFloat32Array;

const gdzig = @import("gdzig");
const raw = &gdzig.raw;
const PackedFloat32Array = gdzig.builtin.PackedFloat32Array;
const StringName = gdzig.builtin.StringName;
const Variant = gdzig.builtin.Variant;
