/// Gets a pointer to a 64-bit float in a PackedFloat64Array.
///
/// - **index**: The index of the float to get.
///
/// **Since Godot 4.1**
pub inline fn index(self: *PackedFloat64Array, index_: usize) *f64 {
    return @ptrCast(raw.packedFloat64ArrayOperatorIndex(self.ptr(), @intCast(index_)));
}

/// Gets a const pointer to a 64-bit float in a PackedFloat64Array.
///
/// - **index**: The index of the float to get.
///
/// **Since Godot 4.1**
pub inline fn indexConst(self: *const PackedFloat64Array, index_: usize) *const f64 {
    return @ptrCast(raw.packedFloat64ArrayOperatorIndexConst(self.constPtr(), @intCast(index_)));
}

// @mixin stop

const raw: *Interface = &@import("../gdzig.zig").raw;

const typeName = @import("../gdzig.zig").typeName;
const Interface = @import("../Interface.zig");
const PackedFloat64Array = @import("./packed_float64_array.zig").PackedFloat64Array;
const StringName = @import("./string_name.zig").StringName;
const Variant = @import("./variant.zig").Variant;
