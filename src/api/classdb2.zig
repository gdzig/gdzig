//! These functions and types are very thin wrappers around the Godot C API to expose a Zig friendly
//! interface. They do not add any additional functionality, other than what is strictly necessary to
//! create an idiomatic interface.
//!
//! If you're looking for the raw C APIs without any wrappers, you can find them exposed in the
//! `godot.c` module.
//!

fn ClassApi(comptime T: type, comptime ClassUserdata: type, comptime VirtualCallUserdata: type) type {
    return struct {
        pub fn registerClass(
            class_name: *StringName,
            base_name: *StringName,
            info: CreationInfo,
        ) void {
            const userdata = &struct {
                var userdata: ?ClassInternalUserdata = null;
            }.userdata;

            if (userdata != null) {
                std.log.warn("The class '" ++ @typeName(T) ++ "' is already registered.", .{});
            }

            userdata.* = .{
                .userdata = info.userdata,
                .vtable = info.vtable,
            };

            godot.interface.classdbRegisterExtensionClass4(godot.interface.library, class_name, base_name, &.{
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
                .class_userdata = userdata.?,
            });
        }

        /// Represents the data that is associated with a class. Contains the user's userdata, and gdzig's VTable.
        pub const ClassInternalUserdata = struct {
            userdata: ClassUserdata,
            vtable: VTable,
        };

        /// Binding represents the data that is associated with an instance.
        pub const Binding = struct {
            ptr: *T,
            vtable: *VTable,
        };

        pub const CreationInfo = struct {
            is_virtual: bool = false,
            is_abstract: bool = false,
            is_exposed: bool = false,
            is_runtime: bool = false,
            icon_path: ?String = null,
            userdata: ClassUserdata,
            vtable: VTable = .{},
        };

        pub const VTable = struct {
            // Static
            init: ?CreateInstance2 = if (@hasDecl(T, "_init")) &T._init else null,
            deinit: ?FreeInstance = if (@hasDecl(T, "_deinit")) &T._deinit else null,
            reinit: ?RecreateInstance = if (@hasDecl(T, "_reinit")) &T._reinit else null,
            getVirtual: ?GetVirtual2 = if (@hasDecl(T, "_getVirtual")) &T._getVirtual else null,
            getVirtualCallData: ?GetVirtualCallData2 = if (@hasDecl(T, "_getVirtualCallData")) &T._getVirtualCallData else null,

            // Instance
            set: ?Set = if (@hasDecl(T, "_set")) &T._set else null,
            get: ?Get = if (@hasDecl(T, "_get")) &T._get else null,
            getPropertyList: ?GetPropertyList = if (@hasDecl(T, "_getPropertyList")) &T._getPropertyList else null,
            freePropertyList: ?FreePropertyList2 = if (@hasDecl(T, "_freePropertyList")) &T._freePropertyList else null,
            propertyCanRevert: ?PropertyCanRevert = if (@hasDecl(T, "_propertyCanRevert")) &T._propertyCanRevert else null,
            propertyGetRevert: ?PropertyGetRevert = if (@hasDecl(T, "_propertyGetRevert")) &T._propertyGetRevert else null,
            validateProperty: ?ValidateProperty = if (@hasDecl(T, "_validateProperty")) &T._validateProperty else null,
            notification: ?Notification2 = if (@hasDecl(T, "_notification")) &T._notification else null,
            toString: ?ToString = if (@hasDecl(T, "_toString")) &T._toString else null,
            reference: ?Reference = if (@hasDecl(T, "_reference")) &T._reference else null,
            unreference: ?Unreference = if (@hasDecl(T, "_unreference")) &T._unreference else null,
        };

        // Static methods
        pub const FreeInstance = *const fn (userdata: ClassUserdata, instance: *T) void;
        pub const RecreateInstance = *const fn (userdata: ClassUserdata, object: *Object) *anyopaque;
        pub const GetVirtual = *const fn (userdata: ClassUserdata, name: StringName) ?CallVirtual;
        pub const GetVirtual2 = *const fn (userdata: ClassUserdata, name: StringName, hash: u32) ?CallVirtual;
        pub const GetVirtualCallData = *const fn (userdata: ClassUserdata, name: StringName) ?*VirtualCallUserdata;
        pub const GetVirtualCallData2 = *const fn (userdata: ClassUserdata, name: StringName, hash: u32) ?*VirtualCallUserdata;

        // Instance methods
        pub const Set = *const fn (instance: *T, name: StringName, value: *const Variant) bool;
        pub const Get = *const fn (instance: *T, name: StringName) ?Variant;
        pub const GetPropertyList = *const fn (instance: *T) []PropertyInfo;
        pub const FreePropertyList = *const fn (instance: *T, properties: [*]PropertyInfo) void;
        pub const FreePropertyList2 = *const fn (instance: *T, properties: []PropertyInfo) void;
        pub const PropertyCanRevert = *const fn (instance: *T, name: StringName) bool;
        pub const PropertyGetRevert = *const fn (instance: *T, name: StringName) ?Variant;
        pub const ValidateProperty = *const fn (instance: *T, info: *PropertyInfo) bool;
        pub const Notification = *const fn (instance: *T, what: i32) void;
        pub const Notification2 = *const fn (instance: *T, what: i32, reversed: bool) void;
        pub const ToString = *const fn (instance: *T) ?String;
        pub const Reference = *const fn (instance: *T) void;
        pub const Unreference = *const fn (instance: *T) void;
        pub const GetRID = *const fn (instance: *T) u64;

        // Callbacks
        pub const CallVirtual = *const fn (instance: *T, args: []const *anyopaque) *anyopaque;
        pub const CallVirtualWithData = *const fn (instance: *T, method_name: StringName, userdata: *VirtualCallUserdata, args: []const *anyopaque) ?*anyopaque;

        pub const CreateInstance = *const fn (userdata: ClassUserdata) *Object;

        fn createInstance(userdata: ?*anyopaque) callconv(.c) c.GDExtensionObjectPtr {
            std.debug.print("createInstance\n", .{});

            const extension_data: *ClassInternalUserdata = @ptrCast(@alignCast(userdata.?));
            if (extension_data.vtable.init) |createInstance_fn| {
                const ret = createInstance_fn.?(extension_data.userdata);
                return @ptrCast(@alignCast(meta.asObject(ret)));
            } else {
                const ret = object.create(T) catch unreachable;
                return @ptrCast(@alignCast(meta.asObject(ret)));
            }

            return @ptrCast(ret);
        }

        pub const CreateInstance2 = *const fn (userdata: ClassUserdata, notify_postinitialize: bool) *Object;

        fn createInstance2(p_userdata: ?*anyopaque, p_notify_postinitialize: c.GDExtensionBool) callconv(.c) c.GDExtensionObjectPtr {
            std.debug.print("createInstance2\n", .{});
            const userdata: *ClassInternalUserdata = @ptrCast(@alignCast(p_userdata.?));

            const ret = userdata.vtable.init.?(userdata.userdata, p_notify_postinitialize != 0);

            godot.interface.objectSetInstance(@ptrCast(ret.base), @ptrCast(userdata.class_name), @ptrCast(ret));
            godot.interface.objectSetInstanceBinding(@ptrCast(ret.base), godot.interface.library,
                // TODO: is this stack allocated? probably needs to be on heap?
                Binding{
                    .ptr = @ptrCast(ret),
                    .vtable = &userdata.vtable,
                }, &dummy_callbacks);

            return @ptrCast(ret);
        }

        fn freeInstance(
            userdata: ?*anyopaque,
            instance: c.GDExtensionClassInstancePtr,
        ) callconv(.c) void {
            std.debug.print("freeInstance\n", .{});
            const extension_data: *ClassInternalUserdata = @ptrCast(@alignCast(userdata.?));
            const p_instance: *anyopaque = instance.?;

            extension_data.vtable.deinit.?(extension_data.userdata, p_instance);
        }

        fn recreateInstance(
            userdata: ?*anyopaque,
            object: c.GDExtensionObjectPtr,
        ) callconv(.c) c.GDExtensionClassInstancePtr {
            std.debug.print("recreateInstance\n", .{});
            const extension_data: *ClassInternalUserdata = @ptrCast(@alignCast(userdata.?));
            const p_object: *Object = @ptrCast(object.?);

            const ret = extension_data.vtable.reinit.?(extension_data.userdata, p_object);

            return @ptrCast(ret);
        }

        fn getVirtual(
            userdata: ?*anyopaque,
            name: c.GDExtensionConstStringNamePtr,
        ) callconv(.c) c.GDExtensionClassCallVirtual {
            std.debug.print("getVirtual\n", .{});

            const extension_data: *ClassInternalUserdata = @ptrCast(@alignCast(userdata.?));
            const p_name: StringName = @as(*const StringName, @ptrCast(name.?)).*;

            const ret = extension_data.vtable.getVirtual.?(extension_data.userdata, p_name);
            _ = ret; // autofix

            @panic("TODO");
        }

        fn getVirtual2(
            userdata: ?*anyopaque,
            name: c.GDExtensionConstStringNamePtr,
            hash: u32,
        ) callconv(.c) c.GDExtensionClassCallVirtual {
            std.debug.print("getVirtual2\n", .{});

            const extension_data: *ClassInternalUserdata = @ptrCast(@alignCast(userdata.?));
            const p_name: StringName = @as(*const StringName, @ptrCast(name.?)).*;

            const ret = extension_data.vtable.getVirtual.?(extension_data.userdata, p_name, hash);
            _ = ret; // autofix

            @panic("TODO");
        }

        fn getVirtualCallData(
            userdata: ?*anyopaque,
            name: c.GDExtensionConstStringNamePtr,
        ) callconv(.c) ?*anyopaque {
            std.debug.print("getVirtualCallData\n", .{});

            const extension_data: *ClassInternalUserdata = @ptrCast(@alignCast(userdata.?));
            const p_name: StringName = @as(*const StringName, @ptrCast(name.?)).*;

            const ret = extension_data.vtable.getVirtualCallData.?(extension_data.userdata, p_name);

            return ret;
        }

        fn getVirtualCallData2(
            userdata: ?*anyopaque,
            name: c.GDExtensionConstStringNamePtr,
            hash: u32,
        ) callconv(.c) ?*anyopaque {
            std.debug.print("getVirtualCallData2\n", .{});

            const extension_data: *ClassInternalUserdata = @ptrCast(@alignCast(userdata.?));
            const p_name: StringName = @as(*const StringName, @ptrCast(name.?)).*;

            const ret = extension_data.vtable.getVirtualCallData.?(extension_data.userdata, p_name, hash);

            return ret;
        }

        fn set(
            instance: c.GDExtensionClassInstancePtr,
            name: c.GDExtensionConstStringNamePtr,
            variant: c.GDExtensionConstVariantPtr,
        ) callconv(.c) c.GDExtensionBool {
            std.debug.print("set\n", .{});
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
            std.debug.print("get\n", .{});
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
            std.debug.print("getPropertyList\n", .{});
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
            std.debug.print("freePropertyList\n", .{});
            const freePropertyList_fn = getMethod(instance, "freePropertyList") orelse return;

            const p_instance: *anyopaque = instance.?;

            freePropertyList_fn(p_instance, list);
        }

        fn freePropertyList2(
            instance: c.GDExtensionClassInstancePtr,
            list: [*c]const c.GDExtensionPropertyInfo,
            count: u32,
        ) callconv(.c) void {
            std.debug.print("freePropertyList\n", .{});
            const freePropertyList_fn = getMethod(instance, "freePropertyList") orelse return;

            const p_instance: *anyopaque = instance.?;

            freePropertyList_fn(p_instance, @ptrCast(@constCast(list[0..count])));
        }

        fn propertyCanRevert(
            instance: c.GDExtensionClassInstancePtr,
            name: c.GDExtensionConstStringNamePtr,
        ) callconv(.c) c.GDExtensionBool {
            std.debug.print("propertyCanRevert\n", .{});
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
            std.debug.print("propertyGetRevert\n", .{});
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
            std.debug.print("validateProperty\n", .{});
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
            std.debug.print("notification\n", .{});
            const notification_fn = getMethod(instance, "notification") orelse return;

            const p_instance: *anyopaque = instance.?;

            notification_fn(p_instance, what);
        }

        fn notification2(
            instance: c.GDExtensionClassInstancePtr,
            what: i32,
            reversed: c.GDExtensionBool,
        ) callconv(.c) void {
            std.debug.print("notification\n", .{});
            const notification_fn = getMethod(instance, "notification") orelse return;

            const p_instance: *anyopaque = instance.?;

            notification_fn(p_instance, what, reversed != 0);
        }

        fn toString(
            instance: c.GDExtensionClassInstancePtr,
            is_valid: [*c]c.GDExtensionBool,
            string: c.GDExtensionStringPtr,
        ) callconv(.c) void {
            std.debug.print("toString\n", .{});
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
            std.debug.print("reference\n", .{});
            const reference_fn = getMethod(instance, "reference") orelse return;

            const p_instance: *anyopaque = instance.?;

            reference_fn(p_instance);
        }

        fn unreference(
            instance: c.GDExtensionClassInstancePtr,
        ) callconv(.c) void {
            std.debug.print("unreference\n", .{});
            const unreference_fn = getMethod(instance, "unreference") orelse return;

            const p_instance: *anyopaque = instance.?;

            unreference_fn(p_instance);
        }

        fn getRid(
            instance: c.GDExtensionClassInstancePtr,
        ) callconv(.c) u64 {
            std.debug.print("getRid\n", .{});

            const getRid_fn = getMethod(instance, "getRid") orelse return 0;

            const p_instance: *anyopaque = instance.?;

            const ret = getRid_fn(p_instance);

            return ret;
        }

        fn callVirtual(
            instance: c.GDExtensionClassInstancePtr,
            args: [*c]const c.GDExtensionConstTypePtr,
            ret: c.GDExtensionTypePtr,
        ) callconv(.c) void {
            std.debug.print("callVirtual\n", .{});
            const callVirtual_fn = getMethod(instance, "callVirtual") orelse return;

            const p_instance: *anyopaque = instance.?;
            const p_args: []const *anyopaque = @ptrCast(args);
            const r_ret: *anyopaque = @ptrCast(ret);

            const result = callVirtual_fn(p_instance, p_args);
            r_ret.* = result.*;
        }

        fn callVirtualWithData(
            instance: c.GDExtensionClassInstancePtr,
            name: c.GDExtensionConstStringNamePtr,
            virtual_call_userdata: ?*anyopaque,
            args: [*c]const c.GDExtensionConstTypePtr,
            ret: c.GDExtensionTypePtr,
        ) callconv(.c) void {
            std.debug.print("callVirtualWithData\n", .{});

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

        fn getMethod(instance: ?*anyopaque, comptime method_name: []const u8) @FieldType(ClassInternalUserdata.VTable, method_name) {
            const ptr = godot.interface.objectGetInstanceBinding(instance.?, godot.interface.library, null).?;
            const binding: *ClassInternalUserdata.Binding = @ptrCast(@alignCast(ptr));
            return @field(binding.vtable, method_name);
        }
    };
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
