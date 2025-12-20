/// Sets an Array to be a reference to another Array object.
///
/// - **from**: A pointer to the Array object to reference.
///
/// **Since Godot 4.1**
pub inline fn ref(self: *Array, from: *const Array) void {
    raw.arrayRef(self.ptr(), from.constPtr());
}

/// Makes an Array into a typed Array.
///
/// - **T**: The type of `Variant` the `Array` will store.
/// - **script**: An optional pointer to a `Script` object (if tag is `.object` and the base class is extended by a script).
///
/// **Since Godot 4.1**
pub inline fn setTyped(self: *Array, comptime T: type, script: ?*const Variant) void {
    const tag = Variant.Tag.forType(T);
    const name: StringName = .fromType(T);
    raw.arraySetTyped(self.ptr(), @intFromEnum(tag), if (tag == .object) name.constPtr() else null, if (script) |s| s.constPtr() else null);
}

/// Gets a pointer to a Variant in an Array.
///
/// - **index**: The index of the Variant to get.
///
/// **Since Godot 4.1**
pub inline fn index(self: *Array, index_: usize) *Variant {
    return @ptrCast(raw.arrayOperatorIndex(self.ptr(), @intCast(index_)));
}

/// Gets a const pointer to a Variant in an Array.
///
/// - **index**: The index of the Variant to get.
///
/// **Since Godot 4.1**
pub inline fn indexConst(self: *const Array, index_: usize) *const Variant {
    return @ptrCast(raw.arrayOperatorIndexConst(self.constPtr(), @intCast(index_)));
}

// @mixin stop

const Self = gdzig.builtin.Array;

const gdzig = @import("gdzig");
const raw = &gdzig.raw;
const Array = gdzig.builtin.Array;
const StringName = gdzig.builtin.StringName;
const Variant = gdzig.builtin.Variant;
