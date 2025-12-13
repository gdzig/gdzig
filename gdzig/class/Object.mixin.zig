// @mixin start

/// Upcasts a child type to this type.
pub fn upcast(value: anytype) *Self {
    return oopz.upcast(*Self, value);
}

/// Downcasts a parent type to this type.
///
/// This operation will fail at compile time if Self does not inherit from `@TypeOf(value)`. However,
/// since there is no guarantee that `value` is this type at runtime, this function has a runtime cost
/// and may return `null`.
pub fn downcast(value: anytype) ?*Self {
    const T = comptime sw: switch (@typeInfo(@TypeOf(value))) {
        .optional => |info| continue :sw @typeInfo(info.child),
        .pointer => |info| break :sw info.child,
        else => @compileError("downcasted value should be a pointer, found '" ++ @typeName(@TypeOf(value)) ++ "'"),
    };
    comptime oopz.assertIsA(T, Self);
    const tag = raw.classdbGetClassTag(@ptrCast(&StringName.fromComptimeLatin1(self_name)));
    const result = raw.objectCastTo(@ptrCast(value), tag);
    if (result) |p| {
        if (oopz.isOpaqueClass(T)) {
            return @ptrCast(@alignCast(p));
        } else {
            const object: *anyopaque = raw.objectGetInstanceBinding(p, raw.library, null) orelse return null;
            return @ptrCast(@alignCast(object));
        }
    } else {
        return null;
    }
}

/// Returns an opaque pointer to the object.
pub fn ptr(self: *Self) *anyopaque {
    return @ptrCast(self);
}

/// Returns a constant opaque pointer to the object.
pub fn constPtr(self: *const Self) *const anyopaque {
    return @ptrCast(self);
}

// @mixin stop

const oopz = @import("oopz");
const raw = &@import("../gdzig.zig").raw;
const StringName = @import("../builtin.zig").StringName;

const Self = @import("./object.zig").Object;
const self_name = "Object";
