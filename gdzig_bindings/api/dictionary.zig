const raw: *Interface = &@import("../../gdzig_bindings.zig").raw;

/// Makes a Dictionary into a typed Dictionary.
///
/// @param self A pointer to the Dictionary.
/// @param key_tag The type of Variant the Dictionary key will store.
/// @param key_class_name A pointer to a StringName with the name of the object (if key_tag is OBJECT).
/// @param key_script An optional pointer to a Script object (if key_tag is OBJECT and the base class is extended by a script).
/// @param value_tag The type of Variant the Dictionary value will store.
/// @param value_class_name A pointer to a StringName with the name of the object (if value_tag is OBJECT).
/// @param value_script An optional pointer to a Script object (if value_tag is OBJECT and the base class is extended by a script).
///
/// @since 4.4
pub inline fn dictionarySetTyped(
    self: *Array,
    key_tag: Variant.Tag,
    key_class_name: *const StringName,
    key_script: ?*const Variant,
    value_tag: Variant.Tag,
    value_class_name: *const StringName,
    value_script: ?*const Variant,
) void {
    raw.dictionarySetTyped(
        self.ptr(),
        @intFromEnum(key_tag),
        key_class_name.constPtr(),
        if (key_script) |s| s.constPtr() else null,
        @intFromEnum(value_tag),
        value_class_name.constPtr(),
        if (value_script) |s| s.constPtr() else null,
    );
}

/// Gets a pointer to a Variant in a Dictionary with the given key.
///
/// @param self A pointer to a Dictionary object.
/// @param key A pointer to a Variant representing the key.
///
/// @return A pointer to a Variant representing the value at the given key.
///
/// @since 4.1
pub inline fn dictionaryOperatorIndex(self: *Dictionary, key: *const Variant) *Variant {
    return raw.dictionaryOperatorIndex(self.ptr(), key.constPtr());
}

/// Gets a const pointer to a Variant in a Dictionary with the given key.
///
/// @param self A const pointer to a Dictionary object.
/// @param key A pointer to a Variant representing the key.
///
/// @return A const pointer to a Variant representing the value at the given key.
///
/// @since 4.1
pub inline fn dictionaryOperatorIndexConst(self: *const Dictionary, key: *const Variant) *const Variant {
    return raw.dictionaryOperatorIndexConst(self.constPtr(), key.constPtr());
}

const builtin = @import("../builtin.zig");
const Array = builtin.Array;
const Dictionary = builtin.Dictionary;
const StringName = builtin.StringName;
const Variant = builtin.Variant;
const Interface = @import("../Interface.zig");
