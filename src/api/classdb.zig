//! These functions and types are very thin wrappers around the Godot C API to expose a Zig friendly
//! interface. They do not add any additional functionality, other than what is strictly necessary to
//! create an idiomatic interface.
//!
//! If you're looking for the raw C APIs without any wrappers, you can find them exposed in the
//! `godot.c` module.
//!

pub const ClassCreationInfo = if (@hasDecl(c, "GDExtensionClassCreationInfo4"))
    ClassCreationInfo4
else if (@hasDecl(c, "GDExtensionClassCreationInfo3"))
    ClassCreationInfo3
else if (@hasDecl(c, "GDExtensionClassCreationInfo2"))
    ClassCreationInfo2
else if (@hasDecl(c, "GDExtensionClassCreationInfo"))
    ClassCreationInfo1
else
    @compileError("Godot version 4.1 or higher is required.");

pub const ClassUserdata = if (@hasDecl(godot.c, "GDExtensionClassCreationInfo4"))
    ClassUserdata4
else if (@hasDecl(godot.c, "GDExtensionClassCreationInfo3"))
    ClassUserdata3
else if (@hasDecl(godot.c, "GDExtensionClassCreationInfo2"))
    ClassUserdata2
else if (@hasDecl(godot.c, "GDExtensionClassCreationInfo"))
    ClassUserdata1
else
    @compileError("Godot version 4.1 or higher is required.");

pub fn registerClass(
    class_name: *StringName,
    base_name: *StringName,
    info: ClassCreationInfo,
) void {
    switch (ClassCreationInfo) {
        ClassCreationInfo4 => godot.interface.classdbRegisterExtensionClass4(godot.interface.library, class_name, base_name, &.{
            .is_virtual = @intFromBool(info.is_virtual),
            .is_abstract = @intFromBool(info.is_abstract),
            .is_exposed = @intFromBool(info.is_exposed),
            .is_runtime = @intFromBool(info.is_runtime),
            .icon_path = @ptrCast(if (info.icon_path) |icon| &icon else null),
            .set_func = &set,
            .get_func = &get,
            .get_property_list_func = &getPropertyList,
            .free_property_list_func = &freePropertyList2,
            .property_can_revert_func = &propertyCanRevert,
            .property_get_revert_func = &propertyGetRevert,
            .validate_property_func = &validateProperty,
            .notification_func = &notification2,
            .to_string_func = &toString,
            .reference_func = &reference,
            .unreference_func = &unreference,
            .create_instance_func = &createInstance2,
            .free_instance_func = &freeInstance,
            .recreate_instance_func = &recreateInstance,
            .get_virtual_func = &getVirtual2,
            .get_virtual_call_data_func = &getVirtualCallData2,
            .call_virtual_with_data_func = &callVirtualWithData,
            .class_userdata = @ptrCast(@constCast(&ClassUserdata4{
                .vtable = info.vtable,
                .userdata = info.userdata,
            })),
        }),
        ClassCreationInfo3 => godot.interface.classdbRegisterExtensionClass3(godot.interface.library, class_name, base_name, &.{
            .is_virtual = @intFromBool(info.is_virtual),
            .is_abstract = @intFromBool(info.is_abstract),
            .is_exposed = @intFromBool(info.is_exposed),
            .is_runtime = @intFromBool(info.is_runtime), // added in v3
            .set_func = &set,
            .get_func = &get,
            .get_property_list_func = &getPropertyList,
            .free_property_list_func = &freePropertyList2,
            .property_can_revert_func = &propertyCanRevert,
            .property_get_revert_func = &propertyGetRevert,
            .validate_property_func = &validateProperty,
            .notification_func = &notification2,
            .to_string_func = &toString,
            .reference_func = &reference,
            .unreference_func = &unreference,
            .create_instance_func = &createInstance,
            .free_instance_func = &freeInstance,
            .recreate_instance_func = &recreateInstance,
            .get_virtual_func = &getVirtual,
            .get_virtual_call_data_func = &getVirtualCallData,
            .call_virtual_with_data_func = &callVirtualWithData,
            .get_rid_func = &getRid,
            .class_userdata = @ptrCast(@constCast(&ClassUserdata4{
                .vtable = info.vtable,
                .userdata = info.userdata,
            })),
        }),
        ClassCreationInfo2 => godot.interface.classdbRegisterExtensionClass2(godot.interface.library, class_name, base_name, &.{
            .is_virtual = @intFromBool(info.is_virtual),
            .is_abstract = @intFromBool(info.is_abstract),
            .is_exposed = @intFromBool(info.is_exposed), // added in v2
            .set_func = &set,
            .get_func = &get,
            .get_property_list_func = &getPropertyList,
            .free_property_list_func = &freePropertyList,
            .property_can_revert_func = &propertyCanRevert,
            .property_get_revert_func = &propertyGetRevert,
            .validate_property_func = &validateProperty,
            .notification_func = &notification2,
            .to_string_func = &toString,
            .reference_func = &reference,
            .unreference_func = &unreference,
            .create_instance_func = &createInstance,
            .free_instance_func = &freeInstance,
            .recreate_instance_func = &recreateInstance,
            .get_virtual_func = &getVirtual,
            .get_virtual_call_data_func = &getVirtualCallData,
            .call_virtual_with_data_func = &callVirtualWithData,
            .get_rid_func = &getRid,
            .class_userdata = @ptrCast(@constCast(&ClassUserdata4{
                .vtable = info.vtable,
                .userdata = info.userdata,
            })),
        }),
        ClassCreationInfo1 => godot.interface.classdbRegisterExtensionClass(godot.interface.library, class_name, base_name, &.{
            .is_virtual = @intFromBool(info.is_virtual),
            .is_abstract = @intFromBool(info.is_abstract),
            .set_func = &set,
            .get_func = &get,
            .get_property_list_func = &getPropertyList,
            .free_property_list_func = &freePropertyList,
            .property_can_revert_func = &propertyCanRevert,
            .property_get_revert_func = &propertyGetRevert,
            .notification_func = &notification,
            .to_string_func = &toString,
            .reference_func = &reference,
            .unreference_func = &unreference,
            .create_instance_func = &createInstance,
            .free_instance_func = &freeInstance,
            .get_virtual_func = &getVirtual,
            .get_rid_func = &getRid,
            .class_userdata = @ptrCast(@constCast(&ClassUserdata4{
                .vtable = info.vtable,
                .userdata = info.userdata,
            })),
        }),
        else => unreachable,
    }
}

/// Godot v4.4
const ClassCreationInfo4 = struct {
    is_virtual: bool = false,
    is_abstract: bool = false,
    is_exposed: bool = false,
    is_runtime: bool = false,
    icon_path: ?String = null, // added in v4
    vtable: *const ClassUserdata4.VTable = &.{},
    userdata: ?*anyopaque = null,
};

/// Godot v4.3
const ClassCreationInfo3 = struct {
    is_virtual: bool = false,
    is_abstract: bool = false,
    is_exposed: bool = false,
    is_runtime: bool = false, // added in v3
    vtable: *const ClassUserdata3.VTable = &.{},
    userdata: ?*anyopaque = null,
};

/// Godot v4.2
const ClassCreationInfo2 = struct {
    is_virtual: bool = false,
    is_abstract: bool = false,
    is_exposed: bool = false, // added in v2
    vtable: *const ClassUserdata2.VTable = &.{},
    userdata: ?*anyopaque = null,
};

/// Godot v4.1
const ClassCreationInfo1 = struct {
    is_virtual: bool = false,
    is_abstract: bool = false,
    vtable: *const ClassUserdata1.VTable = &.{},
    userdata: ?*anyopaque = null,
};

/// Godot v4.4
const ClassUserdata4 = struct {
    vtable: *const VTable,
    userdata: ?*anyopaque,

    pub const Binding = struct {
        vtable: *const VTable,
        ptr: *Object,
    };

    pub const VTable = struct {
        // Static
        createInstance: ?*const CreateInstance2 = null,
        freeInstance: ?*const FreeInstance = null,
        recreateInstance: ?*const RecreateInstance = null,
        getVirtual: ?*const GetVirtual2 = null,
        getVirtualCallData: ?*const GetVirtualCallData2 = null,

        // Instance
        set: ?*const Set = null,
        get: ?*const Get = null,
        getPropertyList: ?*const GetPropertyList = null,
        freePropertyList: ?*const FreePropertyList2 = null,
        propertyCanRevert: ?*const PropertyCanRevert = null,
        propertyGetRevert: ?*const PropertyGetRevert = null,
        validateProperty: ?*const ValidateProperty = null,
        notification: ?*const Notification2 = null,
        toString: ?*const ToString = null,
        reference: ?*const Reference = null,
        unreference: ?*const Unreference = null,
    };
};

/// Godot v4.3
const ClassUserdata3 = struct {
    vtable: *const VTable,
    userdata: ?*anyopaque,

    pub const Binding = struct {
        vtable: *const VTable,
        ptr: *Object,
    };

    pub const VTable = struct {
        // Static
        createInstance: ?*const CreateInstance = null,
        freeInstance: ?*const FreeInstance = null,
        recreateInstance: ?*const RecreateInstance = null,
        getVirtual: ?*const GetVirtual = null,
        getVirtualCallData: ?*const GetVirtualCallData = null,

        // Instance
        set: ?*const Set = null,
        get: ?*const Get = null,
        getPropertyList: ?*const GetPropertyList = null,
        freePropertyList: ?*const FreePropertyList2 = null,
        propertyCanRevert: ?*const PropertyCanRevert = null,
        propertyGetRevert: ?*const PropertyGetRevert = null,
        validateProperty: ?*const ValidateProperty = null,
        notification: ?*const Notification2 = null,
        toString: ?*const ToString = null,
        reference: ?*const Reference = null,
        unreference: ?*const Unreference = null,
        getRid: ?*const GetRID = null,
    };
};

/// Godot v4.2
const ClassUserdata2 = struct {
    vtable: *const VTable,
    userdata: ?*anyopaque,

    pub const Binding = struct {
        vtable: *const VTable,
        ptr: *Object,
    };

    pub const VTable = struct {
        // Static
        createInstance: ?*const CreateInstance = null,
        freeInstance: ?*const FreeInstance = null,
        recreateInstance: ?*const RecreateInstance = null,
        getVirtual: ?*const GetVirtual = null,
        getVirtualCallData: ?*const GetVirtualCallData = null,

        // Instance
        set: ?*const Set = null,
        get: ?*const Get = null,
        getPropertyList: ?*const GetPropertyList = null,
        freePropertyList: ?*const FreePropertyList = null,
        propertyCanRevert: ?*const PropertyCanRevert = null,
        propertyGetRevert: ?*const PropertyGetRevert = null,
        validateProperty: ?*const ValidateProperty = null,
        notification: ?*const Notification2 = null,
        toString: ?*const ToString = null,
        reference: ?*const Reference = null,
        unreference: ?*const Unreference = null,
        getRid: ?*const GetRID = null,
    };
};

/// Godot v4.1
const ClassUserdata1 = struct {
    vtable: *const VTable,
    userdata: ?*anyopaque,

    pub const Binding = struct {
        vtable: *const VTable,
        ptr: *Object,
    };

    pub const VTable = struct {
        // Static
        createInstance: ?*const CreateInstance = null,
        freeInstance: ?*const FreeInstance = null,
        getVirtual: ?*const GetVirtual = null,

        // Instance
        set: ?*const Set = null,
        get: ?*const Get = null,
        getPropertyList: ?*const GetPropertyList = null,
        freePropertyList: ?*const FreePropertyList = null,
        propertyCanRevert: ?*const PropertyCanRevert = null,
        propertyGetRevert: ?*const PropertyGetRevert = null,
        notification: ?*const Notification = null,
        toString: ?*const ToString = null,
        reference: ?*const Reference = null,
        unreference: ?*const Unreference = null,
        getRid: ?*const GetRID = null,
    };
};

pub const Set = fn (instance: *anyopaque, StringName, *const Variant) bool;
pub const Get = fn (instance: *anyopaque, name: StringName) ?Variant;
pub const GetPropertyList = fn (instance: *anyopaque) []PropertyInfo;
pub const FreePropertyList = fn (instance: *anyopaque, [*]PropertyInfo) void;
pub const FreePropertyList2 = fn (instance: *anyopaque, []PropertyInfo) void;
pub const PropertyCanRevert = fn (instance: *anyopaque, name: StringName) bool;
pub const PropertyGetRevert = fn (instance: *anyopaque, name: StringName) ?Variant;
pub const ValidateProperty = fn (instance: *anyopaque, info: *PropertyInfo) bool;
pub const Notification = fn (instance: *anyopaque, what: i32) void;
pub const Notification2 = fn (instance: *anyopaque, what: i32, reversed: bool) void;
pub const ToString = fn (instance: *anyopaque) ?String;
pub const Reference = fn (instance: *anyopaque) void;
pub const Unreference = fn (instance: *anyopaque) void;
pub const CreateInstance = fn (class_userdata: ?*anyopaque) *Object;
pub const CreateInstance2 = fn (class_userdata: ?*anyopaque, notify_postinitialize: bool) *Object;
pub const FreeInstance = fn (class_userdata: ?*anyopaque, instance: *anyopaque) void;
pub const RecreateInstance = fn (class_userdata: ?*anyopaque, object: *Object) *anyopaque;
pub const GetVirtual = fn (class_userdata: ?*anyopaque, name: StringName) ?*const CallVirtual;
pub const GetVirtual2 = fn (class_userdata: ?*anyopaque, name: StringName, hash: u32) ?*const CallVirtual;
pub const GetVirtualCallData = fn (class_userdata: ?*anyopaque, name: StringName) ?*anyopaque;
pub const GetVirtualCallData2 = fn (class_userdata: ?*anyopaque, name: StringName, hash: u32) ?*anyopaque;
pub const CallVirtual = fn (instance: *anyopaque, args: []const *anyopaque) *anyopaque;
pub const CallVirtualWithData = fn (instance: *anyopaque, name: StringName, virtual_call_userdata: ?*anyopaque, args: []const *anyopaque) ?*anyopaque;
pub const GetRID = fn (instance: *anyopaque) u64;

fn getMethod(instance: ?*anyopaque, comptime method_name: []const u8) @FieldType(ClassUserdata.VTable, method_name) {
    const ptr = godot.interface.objectGetInstanceBinding(instance.?, godot.interface.library, null).?;
    const binding: *ClassUserdata.Binding = @ptrCast(@alignCast(ptr));
    return @field(binding.vtable, method_name);
}

fn set(
    instance: c.GDExtensionClassInstancePtr,
    name: c.GDExtensionConstStringNamePtr,
    variant: c.GDExtensionConstVariantPtr,
) callconv(.c) c.GDExtensionBool {
    const set_fn = getMethod(instance, "set") orelse return 0;

    const p_instance: *anyopaque = instance.?;
    const p_name: StringName = @as(*const StringName, @ptrCast(name.?)).*;
    const p_variant: *const Variant = @ptrCast(@alignCast(variant.?));

    const ret = set_fn(p_instance, p_name, p_variant);

    return @intFromBool(ret);
}

fn get(
    instance: c.GDExtensionClassInstancePtr,
    name: c.GDExtensionConstStringNamePtr,
    variant: c.GDExtensionVariantPtr,
) callconv(.c) c.GDExtensionBool {
    const get_fn = getMethod(instance, "get") orelse return 0;

    const p_instance: *anyopaque = instance.?;
    const p_name: StringName = @as(*const StringName, @ptrCast(name.?)).*;
    const r_variant: *Variant = @ptrCast(@alignCast(variant.?));

    const ret = get_fn(p_instance, p_name);

    if (ret) |result| {
        r_variant.* = result;
        return 1;
    } else {
        return 0;
    }
}

fn getPropertyList(
    instance: c.GDExtensionClassInstancePtr,
    count: [*c]u32,
) callconv(.c) [*c]const c.GDExtensionPropertyInfo {
    const getPropertyList_fn = getMethod(instance, "getPropertyList") orelse {
        count.* = 0;
        return null;
    };

    const p_instance: *anyopaque = instance.?;

    const ret = getPropertyList_fn(p_instance);

    count.* = @intCast(ret.len);
    return @ptrCast(ret.ptr);
}

fn freePropertyList(
    instance: c.GDExtensionClassInstancePtr,
    list: [*c]const c.GDExtensionPropertyInfo,
) callconv(.c) void {
    const freePropertyList_fn = getMethod(instance, "freePropertyList") orelse return;

    const p_instance: *anyopaque = instance.?;

    freePropertyList_fn(p_instance, list);
}

fn freePropertyList2(
    instance: c.GDExtensionClassInstancePtr,
    list: [*c]const c.GDExtensionPropertyInfo,
    count: u32,
) callconv(.c) void {
    const freePropertyList_fn = getMethod(instance, "freePropertyList") orelse return;

    const p_instance: *anyopaque = instance.?;

    freePropertyList_fn(p_instance, @ptrCast(@constCast(list[0..count])));
}

fn propertyCanRevert(
    instance: c.GDExtensionClassInstancePtr,
    name: c.GDExtensionConstStringNamePtr,
) callconv(.c) c.GDExtensionBool {
    const propertyCanRevert_fn = getMethod(instance, "propertyCanRevert") orelse return 0;

    const p_instance: *anyopaque = instance.?;
    const p_name: StringName = @as(*const StringName, @ptrCast(name.?)).*;

    const ret = propertyCanRevert_fn(p_instance, p_name);

    return @intFromBool(ret);
}

fn propertyGetRevert(
    instance: c.GDExtensionClassInstancePtr,
    name: c.GDExtensionConstStringNamePtr,
    variant: c.GDExtensionVariantPtr,
) callconv(.c) c.GDExtensionBool {
    const propertyGetRevert_fn = getMethod(instance, "propertyGetRevert") orelse return 0;

    const p_instance: *anyopaque = instance.?;
    const p_name: StringName = @as(*const StringName, @ptrCast(name.?)).*;
    const r_variant: *Variant = @ptrCast(@alignCast(variant.?));

    const ret = propertyGetRevert_fn(p_instance, p_name);

    if (ret) |result| {
        r_variant.* = result;
        return 1;
    }
    return 0;
}

fn validateProperty(
    instance: c.GDExtensionClassInstancePtr,
    property: [*c]c.GDExtensionPropertyInfo,
) callconv(.c) c.GDExtensionBool {
    const validateProperty_fn = getMethod(instance, "validateProperty") orelse return 0;

    const p_instance: *anyopaque = instance.?;
    const p_property: *PropertyInfo = @ptrCast(property);

    const ret = validateProperty_fn(p_instance, p_property);

    return @intFromBool(ret);
}

fn notification(
    instance: c.GDExtensionClassInstancePtr,
    what: i32,
) callconv(.c) void {
    const notification_fn = getMethod(instance, "notification") orelse return;

    const p_instance: *anyopaque = instance.?;

    notification_fn(p_instance, what);
}

fn notification2(
    instance: c.GDExtensionClassInstancePtr,
    what: i32,
    reversed: c.GDExtensionBool,
) callconv(.c) void {
    const notification_fn = getMethod(instance, "notification") orelse return;

    const p_instance: *anyopaque = instance.?;

    notification_fn(p_instance, what, reversed != 0);
}

fn toString(
    instance: c.GDExtensionClassInstancePtr,
    is_valid: [*c]c.GDExtensionBool,
    string: c.GDExtensionStringPtr,
) callconv(.c) void {
    const toString_fn = getMethod(instance, "toString") orelse {
        const r_is_valid: *u8 = @ptrCast(is_valid.?);
        r_is_valid.* = 0;
        return;
    };

    const p_instance: *anyopaque = instance.?;
    const r_string: *String = @ptrCast(@alignCast(string.?));
    const r_is_valid: *u8 = @ptrCast(is_valid.?);

    const ret = toString_fn(p_instance);

    if (ret) |result| {
        r_string.* = result;
        r_is_valid.* = 1;
    } else {
        r_is_valid.* = 0;
    }
}

fn reference(
    instance: c.GDExtensionClassInstancePtr,
) callconv(.c) void {
    const reference_fn = getMethod(instance, "reference") orelse return;

    const p_instance: *anyopaque = instance.?;

    reference_fn(p_instance);
}

fn unreference(
    instance: c.GDExtensionClassInstancePtr,
) callconv(.c) void {
    const unreference_fn = getMethod(instance, "unreference") orelse return;

    const p_instance: *anyopaque = instance.?;

    unreference_fn(p_instance);
}

fn createInstance(
    userdata: ?*anyopaque,
) callconv(.c) c.GDExtensionObjectPtr {
    const class_userdata: *ClassUserdata = @ptrCast(@alignCast(userdata.?));
    const ret = class_userdata.vtable.createInstance.?(class_userdata.userdata);

    return @ptrCast(ret);
}

fn createInstance2(
    userdata: ?*anyopaque,
    notify_postinitialize: c.GDExtensionBool,
) callconv(.c) c.GDExtensionObjectPtr {
    const class_userdata: *ClassUserdata = @ptrCast(@alignCast(userdata.?));
    const ret = class_userdata.vtable.createInstance.?(class_userdata.userdata, notify_postinitialize != 0);

    return @ptrCast(ret);
}

fn freeInstance(
    userdata: ?*anyopaque,
    instance: c.GDExtensionClassInstancePtr,
) callconv(.c) void {
    const class_userdata: *ClassUserdata = @ptrCast(@alignCast(userdata.?));
    const p_instance: *anyopaque = instance.?;

    class_userdata.vtable.freeInstance.?(class_userdata.userdata, p_instance);
}

fn recreateInstance(
    userdata: ?*anyopaque,
    object: c.GDExtensionObjectPtr,
) callconv(.c) c.GDExtensionClassInstancePtr {
    const class_userdata: *ClassUserdata = @ptrCast(@alignCast(userdata.?));
    const p_object: *Object = @ptrCast(object.?);

    const ret = class_userdata.vtable.recreateInstance.?(class_userdata.userdata, p_object);

    return @ptrCast(ret);
}

fn callVirtual(
    instance: c.GDExtensionClassInstancePtr,
    args: [*c]const c.GDExtensionConstTypePtr,
    ret: c.GDExtensionTypePtr,
) callconv(.c) void {
    const callVirtual_fn = getMethod(instance, "callVirtual") orelse return;

    const p_instance: *anyopaque = instance.?;
    const p_args: []const *anyopaque = @ptrCast(args);
    const r_ret: *anyopaque = @ptrCast(ret);

    const result = callVirtual_fn(p_instance, p_args);
    r_ret.* = result.*;
}

fn getVirtual(
    userdata: ?*anyopaque,
    name: c.GDExtensionConstStringNamePtr,
) callconv(.c) c.GDExtensionClassCallVirtual {
    const class_userdata: *ClassUserdata = @ptrCast(@alignCast(userdata.?));
    const p_name: StringName = @as(*const StringName, @ptrCast(name.?)).*;

    const ret = class_userdata.vtable.getVirtual.?(class_userdata.userdata, p_name);
    _ = ret; // autofix

    @panic("TODO");
}

fn getVirtual2(
    userdata: ?*anyopaque,
    name: c.GDExtensionConstStringNamePtr,
    hash: u32,
) callconv(.c) c.GDExtensionClassCallVirtual {
    const class_userdata: *ClassUserdata = @ptrCast(@alignCast(userdata.?));
    const p_name: StringName = @as(*const StringName, @ptrCast(name.?)).*;

    const ret = class_userdata.vtable.getVirtual.?(class_userdata.userdata, p_name, hash);
    _ = ret; // autofix

    @panic("TODO");
}

fn getVirtualCallData(
    userdata: ?*anyopaque,
    name: c.GDExtensionConstStringNamePtr,
) callconv(.c) ?*anyopaque {
    const class_userdata: *ClassUserdata = @ptrCast(@alignCast(userdata.?));
    const p_name: StringName = @as(*const StringName, @ptrCast(name.?)).*;

    const ret = class_userdata.vtable.getVirtualCallData.?(class_userdata.userdata, p_name);

    return ret;
}

fn getVirtualCallData2(
    userdata: ?*anyopaque,
    name: c.GDExtensionConstStringNamePtr,
    hash: u32,
) callconv(.c) ?*anyopaque {
    const class_userdata: *ClassUserdata = @ptrCast(@alignCast(userdata.?));
    const p_name: StringName = @as(*const StringName, @ptrCast(name.?)).*;

    const ret = class_userdata.vtable.getVirtualCallData.?(class_userdata.userdata, p_name, hash);

    return ret;
}

fn callVirtualWithData(
    instance: c.GDExtensionClassInstancePtr,
    name: c.GDExtensionConstStringNamePtr,
    virtual_call_userdata: ?*anyopaque,
    args: [*c]const c.GDExtensionConstTypePtr,
    ret: c.GDExtensionTypePtr,
) callconv(.c) void {
    const p_instance: *anyopaque = instance.?;
    const p_name: StringName = @as(*const StringName, @ptrCast(name.?)).*;

    // ret.* = callback(p_instance, p_name, virtual_call_userdata, args, ret);
    _ = p_instance;
    _ = p_name;
    _ = virtual_call_userdata;
    _ = args;
    _ = ret;

    @panic("TODO: implement");
}

fn getRid(
    instance: c.GDExtensionClassInstancePtr,
) callconv(.c) u64 {
    const getRid_fn = getMethod(instance, "getRid") orelse return 0;

    const p_instance: *anyopaque = instance.?;

    const ret = getRid_fn(p_instance);

    return ret;
}

pub const PropertyInfo = extern struct {
    type: Variant.Tag = .nil,
    name: ?*StringName = null,
    class_name: ?*StringName = null,
    hint: PropertyHint = .property_hint_none,
    hint_string: ?*String = null,
    usage: PropertyUsageFlags = .property_usage_default,
};

const std = @import("std");

const godot = @import("../gdzig.zig");
const c = godot.c;
const PropertyHint = godot.global.PropertyHint;
const PropertyUsageFlags = godot.global.PropertyUsageFlags;
const Object = godot.class.Object;
const String = godot.builtin.String;
const StringName = godot.builtin.StringName;
const Variant = godot.builtin.Variant;
const fn_binding = @import("../util/fn_binding.zig");
