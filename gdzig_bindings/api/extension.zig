const raw: *Interface = &@import("../../gdzig_bindings.zig").raw;

/// **Deprecated** in Godot 4.2. Use `classdbRegisterExtensionClass2` instead.
///
/// Registers an extension class in the ClassDB.
///
/// Provided struct can be safely freed once the function returns.
///
/// @param class_name A pointer to a StringName with the class name.
/// @param parent_class_name A pointer to a StringName with the parent class name.
/// @param class_info A pointer to a GDExtensionClassCreationInfo struct.
/// @param callbacks A pointer to a GDExtensionClassCallbacks struct.
///
/// @since 4.1
pub inline fn classdbRegisterExtensionClass(
    comptime T: type,
    comptime Userdata: type,
    class_name: *const StringName,
    base_class_name: *const StringName,
    info: *const class.ClassInfo1(Userdata),
    comptime callbacks: *const class.ClassCallbacks1(T, Userdata),
) void {
    raw.classdbRegisterExtensionClass(raw.library.ptr(), class_name.constPtr(), base_class_name.constPtr(), &c.GDExtensionClassCreationInfo{
        .is_virtual = @intFromBool(info.is_virtual),
        .is_abstract = @intFromBool(info.is_abstract),

        .create_instance_func = class.wrapCreateInstance(T, Userdata, callbacks.init),
        .free_instance_func = class.wrapFreeInstance(T, Userdata, callbacks.deinit),
        .get_virtual_func = if (callbacks.get_virtual) |f| class.wrapGetVirtual(T, Userdata, f) else null,

        .set_func = if (callbacks.set) |f| class.wrapSet(T, f) else null,
        .get_func = if (callbacks.get) |f| class.wrapGet(T, f) else null,
        .get_property_list_func = if (callbacks.get_property_list) |f| class.wrapGetPropertyList(T, f) else null,
        .free_property_list_func = if (callbacks.free_property_list) |f| class.wrapFreePropertyList(T, f) else null,
        .property_can_revert_func = if (callbacks.property_can_revert) |f| class.wrapPropertyCanRevert(T, f) else null,
        .property_get_revert_func = if (callbacks.property_get_revert) |f| class.wrapPropertyGetRevert(T, f) else null,
        .notification_func = if (callbacks.notification) |f| class.wrapNotification(T, f) else null,
        .to_string_func = if (callbacks.to_string) |f| class.wrapToString(T, f) else null,
        .reference_func = if (callbacks.reference) |f| class.wrapReference(T, f) else null,
        .unreference_func = if (callbacks.unreference) |f| class.wrapUnreference(T, f) else null,
        .get_rid_func = if (callbacks.get_rid) |f| class.wrapGetRID(T, f) else null,

        .class_userdata = @ptrCast(info.userdata),
    });
}

/// **Deprecated** in Godot 4.3. Use `classdbRegisterExtensionClass3` instead.
///
/// Registers an extension class in the ClassDB.
///
/// Provided struct can be safely freed once the function returns.
///
/// @param class_name A pointer to a StringName with the class name.
/// @param parent_class_name A pointer to a StringName with the parent class name.
/// @param class_info A pointer to a GDExtensionClassCreationInfo2 struct.
///
/// @since 4.2
pub inline fn classdbRegisterExtensionClass2(
    comptime T: type,
    comptime Userdata: type,
    comptime VirtualCallData: type,
    class_name: *const StringName,
    base_class_name: *const StringName,
    info: *const class.ClassInfo2(Userdata),
    comptime callbacks: *const class.ClassCallbacks2(T, Userdata, VirtualCallData),
) void {
    raw.classdbRegisterExtensionClass2(raw.library.ptr(), class_name.constPtr(), base_class_name.constPtr(), &c.GDExtensionClassCreationInfo2{
        .is_virtual = @intFromBool(info.is_virtual),
        .is_abstract = @intFromBool(info.is_abstract),
        .is_exposed = @intFromBool(info.is_exposed),

        .create_instance_func = class.wrapCreateInstance(T, Userdata, callbacks.create),
        .free_instance_func = class.wrapFreeInstance(T, Userdata, callbacks.free),
        .recreate_instance_func = if (callbacks.recreate) |f| class.wrapRecreateInstance(T, Userdata, f) else null,
        .get_virtual_func = if (callbacks.get_virtual) |f| class.wrapGetVirtual(T, Userdata, f) else null,
        .get_virtual_call_data_func = if (callbacks.get_virtual_call_data) |f| class.wrapGetVirtualCallData(Userdata, VirtualCallData, f) else null,
        .call_virtual_with_data_func = if (callbacks.call_virtual_with_data) |f| class.wrapCallVirtualWithData(T, VirtualCallData, f) else null,

        .set_func = if (callbacks.set) |f| class.wrapSet(T, f) else null,
        .get_func = if (callbacks.get) |f| class.wrapGet(T, f) else null,
        .get_property_list_func = if (callbacks.get_property_list) |f| class.wrapGetPropertyList(T, f) else null,
        .free_property_list_func = if (callbacks.free_property_list) |f| class.wrapFreePropertyList(T, f) else null,
        .property_can_revert_func = if (callbacks.property_can_revert) |f| class.wrapPropertyCanRevert(T, f) else null,
        .property_get_revert_func = if (callbacks.property_get_revert) |f| class.wrapPropertyGetRevert(T, f) else null,
        .validate_property_func = if (callbacks.validate_property) |f| class.wrapValidateProperty(T, f) else null,
        .notification_func = if (callbacks.notification) |f| class.wrapNotification(T, f) else null,
        .to_string_func = if (callbacks.to_string) |f| class.wrapToString(T, f) else null,
        .reference_func = if (callbacks.reference) |f| class.wrapReference(T, f) else null,
        .unreference_func = if (callbacks.unreference) |f| class.wrapUnreference(T, f) else null,
        .get_rid_func = if (callbacks.get_rid) |f| class.wrapGetRID(T, f) else null,

        .class_userdata = @ptrCast(info.userdata),
    });
}

/// **Deprecated** in Godot 4.4. Use `classdbRegisterExtensionClass4` instead.
///
/// Registers an extension class in the ClassDB.
///
/// Provided struct can be safely freed once the function returns.
///
/// @param class_name A pointer to a StringName with the class name.
/// @param parent_class_name A pointer to a StringName with the parent class name.
/// @param class_info A pointer to a GDExtensionClassCreationInfo3 struct.
///
/// @since 4.3
pub inline fn classdbRegisterExtensionClass3(
    comptime T: type,
    comptime Userdata: type,
    comptime VirtualCallData: type,
    class_name: *const StringName,
    base_class_name: *const StringName,
    info: *const class.ClassInfo3(Userdata),
    comptime callbacks: *const class.ClassCallbacks3(T, Userdata, VirtualCallData),
) void {
    raw.classdbRegisterExtensionClass3(raw.library.ptr(), class_name.constPtr(), base_class_name.constPtr(), &c.GDExtensionClassCreationInfo3{
        .is_virtual = @intFromBool(info.is_virtual),
        .is_abstract = @intFromBool(info.is_abstract),
        .is_exposed = @intFromBool(info.is_exposed),
        .is_runtime = @intFromBool(info.is_runtime),

        .create_instance_func = class.wrapCreateInstance(T, Userdata, callbacks.create),
        .free_instance_func = class.wrapFreeInstance(T, Userdata, callbacks.free),
        .recreate_instance_func = if (callbacks.recreate) |f| class.wrapRecreateInstance(T, Userdata, f) else null,
        .get_virtual_func = if (callbacks.get_virtual) |f| class.wrapGetVirtual(T, Userdata, f) else null,
        .get_virtual_call_data_func = if (callbacks.get_virtual_call_data) |f| class.wrapGetVirtualCallData(Userdata, VirtualCallData, f) else null,
        .call_virtual_with_data_func = if (callbacks.call_virtual_with_data) |f| class.wrapCallVirtualWithData(T, VirtualCallData, f) else null,

        .set_func = if (callbacks.set) |f| class.wrapSet(T, f) else null,
        .get_func = if (callbacks.get) |f| class.wrapGet(T, f) else null,
        .get_property_list_func = if (callbacks.get_property_list) |f| class.wrapGetPropertyList(T, f) else null,
        .free_property_list_func = if (callbacks.free_property_list) |f| class.wrapFreePropertyList(T, f) else null,
        .property_can_revert_func = if (callbacks.property_can_revert) |f| class.wrapPropertyCanRevert(T, f) else null,
        .property_get_revert_func = if (callbacks.property_get_revert) |f| class.wrapPropertyGetRevert(T, f) else null,
        .notification_func = if (callbacks.notification) |f| class.wrapNotification(T, f) else null,
        .to_string_func = if (callbacks.to_string) |f| class.wrapToString(T, f) else null,
        .reference_func = if (callbacks.reference) |f| class.wrapReference(T, f) else null,
        .unreference_func = if (callbacks.unreference) |f| class.wrapUnreference(T, f) else null,
        .get_rid_func = if (callbacks.get_rid) |f| class.wrapGetRID(T, f) else null,

        .class_userdata = @ptrCast(info.userdata),
    });
}

/// Registers an extension class in the ClassDB.
///
/// Provided struct can be safely freed once the function returns.
///
/// @param class_name A pointer to a StringName with the class name.
/// @param parent_class_name A pointer to a StringName with the parent class name.
/// @param class_info A pointer to a GDExtensionClassCreationInfo4 struct.
///
/// @since 4.4
pub inline fn classdbRegisterExtensionClass4(
    comptime T: type,
    comptime Userdata: type,
    comptime VirtualCallData: type,
    class_name: *const StringName,
    base_class_name: *const StringName,
    info: *const class.ClassInfo4(Userdata),
    comptime callbacks: *const class.ClassCallbacks4(T, Userdata, VirtualCallData),
) void {
    raw.classdbRegisterExtensionClass4(raw.library.ptr(), class_name.constPtr(), base_class_name.constPtr(), &c.GDExtensionClassCreationInfo4{
        .is_virtual = @intFromBool(info.is_virtual),
        .is_abstract = @intFromBool(info.is_abstract),
        .is_exposed = @intFromBool(info.is_exposed),
        .is_runtime = @intFromBool(info.is_runtime),

        .create_instance_func = class.wrapCreateInstance(T, Userdata, callbacks.create),
        .free_instance_func = class.wrapFreeInstance(T, Userdata, callbacks.free),
        .recreate_instance_func = if (callbacks.recreate) |f| class.wrapRecreateInstance(T, Userdata, f) else null,
        .get_virtual_func = if (callbacks.get_virtual) |f| class.wrapGetVirtual(T, Userdata, f) else null,
        .get_virtual_call_data_func = if (callbacks.get_virtual_call_data) |f| class.wrapGetVirtualCallData(Userdata, VirtualCallData, f) else null,
        .call_virtual_with_data_func = if (callbacks.call_virtual_with_data) |f| class.wrapCallVirtualWithData(T, VirtualCallData, f) else null,

        .set_func = if (callbacks.set) |f| class.wrapSet(T, f) else null,
        .get_func = if (callbacks.get) |f| class.wrapGet(T, f) else null,
        .get_property_list_func = if (callbacks.get_property_list) |f| class.wrapGetPropertyList(T, f) else null,
        .free_property_list_func = if (callbacks.free_property_list) |f| class.wrapFreePropertyList(T, f) else null,
        .property_can_revert_func = if (callbacks.property_can_revert) |f| class.wrapPropertyCanRevert(T, f) else null,
        .property_get_revert_func = if (callbacks.property_get_revert) |f| class.wrapPropertyGetRevert(T, f) else null,
        .validate_property_func = if (callbacks.validate_property) |f| class.wrapValidateProperty(T, f) else null,
        .notification_func = if (callbacks.notification) |f| class.wrapNotification(T, f) else null,
        .to_string_func = if (callbacks.to_string) |f| class.wrapToString(T, f) else null,
        .reference_func = if (callbacks.reference) |f| class.wrapReference(T, f) else null,
        .unreference_func = if (callbacks.unreference) |f| class.wrapUnreference(T, f) else null,

        .class_userdata = @ptrCast(info.userdata),
    });
}

/// Registers a method on an extension class in the ClassDB.
///
/// Provided struct can be safely freed once the function returns.
///
/// @param class_name A pointer to a StringName with the class name.
/// @param method_info A pointer to a GDExtensionClassMethodInfo struct.
///
/// @since 4.1
pub inline fn classdbRegisterExtensionClassMethod(
    comptime T: type,
    comptime Userdata: type,
    class_name: *const StringName,
    info: method.MethodInfo(Userdata),
    comptime callbacks: method.MethodCallbacks(Userdata),
) void {
    assert(info.argument_info.len == info.argument_metadata.len);

    raw.classdbRegisterExtensionClassMethod(raw.ptr(), class_name.constPtr(), &c.GDExtensionClassMethodInfo{
        .name = info.name.ptr(),
        .method_userdata = @ptrCast(info.userdata),
        .call_func = if (callbacks.call) |f| &method.wrapCall(T, Userdata, f) else null,
        .ptrcall_func = if (callbacks.ptr_call) |f| &method.wrapPtrCall(T, Userdata, f) else null,
        .method_flags = @bitCast(info.flags),
        .has_return_value = @intFromBool(info.has_return_value),
        .return_value_info = @ptrCast(info.return_value_info),
        .return_value_metadata = @intFromEnum(info.return_value_metadata),
        .argument_count = @intCast(info.argument_info.len),
        .arguments_info = @ptrCast(info.argument_info.ptr),
        .arguments_metadata = @ptrCast(info.argument_metadata.ptr),
        .default_argument_count = @intCast(info.default_arguments.len),
        .default_arguments = @ptrCast(info.default_arguments.ptr),
    });
}

/// Registers a property on an extension class in the ClassDB.
///
/// Provided struct can be safely freed once the function returns.
///
/// @param class_name A pointer to a StringName with the class name.
/// @param info A pointer to a GDExtensionPropertyInfo struct.
/// @param setter A pointer to a StringName with the name of the setter method.
/// @param getter A pointer to a StringName with the name of the getter method.
///
/// @since 4.1
pub inline fn classdbRegisterExtensionClassProperty(class_name: *const StringName, info: *const PropertyInfo, setter: *const StringName, getter: *const StringName) void {
    raw.classdbRegisterExtensionClassProperty(raw.library.ptr(), class_name.constPtr(), info, setter.constPtr(), getter.constPtr());
}

/// Registers a signal on an extension class in the ClassDB.
///
/// Provided structs can be safely freed once the function returns.
/// @param class_name A pointer to a StringName with the class name.
/// @param signal_name A pointer to a StringName with the signal name.
/// @param argument_info A slice of PropertyInfo structs describing the signal arguments.
///
/// @since 4.1
pub inline fn classdbRegisterExtensionClassSignal(class_name: *const StringName, signal_name: *const StringName, argument_info: []const PropertyInfo) void {
    raw.classdbRegisterExtensionClassSignal(raw.library.ptr(), class_name.constPtr(), signal_name.constPtr(), argument_info.ptr, @intCast(argument_info.len));
}

/// Unregisters an extension class in the ClassDB.
///
/// @param class_name A pointer to a StringName with the class name.
///
/// @since 4.1
pub inline fn classdbUnregisterExtensionClass(class_name: *const StringName) void {
    raw.classdbUnregisterExtensionClass(raw.library.ptr(), class_name.constPtr());
}

/// Registers a virtual method on an extension class in ClassDB, that can be implemented by scripts or other extensions.
///
/// Provided struct can be safely freed once the function returns.
///
/// @param p_library A pointer the library received by the GDExtension's entry point function.
/// @param p_class_name A pointer to a StringName with the class name.
/// @param p_method_info A pointer to a GDExtensionClassMethodInfo struct.
///
/// @since 4.3
pub inline fn classdbRegisterExtensionClassVirtualMethod(class_name: *const StringName, method_info: *const method.VirtualMethodInfo) void {
    raw.classdbRegisterExtensionClassVirtualMethod(raw.library.ptr(), class_name.constPtr(), method_info);
}

/// Registers an integer constant on an extension class in the ClassDB.
///
/// Note about registering bitfield values (if p_is_bitfield is true): even though p_constant_value is signed, language bindings are
/// advised to treat bitfields as uint64_t, since this is generally clearer and can prevent mistakes like using -1 for setting all bits.
/// Language APIs should thus provide an abstraction that registers bitfields (uint64_t) separately from regular constants (int64_t).
///
/// @param p_library A pointer the library received by the GDExtension's entry point function.
/// @param class_name A pointer to a StringName with the class name.
/// @param enum_name An optional pointer to a StringName with the enum name.
/// @param constant_name A pointer to a StringName with the constant name.
/// @param constant_value The constant value.
/// @param is_bitfield Whether or not this constant is part of a bitfield.
///
/// @since 4.1
pub inline fn classdbRegisterExtensionClassIntegerConstant(class_name: *const StringName, enum_name: ?*const StringName, constant_name: *const StringName, constant_value: i64, is_bitfield: bool) void {
    raw.classdbRegisterExtensionClassIntegerConstant(raw.library.ptr(), class_name.constPtr(), if (enum_name) |e| e.constPtr() else null, constant_name.constPtr(), constant_value, @intFromBool(is_bitfield));
}

/// Registers a property group on an extension class in the ClassDB.
///
/// @param class_name A pointer to a StringName with the class name.
/// @param group_name A pointer to a String with the group name.
/// @param prefix A pointer to a String with the prefix used by properties in this group.
///
/// @since 4.1
pub inline fn classdbRegisterExtensionClassPropertyGroup(class_name: *const StringName, group_name: *const String, prefix: *const String) void {
    raw.classdbRegisterExtensionClassPropertyGroup(raw.library.ptr(), class_name.constPtr(), group_name.constPtr(), prefix.constPtr());
}

/// Registers a property subgroup on an extension class in the ClassDB.
///
/// @param class_name A pointer to a StringName with the class name.
/// @param subgroup_name A pointer to a String with the subgroup name.
/// @param prefix A pointer to a String with the prefix used by properties in this subgroup.
///
/// @since 4.1
pub inline fn classdbRegisterExtensionClassPropertySubgroup(class_name: *const StringName, subgroup_name: *const String, prefix: *const String) void {
    raw.classdbRegisterExtensionClassPropertySubgroup(raw.library.ptr(), class_name.constPtr(), subgroup_name.constPtr(), prefix.constPtr());
}

/// Registers an indexed property on an extension class in the ClassDB.
///
/// Provided struct can be safely freed once the function returns.
///
/// @param class_name A pointer to a StringName with the class name.
/// @param info A pointer to a GDExtensionPropertyInfo struct.
/// @param setter A pointer to a StringName with the name of the setter method.
/// @param getter A pointer to a StringName with the name of the getter method.
/// @param index The index to pass as the first argument to the getter and setter methods.
///
/// @since 4.2
pub inline fn classdbRegisterExtensionClassPropertyIndexed(class_name: *const StringName, info: *const PropertyInfo, setter: *const StringName, getter: *const StringName, index: i64) void {
    raw.classdbRegisterExtensionClassPropertyIndexed(raw.library.ptr(), class_name.constPtr(), info, setter.constPtr(), getter.constPtr(), index);
}

/// Gets the path to the current GDExtension library.
///
/// @return The library path as a String.
///
/// @since 4.1
pub inline fn getLibraryPath() String {
    var path: String = undefined;
    raw.getLibraryPath(raw.library.ptr(), @ptrCast(&path));
    return path;
}

const std = @import("std");
const Child = std.meta.Child;
const assert = std.debug.assert;

const c = @import("gdextension");

const api = @import("../api.zig");
const PropertyInfo = api.PropertyInfo;
const CallError = api.CallError;
const Error = api.Error;
const builtin = @import("../builtin.zig");
const StringName = builtin.StringName;
const String = builtin.String;
const Variant = builtin.Variant;
const Object = @import("../class.zig").Object;
const Interface = @import("../Interface.zig");
const ClassLibrary = Interface.ClassLibrary;
const class = @import("./extension/class.zig");
const init = @import("./extension/init.zig");
const method = @import("./extension/method.zig");
