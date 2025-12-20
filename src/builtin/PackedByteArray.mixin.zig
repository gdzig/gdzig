/// Gets a pointer to a byte in a PackedByteArray.
///
/// - **index**: The index of the byte to get.
///
/// **Since Godot 4.1**
pub inline fn index(self: *PackedByteArray, index_: usize) *u8 {
    return @ptrCast(raw.packedByteArrayOperatorIndex(self.ptr(), @intCast(index_)));
}

/// Gets a const pointer to a byte in a PackedByteArray.
///
/// - **index**: The index of the byte to get.
///
/// **Since Godot 4.1**
pub inline fn indexConst(self: *const PackedByteArray, index_: usize) *const u8 {
    return @ptrCast(raw.packedByteArrayOperatorIndexConst(self.constPtr(), @intCast(index_)));
}

// @mixin stop

const Self = gdzig.builtin.PackedByteArray;

const gdzig = @import("gdzig");
const raw = &gdzig.raw;
const PackedByteArray = gdzig.builtin.PackedByteArray;
const StringName = gdzig.builtin.StringName;
const Variant = gdzig.builtin.Variant;
