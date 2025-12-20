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

const Self = gdzig.builtin.PackedFloat64Array;

const gdzig = @import("gdzig");
const raw = &gdzig.raw;
const PackedFloat64Array = gdzig.builtin.PackedFloat64Array;
const StringName = gdzig.builtin.StringName;
const Variant = gdzig.builtin.Variant;
