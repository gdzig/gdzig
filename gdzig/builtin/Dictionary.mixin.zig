/// Makes a Dictionary into a typed Dictionary.
///
/// - **K**: The type for Dictionary keys.
/// - **V**: The type for Dictionary values.
/// - **key_script**: An optional pointer to a Script object (if K is an object, and the base class is extended by a script).
/// - **value_script**: An optional pointer to a Script object (if V is an object, and the base class is extended by a script).
///
/// _Since Godot 4.4_
pub inline fn setTyped(
    self: *Array,
    comptime K: type,
    comptime V: type,
    key_script: ?*const Variant,
    value_script: ?*const Variant,
) void {
    const key_tag = Variant.Tag.forType(K);
    const value_tag = Variant.Tag.forType(V);
    const key_class_name: StringName = .fromType(K);
    const value_class_name: StringName = .fromType(V);

    raw.dictionarySetTyped(
        self.ptr(),
        @intFromEnum(key_tag),
        if (key_tag == .object) key_class_name.constPtr() else null,
        if (key_script) |s| s.constPtr() else null,
        @intFromEnum(value_tag),
        if (value_tag == .object) value_class_name.constPtr() else null,
        if (value_script) |s| s.constPtr() else null,
    );
}

/// Gets a pointer to a Variant in a Dictionary with the given key.
///
/// - **key**: A pointer to a Variant representing the key.
///
/// _Since Godot 4.1_
pub inline fn index(self: *Dictionary, key: *const Variant) *Variant {
    return @ptrCast(raw.dictionaryOperatorIndex(self.ptr(), key.constPtr()));
}

/// Gets a const pointer to a Variant in a Dictionary with the given key.
///
/// - **key**: A pointer to a Variant representing the key.
///
/// _Since Godot 4.1_
pub inline fn indexConst(self: *const Dictionary, key: *const Variant) *const Variant {
    return @ptrCast(raw.dictionaryOperatorIndexConst(self.constPtr(), key.constPtr()));
}

// @mixin stop

const Self = gdzig.builtin.Dictionary;

const gdzig = @import("gdzig");
const raw = &gdzig.raw;
const Array = gdzig.builtin.Array;
const Dictionary = gdzig.builtin.Dictionary;
const StringName = gdzig.builtin.StringName;
const Variant = gdzig.builtin.Variant;
