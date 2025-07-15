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

const raw: *Interface = &@import("../gdzig_bindings.zig").raw;

const typeName = @import("../gdzig_bindings.zig").typeName;
const Interface = @import("../Interface.zig");
const PackedByteArray = @import("./packed_byte_array.zig").PackedByteArray;
const StringName = @import("./string_name.zig").StringName;
const Variant = @import("./variant.zig").Variant;
