const raw: *Interface = &@import("../../gdzig_bindings.zig").raw;

pub const ObjectID = enum(u63) {
    _,

    pub fn toOptional(i: ObjectID) OptionalObjectID {
        const result: OptionalObjectID = @enumFromInt(@intFromEnum(i));
        assert(result != .none);
        return result;
    }
};

pub const OptionalObjectID = enum(u64) {
    none = 0,
    _,

    pub fn unwrap(i: OptionalObjectID) ?ObjectID {
        if (i == .none) return null;
        return @enumFromInt(@intFromEnum(i));
    }
};

pub fn InstanceBindingCallbacks(comptime Token: type, comptime Binding: type) type {
    return struct {
        create: ?*const Create(Token, Binding) = null,
        free: ?*const Free(Token, Binding) = null,
        reference: ?*const Reference(Token, Binding) = null,
    };
}

pub fn Create(comptime Token: type, comptime Binding: type) type {
    return fn (token: *Token, instance: *Object) *Binding;
}

pub fn wrapCreate(comptime Token: type, comptime Binding: type, comptime callback: *const Create(Token, Binding)) Child(c.GDExtensionInstanceBindingCreateCallback) {
    return struct {
        fn wrapped(p_token: ?*anyopaque, p_instance: ?*anyopaque) callconv(.c) ?*anyopaque {
            const instance = @as(*Object, @ptrCast(@alignCast(p_instance)));
            const token = @as(*Token, @ptrCast(@alignCast(p_token)));
            const result = callback(token, instance);

            if (result) |binding| {
                return @ptrCast(binding);
            } else {
                return null;
            }
        }
    }.wrapped;
}

pub fn Free(comptime Token: type, comptime Binding: type) type {
    return fn (token: *Token, instance: *Object, binding: *Binding) void;
}

pub fn wrapFree(comptime Token: type, comptime Binding: type, comptime callback: *const Free(Token, Binding)) Child(c.GDExtensionInstanceBindingFreeCallback) {
    return struct {
        fn wrapped(p_token: ?*anyopaque, p_instance: ?*anyopaque, p_binding: ?*anyopaque) callconv(.c) void {
            const instance = @as(*Object, @ptrCast(@alignCast(p_instance)));
            const binding = @as(*Binding, @ptrCast(@alignCast(p_binding)));
            const token = @as(*Token, @ptrCast(@alignCast(p_token)));
            callback(token, instance, binding);
        }
    }.wrapped;
}

pub fn Reference(comptime Token: type, comptime Binding: type) type {
    return fn (token: *Token, binding: *Binding, reference: bool) bool;
}

pub fn wrapReference(comptime Token: type, comptime Binding: type, comptime callback: *const Reference(Token, Binding)) Child(c.GDExtensionInstanceBindingReferenceCallback) {
    return struct {
        fn wrapped(p_token: ?*anyopaque, p_binding: ?*anyopaque, p_reference: c.GDExtensionBool) callconv(.c) c.GDExtensionBool {
            const binding = @as(*Binding, @ptrCast(@alignCast(p_binding)));
            const reference = p_reference != 0;
            const token = @as(*Token, @ptrCast(@alignCast(p_token)));
            const result = callback(token, binding, reference);

            return if (result) 1 else 0;
        }
    }.wrapped;
}

/// Gets the instance ID from an Object.
///
/// @param obj A pointer to the Object.
///
/// @return The instance ID.
///
/// @since 4.1
pub inline fn objectGetInstanceId(obj: *const Object) ObjectID {
    return raw.objectGetInstanceId(obj);
}

/// Gets an Object by its instance ID.
///
/// @param instance_id The instance ID.
///
/// @return A pointer to the Object, or null if it can't be found.
///
/// @since 4.1
pub inline fn objectGetInstanceFromId(id: ObjectID) ?*Object {
    return @ptrCast(raw.objectGetInstanceFromId(id));
}

/// Destroys an Object.
///
/// @param obj A pointer to the Object.
///
/// @since 4.1
pub inline fn objectDestroy(obj: *Object) void {
    raw.objectDestroy(obj);
}

/// Gets a global singleton by name.
///
/// @param name A pointer to a StringName with the singleton name.
///
/// @return A pointer to the singleton Object.
///
/// @since 4.1
pub inline fn globalGetSingleton(name: *const StringName) ?*Object {
    return @ptrCast(raw.globalGetSingleton(name.constPtr()));
}

/// Gets the class name of an Object.
///
/// If the GDExtension wraps the Godot object in an abstraction specific to its class, this is the
/// function that should be used to determine which wrapper to use.
///
/// @param object A pointer to the Object.
///
/// @return The class name as a StringName.
///
/// @since 4.1
pub inline fn objectGetClassName(object: *const Object) StringName {
    var result: StringName = undefined;
    raw.objectGetClassName(object.constPtr(), raw.getLibraryPath, result.ptr());
    return result;
}

/// Casts an Object to a different type.
///
/// @param object A pointer to the Object.
/// @param class_tag A pointer uniquely identifying a built-in class in the ClassDB.
///
/// @return Returns a pointer to the Object, or null if it can't be cast to the requested type.
///
/// @since 4.1
pub inline fn objectCastTo(object: *const Object, class_tag: *ClassTag) ?*Object {
    return @ptrCast(raw.objectCastTo(object.constPtr(), class_tag));
}

/// Checks if this object has a script with the given method.
///
/// @param object A pointer to the Object.
/// @param method A pointer to a StringName identifying the method.
///
/// @return true if the object has a script and that script has a method with the given name. Returns false if the object has no script.
///
/// @since 4.3
pub inline fn objectHasScriptMethod(object: *const Object, method: *const StringName) bool {
    return raw.objectHasScriptMethod(object.constPtr(), method.constPtr()) != 0;
}

/// Call the given script method on this object.
///
/// @param object A pointer to the Object.
/// @param method A pointer to a StringName identifying the method.
/// @param args A slice of Variant pointers representing the arguments.
///
/// @return The return value from the method call.
///
/// @since 4.3
pub inline fn objectCallScriptMethod(object: *Object, method: *const StringName, args: []const *const Variant) CallError!Variant {
    var ret: Variant = undefined;
    var result: CallResult = undefined;

    raw.objectCallScriptMethod(object.ptr(), method.constPtr(), @ptrCast(args.ptr), @intCast(args.len), ret.ptr(), &result);

    try result.throw();

    return ret;
}

/// Sets an extension class instance on a Object.
///
/// @param object A pointer to the Object.
/// @param class_name A pointer to a StringName with the registered extension class's name.
/// @param instance A pointer to the extension class instance (can be null).
///
/// @since 4.1
pub inline fn objectSetInstance(object: *Object, class_name: *const StringName, instance: ?*anyopaque) void {
    raw.objectSetInstance(object.ptr(), class_name.constPtr(), instance);
}

/// Gets a pointer representing an Object's instance binding.
///
/// @param object A pointer to the Object.
/// @param callbacks A pointer to a GDExtensionInstanceBindingCallbacks struct.
///
/// @return A pointer to the instance binding.
///
/// @since 4.1
pub inline fn objectGetInstanceBinding(comptime Token: type, comptime Binding: type, object: *Object, callbacks: *const InstanceBindingCallbacks(Token, Binding)) ?*anyopaque {
    if (callbacks) |cb| {
        const c_callbacks = c.GDExtensionInstanceBindingCallbacks{
            .create_callback = if (cb.create) |f| @ptrCast(&wrapCreate(Token, Binding, f)) else null,
            .free_callback = if (cb.free) |f| @ptrCast(&wrapFree(Token, Binding, f)) else null,
            .reference_callback = if (cb.reference) |f| @ptrCast(&wrapReference(Token, Binding, f)) else null,
        };
        return raw.objectGetInstanceBinding(object.ptr(), raw.library.ptr(), &c_callbacks);
    } else {
        return raw.objectGetInstanceBinding(object.ptr(), raw.library.ptr(), null);
    }
}

/// Sets an Object's instance binding.
///
/// @param object A pointer to the Object.
/// @param binding A pointer to the instance binding.
/// @param callbacks An optional pointer to a GDExtensionInstanceBindingCallbacks struct.
///
/// @since 4.1
pub inline fn objectSetInstanceBinding(comptime Token: type, comptime Binding: type, object: *Object, binding: *anyopaque, callbacks: *const InstanceBindingCallbacks(Token, Binding)) void {
    if (callbacks) |cb| {
        const c_callbacks = c.GDExtensionInstanceBindingCallbacks{
            .create_callback = if (cb.create) |f| @ptrCast(&wrapCreate(Token, Binding, f)) else null,
            .free_callback = if (cb.free) |f| @ptrCast(&wrapFree(Token, Binding, f)) else null,
            .reference_callback = if (cb.reference) |f| @ptrCast(&wrapReference(Token, Binding, f)) else null,
        };
        raw.objectSetInstanceBinding(object.ptr(), raw.library.ptr(), binding, &c_callbacks);
    } else {
        raw.objectSetInstanceBinding(object.ptr(), raw.library.ptr(), binding, null);
    }
}

/// Free an Object's instance binding.
///
/// @param object A pointer to the Object.
///
/// @since 4.2
pub inline fn objectFreeInstanceBinding(object: *Object) void {
    raw.objectFreeInstanceBinding(object.ptr(), raw.library.ptr());
}

/// Calls a method on an Object.
///
/// @param method_bind A pointer to the MethodBind representing the method on the Object's class.
/// @param instance A pointer to the Object (can be null for static methods).
/// @param args A slice of Variant pointers representing the arguments.
///
/// @return The return value from the method call.
///
/// @since 4.1
pub inline fn objectMethodBindCall(method_bind: *MethodBind, instance: ?*Object, args: []const *const Variant) CallError!Variant {
    var ret: Variant = undefined;
    var err: CallResult = undefined;

    raw.objectMethodBindCall(
        method_bind.ptr(),
        if (instance) |i| i.ptr() else null,
        @ptrCast(args.ptr),
        @intCast(args.len),
        ret.ptr(),
        err.ptr(),
    );

    try err.throw();

    return ret;
}

/// Calls a method on an Object (using a "ptrcall").
///
/// @param method_bind A pointer to the MethodBind representing the method on the Object's class.
/// @param instance A pointer to the Object (can be null for static methods).
/// @param args A slice of pointers representing the arguments.
/// @param ret A pointer that will receive the return value (can be null).
///
/// @since 4.1
pub inline fn objectMethodBindPtrcall(method_bind: *MethodBind, instance: ?*Object, args: []const *const anyopaque, ret: ?*anyopaque) void {
    raw.objectMethodBindPtrcall(
        method_bind.ptr(),
        if (instance) |i| i.ptr() else null,
        @ptrCast(args.ptr),
        ret,
    );
}

/// Get the script instance data attached to this object.
///
/// @param object A pointer to the Object.
/// @param language A pointer to the language expected for this script instance.
///
/// @return A GDExtensionScriptInstanceDataPtr that was attached to this object as part of script_instance_create.
///
/// @since 4.2
pub inline fn objectGetScriptInstance(object: *const Object, language: *Object) ?*ScriptInstance {
    return @ptrCast(raw.objectGetScriptInstance(object.constPtr(), language.ptr()));
}

const std = @import("std");
const Child = std.meta.Child;
const assert = std.debug.assert;

const c = @import("gdextension");

const api = @import("../api.zig");
const ClassTag = api.ClassTag;
const MethodBind = api.classdb.MethodBind;
const CallResult = api.CallResult;
const CallError = api.CallError;
const builtin = @import("../builtin.zig");
const StringName = builtin.StringName;
const Variant = builtin.Variant;
const class = @import("../class.zig");
const ScriptInstance = class.ScriptInstance;
const Object = class.Object;
const Interface = @import("../Interface.zig");
