/// Gets a pointer to a string in a PackedStringArray.
///
/// - **index**: The index of the String to get.
///
/// **Since Godot 4.1**
pub inline fn index(self: *PackedStringArray, index_: usize) *String {
    return @ptrCast(raw.packedStringArrayOperatorIndex(self.ptr(), @intCast(index_)));
}

/// Gets a const pointer to a string in a PackedStringArray.
///
/// - **index**: The index of the String to get.
///
/// **Since Godot 4.1**
pub inline fn indexConst(self: *const PackedStringArray, index_: usize) *const String {
    return @ptrCast(raw.packedStringArrayOperatorIndexConst(self.constPtr(), @intCast(index_)));
}

// @mixin stop

const raw: *Interface = &@import("../gdzig_bindings.zig").raw;

const typeName = @import("../gdzig_bindings.zig").typeName;
const Interface = @import("../Interface.zig");
const PackedStringArray = @import("./packed_string_array.zig").PackedStringArray;
const String = @import("./string.zig").String;
const StringName = @import("./string_name.zig").StringName;
const Variant = @import("./variant.zig").Variant;
