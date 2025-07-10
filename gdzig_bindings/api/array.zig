const raw: *Interface = &@import("../../gdzig_bindings.zig").raw;

/// Sets an Array to be a reference to another Array object.
///
/// @param self A pointer to the Array object to update.
/// @param from A pointer to the Array object to reference.
///
/// @since 4.1
pub inline fn arrayRef(self: *Array, from: *const Array) void {
    raw.arrayRef(self.ptr(), from.constPtr());
}

/// Makes an Array into a typed Array.
///
/// @param self A pointer to the Array.
/// @param var_tag The type of Variant the Array will store.
/// @param class_name A pointer to a StringName with the name of the object (if var_tag is OBJECT).
/// @param script An optional pointer to a Script object (if var_tag is OBJECT and the base class is extended by a script).
///
/// @since 4.1
pub inline fn arraySetTyped(self: *Array, var_tag: Variant.Tag, class_name: *const StringName, script: ?*const Variant) void {
    raw.arraySetTyped(self.ptr(), @intFromEnum(var_tag), class_name.constPtr(), if (script) |s| s.constPtr() else null);
}

/// Gets a pointer to a Variant in an Array.
///
/// @param self A pointer to an Array object.
/// @param index The index of the Variant to get.
///
/// @return A pointer to the requested Variant.
///
/// @since 4.1
pub inline fn arrayOperatorIndex(self: *Array, index: i64) *Variant {
    return raw.arrayOperatorIndex(self.ptr(), index);
}

/// Gets a const pointer to a Variant in an Array.
///
/// @param self A const pointer to an Array object.
/// @param index The index of the Variant to get.
///
/// @return A const pointer to the requested Variant.
///
/// @since 4.1
pub inline fn arrayOperatorIndexConst(self: *const Array, index: i64) *const Variant {
    return raw.arrayOperatorIndexConst(self.constPtr(), index);
}

/// Gets a pointer to a byte in a PackedByteArray.
///
/// @param self A pointer to a PackedByteArray object.
/// @param index The index of the byte to get.
///
/// @return A pointer to the requested byte.
///
/// @since 4.1
pub inline fn packedByteArrayOperatorIndex(self: *PackedByteArray, index: i64) *u8 {
    return raw.packedByteArrayOperatorIndex(self.ptr(), index);
}

/// Gets a const pointer to a byte in a PackedByteArray.
///
/// @param self A const pointer to a PackedByteArray object.
/// @param index The index of the byte to get.
///
/// @return A const pointer to the requested byte.
///
/// @since 4.1
pub inline fn packedByteArrayOperatorIndexConst(self: *const PackedByteArray, index: i64) *const u8 {
    return raw.packedByteArrayOperatorIndexConst(self.constPtr(), index);
}

/// Gets a pointer to a 32-bit float in a PackedFloat32Array.
///
/// @param self A pointer to a PackedFloat32Array object.
/// @param index The index of the float to get.
///
/// @return A pointer to the requested 32-bit float.
///
/// @since 4.1
pub inline fn packedFloat32ArrayOperatorIndex(self: *PackedFloat32Array, index: i64) *f32 {
    return raw.packedFloat32ArrayOperatorIndex(self.ptr(), index);
}

/// Gets a const pointer to a 32-bit float in a PackedFloat32Array.
///
/// @param self A const pointer to a PackedFloat32Array object.
/// @param index The index of the float to get.
///
/// @return A const pointer to the requested 32-bit float.
///
/// @since 4.1
pub inline fn packedFloat32ArrayOperatorIndexConst(self: *const PackedFloat32Array, index: i64) *const f32 {
    return raw.packedFloat32ArrayOperatorIndexConst(self.constPtr(), index);
}

/// Gets a pointer to a 64-bit float in a PackedFloat64Array.
///
/// @param self A pointer to a PackedFloat64Array object.
/// @param index The index of the float to get.
///
/// @return A pointer to the requested 64-bit float.
///
/// @since 4.1
pub inline fn packedFloat64ArrayOperatorIndex(self: *PackedFloat64Array, index: i64) *f64 {
    return raw.packedFloat64ArrayOperatorIndex(self.ptr(), index);
}

/// Gets a const pointer to a 64-bit float in a PackedFloat64Array.
///
/// @param self A const pointer to a PackedFloat64Array object.
/// @param index The index of the float to get.
///
/// @return A const pointer to the requested 64-bit float.
///
/// @since 4.1
pub inline fn packedFloat64ArrayOperatorIndexConst(self: *const PackedFloat64Array, index: i64) *const f64 {
    return raw.packedFloat64ArrayOperatorIndexConst(self.constPtr(), index);
}

/// Gets a pointer to a 32-bit integer in a PackedInt32Array.
///
/// @param self A pointer to a PackedInt32Array object.
/// @param index The index of the integer to get.
///
/// @return A pointer to the requested 32-bit integer.
///
/// @since 4.1
pub inline fn packedInt32ArrayOperatorIndex(self: *PackedInt32Array, index: i64) *i32 {
    return raw.packedInt32ArrayOperatorIndex(self.ptr(), index);
}

/// Gets a const pointer to a 32-bit integer in a PackedInt32Array.
///
/// @param self A const pointer to a PackedInt32Array object.
/// @param index The index of the integer to get.
///
/// @return A const pointer to the requested 32-bit integer.
///
/// @since 4.1
pub inline fn packedInt32ArrayOperatorIndexConst(self: *const PackedInt32Array, index: i64) *const i32 {
    return raw.packedInt32ArrayOperatorIndexConst(self.constPtr(), index);
}

/// Gets a pointer to a 64-bit integer in a PackedInt64Array.
///
/// @param self A pointer to a PackedInt64Array object.
/// @param index The index of the integer to get.
///
/// @return A pointer to the requested 64-bit integer.
///
/// @since 4.1
pub inline fn packedInt64ArrayOperatorIndex(self: *PackedInt64Array, index: i64) *i64 {
    return raw.packedInt64ArrayOperatorIndex(self.ptr(), index);
}

/// Gets a const pointer to a 64-bit integer in a PackedInt64Array.
///
/// @param self A const pointer to a PackedInt64Array object.
/// @param index The index of the integer to get.
///
/// @return A const pointer to the requested 64-bit integer.
///
/// @since 4.1
pub inline fn packedInt64ArrayOperatorIndexConst(self: *const PackedInt64Array, index: i64) *const i64 {
    return raw.packedInt64ArrayOperatorIndexConst(self.constPtr(), index);
}

/// Gets a pointer to a string in a PackedStringArray.
///
/// @param self A pointer to a PackedStringArray object.
/// @param index The index of the String to get.
///
/// @return A pointer to the requested String.
///
/// @since 4.1
pub inline fn packedStringArrayOperatorIndex(self: *PackedStringArray, index: i64) *String {
    return raw.packedStringArrayOperatorIndex(self.ptr(), index);
}

/// Gets a const pointer to a string in a PackedStringArray.
///
/// @param self A const pointer to a PackedStringArray object.
/// @param index The index of the String to get.
///
/// @return A const pointer to the requested String.
///
/// @since 4.1
pub inline fn packedStringArrayOperatorIndexConst(self: *const PackedStringArray, index: i64) *const String {
    return raw.packedStringArrayOperatorIndexConst(self.constPtr(), index);
}

/// Gets a pointer to a Vector2 in a PackedVector2Array.
///
/// @param self A pointer to a PackedVector2Array object.
/// @param index The index of the Vector2 to get.
///
/// @return A pointer to the requested Vector2.
///
/// @since 4.1
pub inline fn packedVector2ArrayOperatorIndex(self: *PackedVector2Array, index: i64) *Vector2 {
    return raw.packedVector2ArrayOperatorIndex(self.ptr(), index);
}

/// Gets a const pointer to a Vector2 in a PackedVector2Array.
///
/// @param self A const pointer to a PackedVector2Array object.
/// @param index The index of the Vector2 to get.
///
/// @return A const pointer to the requested Vector2.
///
/// @since 4.1
pub inline fn packedVector2ArrayOperatorIndexConst(self: *const PackedVector2Array, index: i64) *const Vector2 {
    return raw.packedVector2ArrayOperatorIndexConst(self.constPtr(), index);
}

/// Gets a pointer to a Vector3 in a PackedVector3Array.
///
/// @param self A pointer to a PackedVector3Array object.
/// @param index The index of the Vector3 to get.
///
/// @return A pointer to the requested Vector3.
///
/// @since 4.1
pub inline fn packedVector3ArrayOperatorIndex(self: *PackedVector3Array, index: i64) *Vector3 {
    return raw.packedVector3ArrayOperatorIndex(self.ptr(), index);
}

/// Gets a const pointer to a Vector3 in a PackedVector3Array.
///
/// @param self A const pointer to a PackedVector3Array object.
/// @param index The index of the Vector3 to get.
///
/// @return A const pointer to the requested Vector3.
///
/// @since 4.1
pub inline fn packedVector3ArrayOperatorIndexConst(self: *const PackedVector3Array, index: i64) *const Vector3 {
    return raw.packedVector3ArrayOperatorIndexConst(self.constPtr(), index);
}

/// Gets a pointer to a Vector4 in a PackedVector4Array.
///
/// @param self A pointer to a PackedVector4Array object.
/// @param index The index of the Vector4 to get.
///
/// @return A pointer to the requested Vector4.
///
/// @since 4.3
pub inline fn packedVector4ArrayOperatorIndex(self: *PackedVector4Array, index: i64) *Vector4 {
    return raw.packedVector4ArrayOperatorIndex(self.ptr(), index);
}

/// Gets a const pointer to a Vector4 in a PackedVector4Array.
///
/// @param self A const pointer to a PackedVector4Array object.
/// @param index The index of the Vector4 to get.
///
/// @return A const pointer to the requested Vector4.
///
/// @since 4.3
pub inline fn packedVector4ArrayOperatorIndexConst(self: *const PackedVector4Array, index: i64) *const Vector4 {
    return raw.packedVector4ArrayOperatorIndexConst(self.constPtr(), index);
}

/// Gets a pointer to a color in a PackedColorArray.
///
/// @param self A pointer to a PackedColorArray object.
/// @param index The index of the Color to get.
///
/// @return A pointer to the requested Color.
///
/// @since 4.1
pub inline fn packedColorArrayOperatorIndex(self: *PackedColorArray, index: i64) *Color {
    return raw.packedColorArrayOperatorIndex(self.ptr(), index);
}

/// Gets a const pointer to a color in a PackedColorArray.
///
/// @param self A const pointer to a PackedColorArray object.
/// @param index The index of the Color to get.
///
/// @return A const pointer to the requested Color.
///
/// @since 4.1
pub inline fn packedColorArrayOperatorIndexConst(self: *const PackedColorArray, index: i64) *const Color {
    return raw.packedColorArrayOperatorIndexConst(self.constPtr(), index);
}

const builtin = @import("../builtin.zig");
const Array = builtin.Array;
const StringName = builtin.StringName;
const Variant = builtin.Variant;
const Vector2 = builtin.Vector2;
const Vector3 = builtin.Vector3;
const Vector4 = builtin.Vector4;
const Color = builtin.Color;
const String = builtin.String;
const PackedByteArray = builtin.PackedByteArray;
const PackedFloat32Array = builtin.PackedFloat32Array;
const PackedFloat64Array = builtin.PackedFloat64Array;
const PackedInt32Array = builtin.PackedInt32Array;
const PackedInt64Array = builtin.PackedInt64Array;
const PackedStringArray = builtin.PackedStringArray;
const PackedVector2Array = builtin.PackedVector2Array;
const PackedVector3Array = builtin.PackedVector3Array;
const PackedVector4Array = builtin.PackedVector4Array;
const PackedColorArray = builtin.PackedColorArray;
const Interface = @import("../Interface.zig");
