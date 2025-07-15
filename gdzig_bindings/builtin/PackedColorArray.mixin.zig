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

const raw: *Interface = &@import("../gdzig_bindings.zig").raw;

const typeName = @import("../gdzig_bindings.zig").typeName;
const Interface = @import("../Interface.zig");
const Color = @import("./color.zig").Color;
const PackedColorArray = @import("./packed_color_array.zig").PackedColorArray;
const StringName = @import("./string_name.zig").StringName;
const Variant = @import("./variant.zig").Variant;
