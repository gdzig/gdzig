pub fn ClassInfo1(comptime Userdata: type) type {
    return if (Userdata != void)
        struct {
            is_virtual: bool = false,
            is_abstract: bool = false,
            userdata: *Userdata = null,
        }
    else
        struct {
            is_virtual: bool = false,
            is_abstract: bool = false,
        };
}

pub fn ClassInfo2(comptime Userdata: type) type {
    return if (Userdata != void)
        struct {
            userdata: *Userdata = null,
            is_virtual: bool = false,
            is_abstract: bool = false,
            is_exposed: bool = true,
        }
    else
        struct {
            is_virtual: bool = false,
            is_abstract: bool = false,
            is_exposed: bool = true,
        };
}

pub fn ClassInfo3(comptime Userdata: type) type {
    return if (Userdata != void)
        struct {
            userdata: *Userdata = null,
            is_virtual: bool = false,
            is_abstract: bool = false,
            is_exposed: bool = true,
            is_runtime: bool = false,
        }
    else
        struct {
            is_virtual: bool = false,
            is_abstract: bool = false,
            is_exposed: bool = true,
            is_runtime: bool = false,
        };
}

pub fn ClassInfo4(comptime Userdata: type) type {
    return if (Userdata != void)
        struct {
            userdata: *Userdata = null,
            is_virtual: bool = false,
            is_abstract: bool = false,
            is_exposed: bool = true,
            is_runtime: bool = false,
            icon_path: ?[*:0]const u8 = null,
        }
    else
        struct {
            is_virtual: bool = false,
            is_abstract: bool = false,
            is_exposed: bool = true,
            is_runtime: bool = false,
            icon_path: ?[*:0]const u8 = null,
        };
}

pub fn ClassCallbacks1(comptime T: type, comptime ClassUserdata: type) type {
    return struct {
        create: *const Create(T, ClassUserdata),
        free: *const Free(T, ClassUserdata),

        get_virtual: ?*const GetVirtual(T, ClassUserdata) = null,

        set: ?*const Set(T) = null,
        get: ?*const Get(T) = null,
        get_property_list: ?*const GetPropertyList(T) = null,
        free_property_list: ?*const FreePropertyList(T) = null,
        property_can_revert: ?*const PropertyCanRevert(T) = null,
        property_get_revert: ?*const PropertyGetRevert(T) = null,
        notification: ?*const Notification(T) = null,
        to_string: ?*const ToString(T) = null,
        reference: ?*const Reference(T) = null,
        unreference: ?*const Unreference(T) = null,
        get_rid: ?*const GetRID(T) = null,
    };
}

pub fn ClassCallbacks2(comptime T: type, comptime ClassUserdata: type, comptime VirtualCallUserdata: type) type {
    return struct {
        create: *const Create(T, ClassUserdata),
        free: *const Free(T, ClassUserdata),
        recreate: ?*const Recreate(T, ClassUserdata) = null,

        get_virtual: ?*const GetVirtual(T, ClassUserdata) = null,
        get_virtual_call_data: ?*const GetVirtualCallData(ClassUserdata, VirtualCallUserdata) = null,
        call_virtual_with_data: ?*const CallVirtualWithData(T, VirtualCallUserdata) = null,

        set: ?*const Set(T) = null,
        get: ?*const Get(T) = null,
        get_property_list: ?*const GetPropertyList(T) = null,
        free_property_list: ?*const FreePropertyList(T) = null,
        property_can_revert: ?*const PropertyCanRevert(T) = null,
        property_get_revert: ?*const PropertyGetRevert(T) = null,
        validate_property: ?*const ValidateProperty(T) = null,
        notification: ?*const Notification2(T) = null,
        to_string: ?*const ToString(T) = null,
        reference: ?*const Reference(T) = null,
        unreference: ?*const Unreference(T) = null,
        get_rid: ?*const GetRID(T) = null,
    };
}

pub fn ClassCallbacks3(comptime T: type, comptime ClassUserdata: type, comptime VirtualCallUserdata: type) type {
    return struct {
        create: *const Create(T, ClassUserdata),
        free: *const Free(T, ClassUserdata),
        recreate: ?*const Recreate(T, ClassUserdata) = null,

        get_virtual: ?*const GetVirtual(T, ClassUserdata) = null,
        get_virtual_call_data: ?*const GetVirtualCallData(ClassUserdata, VirtualCallUserdata) = null,
        call_virtual_with_data: ?*const CallVirtualWithData(T, VirtualCallUserdata) = null,

        set: ?*const Set(T) = null,
        get: ?*const Get(T) = null,
        get_property_list: ?*const GetPropertyList(T) = null,
        free_property_list: ?*const FreePropertyList2(T) = null,
        property_can_revert: ?*const PropertyCanRevert(T) = null,
        property_get_revert: ?*const PropertyGetRevert(T) = null,
        validate_property: ?*const ValidateProperty(T) = null,
        notification: ?*const Notification2(T) = null,
        to_string: ?*const ToString(T) = null,
        reference: ?*const Reference(T) = null,
        unreference: ?*const Unreference(T) = null,
        get_rid: ?*const GetRID(T) = null,
    };
}

pub fn ClassCallbacks4(comptime T: type, comptime ClassUserdata: type, comptime VirtualCallUserdata: type) type {
    return struct {
        create: *const Create2(T, ClassUserdata),
        free: *const Free(T, ClassUserdata),
        recreate: ?*const Recreate(T, ClassUserdata) = null,

        get_virtual: ?*const GetVirtual2(T, ClassUserdata) = null,
        get_virtual_call_data: ?*const GetVirtualCallData2(T, ClassUserdata, VirtualCallUserdata) = null,
        call_virtual_with_data: ?*const CallVirtualWithData(T, VirtualCallUserdata) = null,

        set: ?*const Set(T) = null,
        get: ?*const Get(T) = null,
        get_property_list: ?*const GetPropertyList(T) = null,
        free_property_list: ?*const FreePropertyList2(T) = null,
        property_can_revert: ?*const PropertyCanRevert(T) = null,
        property_get_revert: ?*const PropertyGetRevert(T) = null,
        validate_property: ?*const ValidateProperty(T) = null,
        notification: ?*const Notification2(T) = null,
        to_string: ?*const ToString(T) = null,
        reference: ?*const Reference(T) = null,
        unreference: ?*const Unreference(T) = null,
    };
}

pub fn Set(comptime T: type) type {
    return fn (self: *T, name: *const StringName, value: *const Variant) Error!void;
}

pub fn wrapSet(comptime T: type, comptime callback: *const Set(T)) Child(c.GDExtensionClassSet) {
    return struct {
        fn wrapped(p_instance: c.GDExtensionClassInstancePtr, p_name: c.GDExtensionConstStringNamePtr, p_value: c.GDExtensionConstVariantPtr) callconv(.c) c.GDExtensionBool {
            const instance = @as(*T, @ptrCast(@alignCast(p_instance)));
            const name = @as(*const StringName, @ptrCast(p_name));
            const value = @as(*const Variant, @ptrCast(p_value));
            callback(instance, name, value) catch return 0;
            return 1;
        }
    }.wrapped;
}

pub fn Get(comptime T: type) type {
    return fn (self: *T, name: *const StringName) Error!Variant;
}

pub fn wrapGet(comptime T: type, comptime callback: *const Get(T)) Child(c.GDExtensionClassGet) {
    return struct {
        fn wrapped(p_instance: c.GDExtensionClassInstancePtr, p_name: c.GDExtensionConstStringNamePtr, r_ret: c.GDExtensionVariantPtr) callconv(.c) c.GDExtensionBool {
            const instance = @as(*T, @ptrCast(@alignCast(p_instance)));
            const name = @as(*const StringName, @ptrCast(p_name));
            const ret = @as(*Variant, @ptrCast(@alignCast(r_ret)));
            ret.* = callback(instance, name) catch return 0;
            return 1;
        }
    }.wrapped;
}

pub fn GetRID(comptime T: type) type {
    return fn (self: *T) builtin.RID;
}

pub fn wrapGetRID(comptime T: type, comptime callback: *const GetRID(T)) Child(c.GDExtensionClassGetRID) {
    return struct {
        fn wrapped(p_instance: c.GDExtensionClassInstancePtr) callconv(.c) u64 {
            const instance = @as(*T, @ptrCast(@alignCast(p_instance)));
            const rid = callback(instance);
            return @bitCast(rid);
        }
    }.wrapped;
}

pub fn GetPropertyList(comptime T: type) type {
    return fn (self: *T) []PropertyInfo;
}

pub fn wrapGetPropertyList(comptime T: type, comptime callback: *const GetPropertyList(T)) Child(c.GDExtensionClassGetPropertyList) {
    return struct {
        fn wrapped(p_instance: c.GDExtensionClassInstancePtr, r_count: *u32) callconv(.c) ?*const c.GDExtensionPropertyInfo {
            const instance = @as(*T, @ptrCast(@alignCast(p_instance)));
            const list = callback(instance);
            r_count.* = @intCast(list.len);
            if (list.len == 0) return null;
            return @ptrCast(list.ptr);
        }
    }.wrapped;
}

pub fn FreePropertyList(comptime T: type) type {
    return fn (self: *T, list: [*]PropertyInfo) void;
}

pub fn wrapFreePropertyList(comptime T: type, comptime callback: *const FreePropertyList(T)) Child(c.GDExtensionClassFreePropertyList) {
    return struct {
        fn wrapped(p_instance: c.GDExtensionClassInstancePtr, p_list: ?*const c.GDExtensionPropertyInfo) callconv(.c) void {
            const instance = @as(*T, @ptrCast(@alignCast(p_instance)));
            if (p_list) |list| {
                callback(instance, @ptrCast(list));
            }
        }
    }.wrapped;
}

pub fn FreePropertyList2(comptime T: type) type {
    return fn (self: *T, list: []const PropertyInfo) void;
}

pub fn wrapFreePropertyList2(comptime T: type, comptime callback: *const FreePropertyList2(T)) Child(c.GDExtensionClassFreePropertyList2) {
    return struct {
        fn wrapped(p_instance: c.GDExtensionClassInstancePtr, p_list: ?*const c.GDExtensionPropertyInfo, p_count: u32) callconv(.c) void {
            const instance = @as(*T, @ptrCast(@alignCast(p_instance)));
            if (p_list) |list| {
                const slice = @as([*]const PropertyInfo, @ptrCast(list))[0..p_count];
                callback(instance, slice);
            }
        }
    }.wrapped;
}

pub fn PropertyCanRevert(comptime T: type) type {
    return fn (self: *T, name: *const StringName) bool;
}

pub fn wrapPropertyCanRevert(comptime T: type, comptime callback: *const PropertyCanRevert(T)) Child(c.GDExtensionClassPropertyCanRevert) {
    return struct {
        fn wrapped(p_instance: c.GDExtensionClassInstancePtr, p_name: c.GDExtensionConstStringNamePtr) callconv(.c) c.GDExtensionBool {
            const instance = @as(*T, @ptrCast(@alignCast(p_instance)));
            const name = @as(*const StringName, @ptrCast(p_name));
            return if (callback(instance, name)) 1 else 0;
        }
    }.wrapped;
}

pub fn PropertyGetRevert(comptime T: type) type {
    return fn (self: *T, name: *const StringName) Error!Variant;
}

pub fn wrapPropertyGetRevert(comptime T: type, comptime callback: *const PropertyGetRevert(T)) Child(c.GDExtensionClassPropertyGetRevert) {
    return struct {
        fn wrapped(p_instance: c.GDExtensionClassInstancePtr, p_name: c.GDExtensionConstStringNamePtr, r_ret: c.GDExtensionVariantPtr) callconv(.c) c.GDExtensionBool {
            const instance = @as(*T, @ptrCast(@alignCast(p_instance)));
            const name = @as(*const StringName, @ptrCast(p_name));
            const ret = @as(*Variant, @ptrCast(@alignCast(r_ret)));
            ret.* = callback(instance, name) catch return 0;
            return 1;
        }
    }.wrapped;
}

pub fn ValidateProperty(comptime T: type) type {
    return fn (self: *T, property: *PropertyInfo) bool;
}

pub fn wrapValidateProperty(comptime T: type, comptime callback: *const ValidateProperty(T)) Child(c.GDExtensionClassValidateProperty) {
    return struct {
        fn wrapped(p_instance: c.GDExtensionClassInstancePtr, p_property: *c.GDExtensionPropertyInfo) callconv(.c) c.GDExtensionBool {
            const instance = @as(*T, @ptrCast(@alignCast(p_instance)));
            const property = @as(*PropertyInfo, @ptrCast(p_property));
            return if (callback(instance, property)) 1 else 0;
        }
    }.wrapped;
}

pub fn Notification(comptime T: type) type {
    return fn (self: *T, what: i32) void;
}

pub fn wrapNotification(comptime T: type, comptime callback: *const Notification(T)) Child(c.GDExtensionClassNotification) {
    return struct {
        fn wrapped(p_instance: c.GDExtensionClassInstancePtr, p_what: i32) callconv(.c) void {
            const instance = @as(*T, @ptrCast(@alignCast(p_instance)));
            callback(instance, p_what);
        }
    }.wrapped;
}

pub fn Notification2(comptime T: type) type {
    return fn (self: *T, what: i32, reversed: bool) void;
}

pub fn wrapNotification2(comptime T: type, comptime callback: *const Notification2(T)) Child(c.GDExtensionClassNotification2) {
    return struct {
        fn wrapped(p_instance: c.GDExtensionClassInstancePtr, p_what: i32, p_reversed: c.GDExtensionBool) callconv(.c) void {
            const instance = @as(*T, @ptrCast(@alignCast(p_instance)));
            callback(instance, p_what, p_reversed != 0);
        }
    }.wrapped;
}

pub fn ToString(comptime T: type) type {
    return fn (self: *T) Error!String;
}

pub fn wrapToString(comptime T: type, comptime callback: *const ToString(T)) Child(c.GDExtensionClassToString) {
    return struct {
        fn wrapped(p_instance: c.GDExtensionClassInstancePtr, r_is_valid: *c.GDExtensionBool, p_out: c.GDExtensionStringPtr) callconv(.c) void {
            const instance = @as(*T, @ptrCast(@alignCast(p_instance)));
            const out = @as(*String, @ptrCast(@alignCast(p_out)));
            if (callback(instance)) |str| {
                out.* = str;
                r_is_valid.* = 1;
            } else |_| {
                r_is_valid.* = 0;
            }
        }
    }.wrapped;
}

pub fn Reference(comptime T: type) type {
    return fn (self: *T) void;
}

pub fn wrapReference(comptime T: type, comptime callback: *const Reference(T)) Child(c.GDExtensionClassReference) {
    return struct {
        fn wrapped(p_instance: c.GDExtensionClassInstancePtr) callconv(.c) void {
            const instance = @as(*T, @ptrCast(@alignCast(p_instance)));
            callback(instance);
        }
    }.wrapped;
}

pub fn Unreference(comptime T: type) type {
    return fn (self: *T) void;
}

pub fn wrapUnreference(comptime T: type, comptime callback: *const Unreference(T)) Child(c.GDExtensionClassUnreference) {
    return struct {
        fn wrapped(p_instance: c.GDExtensionClassInstancePtr) callconv(.c) void {
            const instance = @as(*T, @ptrCast(@alignCast(p_instance)));
            callback(instance);
        }
    }.wrapped;
}

pub fn CallVirtual(comptime T: type) type {
    return fn (self: *T, args: [*]const *const anyopaque, ret: *anyopaque) void;
}

pub fn wrapCallVirtual(comptime T: type, comptime callback: *const CallVirtual(T)) Child(c.GDExtensionClassCallVirtual) {
    return struct {
        fn wrapped(p_instance: c.GDExtensionClassInstancePtr, p_args: [*c]const c.GDExtensionConstTypePtr, r_ret: c.GDExtensionTypePtr) callconv(.c) void {
            const instance = @as(*T, @ptrCast(@alignCast(p_instance)));
            callback(instance, @ptrCast(p_args), @ptrCast(r_ret));
        }
    }.wrapped;
}

pub fn Create(comptime T: type, comptime ClassUserdata: type) type {
    if (ClassUserdata != void) {
        return fn (userdata: *ClassUserdata) *T;
    } else {
        return fn () *T;
    }
}

pub fn wrapCreateInstance(comptime T: type, comptime ClassUserdata: type, comptime callback: *const Create(T, ClassUserdata)) Child(c.GDExtensionClassCreateInstance) {
    return struct {
        fn wrapped(p_class_userdata: ?*anyopaque) callconv(.c) c.GDExtensionObjectPtr {
            if (ClassUserdata != void) {
                const userdata = @as(*ClassUserdata, @ptrCast(@alignCast(p_class_userdata)));
                const instance = callback(userdata);
                return @ptrCast(instance);
            } else {
                const instance = callback();
                return @ptrCast(instance);
            }
        }
    }.wrapped;
}

pub fn Create2(comptime T: type, comptime ClassUserdata: type) type {
    if (ClassUserdata != void) {
        return fn (userdata: *ClassUserdata, notify_postinitialize: bool) *T;
    } else {
        return fn (notify_postinitialize: bool) *T;
    }
}

pub fn wrapCreateInstance2(comptime T: type, comptime ClassUserdata: type, comptime callback: *const Create2(T, ClassUserdata)) Child(c.GDExtensionClassCreateInstance2) {
    return struct {
        fn wrapped(p_class_userdata: ?*anyopaque, p_notify_postinitialize: c.GDExtensionBool) callconv(.c) c.GDExtensionObjectPtr {
            if (ClassUserdata != void) {
                const userdata = @as(*ClassUserdata, @ptrCast(@alignCast(p_class_userdata)));
                const instance = callback(userdata, p_notify_postinitialize != 0);
                return @ptrCast(instance);
            } else {
                const instance = callback(p_notify_postinitialize != 0);
                return @ptrCast(instance);
            }
        }
    }.wrapped;
}

pub fn Free(comptime T: type, comptime ClassUserdata: type) type {
    if (ClassUserdata != void) {
        return fn (userdata: *ClassUserdata, instance: *T) void;
    } else {
        return fn (instance: *T) void;
    }
}

pub fn wrapFreeInstance(comptime T: type, comptime ClassUserdata: type, comptime callback: *const Free(T, ClassUserdata)) Child(c.GDExtensionClassFreeInstance) {
    return struct {
        fn wrapped(p_class_userdata: ?*anyopaque, p_instance: c.GDExtensionClassInstancePtr) callconv(.c) void {
            const instance = @as(*T, @ptrCast(@alignCast(p_instance)));
            if (ClassUserdata != void) {
                const userdata = @as(*ClassUserdata, @ptrCast(@alignCast(p_class_userdata)));
                callback(userdata, instance);
            } else {
                callback(instance);
            }
        }
    }.wrapped;
}

pub fn Recreate(comptime T: type, comptime ClassUserdata: type) type {
    if (ClassUserdata != void) {
        return fn (userdata: *ClassUserdata, object: *Object) *T;
    } else {
        return fn (object: *Object) *T;
    }
}

pub fn wrapRecreateInstance(comptime T: type, comptime ClassUserdata: type, comptime callback: *const Recreate(T, ClassUserdata)) Child(c.GDExtensionClassRecreateInstance) {
    return struct {
        fn wrapped(p_class_userdata: ?*anyopaque, p_object: c.GDExtensionObjectPtr) callconv(.c) c.GDExtensionClassInstancePtr {
            const object = @as(*Object, @ptrCast(@alignCast(p_object)));
            if (ClassUserdata != void) {
                const userdata = @as(*ClassUserdata, @ptrCast(@alignCast(p_class_userdata)));
                const instance = callback(userdata, object);
                return @ptrCast(instance);
            } else {
                const instance = callback(object);
                return @ptrCast(instance);
            }
        }
    }.wrapped;
}

pub fn GetVirtual(comptime T: type, comptime ClassUserdata: type) type {
    if (ClassUserdata != void) {
        return fn (userdata: *ClassUserdata, name: *const StringName) ?*const CallVirtual(T);
    } else {
        return fn (name: *const StringName) ?*const CallVirtual(T);
    }
}

pub fn wrapGetVirtual(comptime T: type, comptime ClassUserdata: type, comptime callback: *const GetVirtual(T, ClassUserdata)) Child(c.GDExtensionClassGetVirtual) {
    return struct {
        fn wrapped(p_class_userdata: ?*anyopaque, p_name: c.GDExtensionConstStringNamePtr) callconv(.c) c.GDExtensionClassCallVirtual {
            const name = @as(*const StringName, @ptrCast(p_name));
            var virtual: ?*const CallVirtual(T) = undefined;
            if (ClassUserdata != void) {
                const userdata = @as(*ClassUserdata, @ptrCast(@alignCast(p_class_userdata)));
                virtual = callback(userdata, name);
            } else {
                virtual = callback(name);
            }
            if (virtual) |v| {
                return @ptrCast(&wrapCallVirtual(T, v));
            }
            return null;
        }
    }.wrapped;
}

pub fn GetVirtual2(comptime T: type, comptime ClassUserdata: type) type {
    if (ClassUserdata != void) {
        return fn (userdata: *ClassUserdata, name: *const StringName, hash: u32) ?*const CallVirtual(T);
    } else {
        return fn (name: *const StringName, hash: u32) ?*const CallVirtual(T);
    }
}

pub fn wrapGetVirtual2(comptime T: type, comptime ClassUserdata: type, comptime callback: *const GetVirtual2(T, ClassUserdata)) Child(c.GDExtensionClassGetVirtual2) {
    return struct {
        fn wrapped(p_class_userdata: ?*anyopaque, p_name: c.GDExtensionConstStringNamePtr, p_hash: u32) callconv(.c) c.GDExtensionClassCallVirtual {
            const name = @as(*const StringName, @ptrCast(p_name));
            var virtual: ?*const CallVirtual(T) = undefined;
            if (ClassUserdata != void) {
                const userdata = @as(*ClassUserdata, @ptrCast(@alignCast(p_class_userdata)));
                virtual = callback(userdata, name, p_hash);
            } else {
                virtual = callback(name, p_hash);
            }
            if (virtual) |v| {
                return @ptrCast(&wrapCallVirtual(T, v));
            }
            return null;
        }
    }.wrapped;
}

pub fn GetVirtualCallData(comptime ClassUserdata: type, comptime VirtualCallUserdata: type) type {
    if (ClassUserdata != void) {
        return fn (userdata: *ClassUserdata, name: *const StringName) ?*VirtualCallUserdata;
    } else {
        return fn (name: *const StringName) ?*VirtualCallUserdata;
    }
}

pub fn wrapGetVirtualCallData(comptime ClassUserdata: type, comptime VirtualCallUserdata: type, comptime callback: *const GetVirtualCallData(ClassUserdata, VirtualCallUserdata)) Child(c.GDExtensionClassGetVirtualCallData) {
    return struct {
        fn wrapped(p_class_userdata: ?*anyopaque, p_name: c.GDExtensionConstStringNamePtr) callconv(.c) ?*anyopaque {
            const name = @as(*const StringName, @ptrCast(p_name));
            if (ClassUserdata != void) {
                const userdata = @as(*ClassUserdata, @ptrCast(@alignCast(p_class_userdata)));
                return callback(userdata, name);
            } else {
                return callback(name);
            }
        }
    }.wrapped;
}

pub fn GetVirtualCallData2(comptime ClassUserdata: type, comptime VirtualCallUserdata: type) type {
    if (ClassUserdata != void) {
        return fn (userdata: *ClassUserdata, name: *const StringName, hash: u32) ?*VirtualCallUserdata;
    } else {
        return fn (name: *const StringName, hash: u32) ?*VirtualCallUserdata;
    }
}

pub fn wrapGetVirtualCallData2(comptime T: type, comptime ClassUserdata: type, comptime VirtualCallUserdata: type, comptime callback: *const GetVirtualCallData2(T, ClassUserdata, VirtualCallUserdata)) Child(c.GDExtensionClassGetVirtualCallData2) {
    return struct {
        fn wrapped(p_class_userdata: ?*anyopaque, p_name: c.GDExtensionConstStringNamePtr, p_hash: u32) callconv(.c) ?*anyopaque {
            const name = @as(*const StringName, @ptrCast(p_name));
            if (ClassUserdata != void) {
                const userdata = @as(*ClassUserdata, @ptrCast(@alignCast(p_class_userdata)));
                return callback(userdata, name, p_hash);
            } else {
                return callback(name, p_hash);
            }
        }
    }.wrapped;
}

pub fn CallVirtualWithData(comptime T: type, comptime VirtualCallUserdata: type) type {
    if (VirtualCallUserdata != void) {
        return fn (instance: *T, name: *const StringName, virtual_call_userdata: *VirtualCallUserdata, args: [*]const *const anyopaque, ret: *anyopaque) void;
    } else {
        return fn (instance: *T, name: *const StringName, args: [*]const *const anyopaque, ret: *anyopaque) void;
    }
}

pub fn wrapCallVirtualWithData(comptime T: type, comptime VirtualCallUserdata: type, comptime callback: *const CallVirtualWithData(T, VirtualCallUserdata)) Child(c.GDExtensionClassCallVirtualWithData) {
    return struct {
        fn wrapped(p_instance: c.GDExtensionClassInstancePtr, p_name: c.GDExtensionConstStringNamePtr, p_virtual_call_userdata: ?*anyopaque, p_args: [*c]const c.GDExtensionConstTypePtr, r_ret: c.GDExtensionTypePtr) callconv(.c) void {
            const instance = @as(*T, @ptrCast(@alignCast(p_instance)));
            const name = @as(*const StringName, @ptrCast(p_name));
            if (VirtualCallUserdata != void) {
                const userdata = @as(*VirtualCallUserdata, @ptrCast(@alignCast(p_virtual_call_userdata)));
                callback(instance, name, userdata, @ptrCast(p_args), @ptrCast(r_ret));
            } else {
                callback(instance, name, @ptrCast(p_args), @ptrCast(r_ret));
            }
        }
    }.wrapped;
}

const std = @import("std");
const Child = std.meta.Child;

const c = @import("gdextension");

const api = @import("../../api.zig");
const CallError = api.CallError;
const Error = api.Error;
const PropertyInfo = api.PropertyInfo;
const builtin = @import("../../builtin.zig");
const StringName = builtin.StringName;
const String = builtin.String;
const Variant = builtin.Variant;
const class = @import("../../class.zig");
const Object = class.Object;
const global = @import("../../global.zig");
const Interface = @import("../../Interface.zig");
const ClassLibrary = Interface.ClassLibrary;
