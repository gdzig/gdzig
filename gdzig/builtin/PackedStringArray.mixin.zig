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

const Self = gdzig.builtin.PackedStringArray;

const gdzig = @import("gdzig");
const raw = &gdzig.raw;
const PackedStringArray = gdzig.builtin.PackedStringArray;
const String = gdzig.builtin.String;
const StringName = gdzig.builtin.StringName;
const Variant = gdzig.builtin.Variant;
