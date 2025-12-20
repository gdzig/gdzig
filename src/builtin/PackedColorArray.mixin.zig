/// Gets a pointer to a color in a PackedColorArray.
///
/// - **index**: The index of the Color to get.
///
/// **Since Godot 4.1**
pub inline fn index(self: *PackedColorArray, index_: usize) *Color {
    return @ptrCast(raw.packedColorArrayOperatorIndex(self.ptr(), @intCast(index_)));
}

/// Gets a const pointer to a color in a PackedColorArray.
///
/// - **index**: The index of the Color to get.
///
/// **Since Godot 4.1**
pub inline fn indexConst(self: *const PackedColorArray, index_: usize) *const Color {
    return @ptrCast(raw.packedColorArrayOperatorIndexConst(self.constPtr(), @intCast(index_)));
}

// @mixin stop

const Self = gdzig.builtin.PackedColorArray;

const gdzig = @import("gdzig");
const raw = &gdzig.raw;
const Color = gdzig.builtin.Color;
const PackedColorArray = gdzig.builtin.PackedColorArray;
const StringName = gdzig.builtin.StringName;
const Variant = gdzig.builtin.Variant;
