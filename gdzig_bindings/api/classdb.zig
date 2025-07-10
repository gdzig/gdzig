const raw: *Interface = &@import("../../gdzig_bindings.zig").raw;

pub const ClassTag = opaque {
    pub inline fn ptr(self: *@This()) c.GDExtensionClassTagPtr {
        return @ptrCast(self);
    }
};

pub const MethodBind = opaque {
    pub inline fn ptr(self: *const @This()) c.GDExtensionMethodBindPtr {
        return @ptrCast(self);
    }
};

/// **Deprecated** in Godot 4.4. Use `classdbConstructObject2` instead.
///
/// Constructs an Object of the requested class.
///
/// The passed class must be a built-in godot class, or an already-registered extension class. In both cases, object_set_instance() should be called to fully initialize the object.
///
/// @param class_name A pointer to a StringName with the class name.
///
/// @return A pointer to the newly created Object.
///
/// @since 4.1
pub inline fn classdbConstructObject(class_name: *const StringName) ?*Object {
    return @ptrCast(raw.classdbConstructObject(class_name.constPtr()));
}

/// Constructs an Object of the requested class.
///
/// The passed class must be a built-in godot class, or an already-registered extension class. In both cases, object_set_instance() should be called to fully initialize the object.
///
/// "NOTIFICATION_POSTINITIALIZE" must be sent after construction.
///
/// @param class_name A pointer to a StringName with the class name.
///
/// @return A pointer to the newly created Object.
///
/// @since 4.4
pub inline fn classdbConstructObject2(class_name: *const StringName) ?*Object {
    return @ptrCast(raw.classdbConstructObject2(class_name.constPtr()));
}

/// Gets a pointer uniquely identifying the given built-in class in the ClassDB.
///
/// @param class_name A pointer to a StringName with the class name.
///
/// @return A pointer uniquely identifying the built-in class in the ClassDB.
///
/// @since 4.1
pub inline fn classdbGetClassTag(class_name: *const StringName) ?*ClassTag {
    return @ptrCast(raw.classdbGetClassTag(class_name.constPtr()));
}

/// Gets a pointer to the MethodBind in ClassDB for the given class, method and hash.
///
/// @param classname A pointer to a StringName with the class name.
/// @param methodname A pointer to a StringName with the method name.
/// @param hash A hash representing the function signature.
///
/// @return A pointer to the MethodBind from ClassDB.
///
/// @since 4.1
pub inline fn classdbGetMethodBind(class_name: *const StringName, method_name: *const StringName, hash: i64) ?*MethodBind {
    const ptr = raw.classdbGetMethodBind(class_name.constPtr(), method_name.constPtr(), hash);
    return ptr;
}

const c = @import("gdextension");

const builtin = @import("../builtin.zig");
const StringName = builtin.StringName;
const Variant = builtin.Variant;
const String = builtin.String;
const class = @import("../class.zig");
const Object = class.Object;
const global = @import("../global.zig");
const PropertyHint = global.PropertyHint;
const PropertyUsageFlags = global.PropertyUsageFlags;
const Interface = @import("../Interface.zig");
