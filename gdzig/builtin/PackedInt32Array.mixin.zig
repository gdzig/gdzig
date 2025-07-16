/// Gets a pointer to a 32-bit integer in a PackedInt32Array.
///
/// - **index**: The index of the integer to get.
///
/// **Since Godot 4.1**
pub inline fn index(self: *PackedInt32Array, index_: usize) *i32 {
    return @ptrCast(raw.packedInt32ArrayOperatorIndex(self.ptr(), @intCast(index_)));
}

/// Gets a const pointer to a 32-bit integer in a PackedInt32Array.
///
/// - **index**: The index of the integer to get.
///
/// **Since Godot 4.1**
pub inline fn indexConst(self: *const PackedInt32Array, index_: usize) *const i32 {
    return @ptrCast(raw.packedInt32ArrayOperatorIndexConst(self.constPtr(), @intCast(index_)));
}

// @mixin stop

const raw: *Interface = &@import("../gdzig.zig").raw;

const typeName = @import("../gdzig.zig").typeName;
const Interface = @import("../Interface.zig");
const PackedInt32Array = @import("./packed_int32_array.zig").PackedInt32Array;
const StringName = @import("./string_name.zig").StringName;
const Variant = @import("./variant.zig").Variant;
