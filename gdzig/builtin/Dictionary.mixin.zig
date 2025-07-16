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
    const typeName = @import("../gdzig.zig").typeName;

    const key_tag = Variant.Tag.forType(K);
    const value_tag = Variant.Tag.forType(V);
    const key_class_name = typeName(K);
    const value_class_name = typeName(V);

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

const raw: *Interface = &@import("../gdzig.zig").raw;

const builtin = @import("../builtin.zig");
const Array = builtin.Array;
const Dictionary = builtin.Dictionary;
const StringName = builtin.StringName;
const Variant = builtin.Variant;
const Interface = @import("../Interface.zig");
