/// Gets a pointer to a 64-bit integer in a PackedInt64Array.
///
/// - **index**: The index of the integer to get.
///
/// **Since Godot 4.1**
pub inline fn index(self: *PackedInt64Array, index_: usize) *i64 {
    return @ptrCast(raw.packedInt64ArrayOperatorIndex(self.ptr(), @intCast(index_)));
}

/// Gets a const pointer to a 64-bit integer in a PackedInt64Array.
///
/// - **index**: The index of the integer to get.
///
/// **Since Godot 4.1**
pub inline fn indexConst(self: *const PackedInt64Array, index_: usize) *const i64 {
    return @ptrCast(raw.packedInt64ArrayOperatorIndexConst(self.constPtr(), @intCast(index_)));
}

// @mixin stop

const raw: *Interface = &@import("../gdzig_bindings.zig").raw;

const typeName = @import("../gdzig_bindings.zig").typeName;
const Interface = @import("../Interface.zig");
const PackedInt64Array = @import("./packed_int64_array.zig").PackedInt64Array;
const StringName = @import("./string_name.zig").StringName;
const Variant = @import("./variant.zig").Variant;
