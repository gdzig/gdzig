//! These functions and types are very thin wrappers around the Godot C API to expose a Zig friendly
//! interface. They do not add any additional functionality, other than what is strictly necessary to
//! create an idiomatic interface.
//!
//! If you're looking for the raw C APIs without any wrappers, you can find them exposed in the
//! `godot.c` module.
//!

pub fn bind(func: anytype, vars: anytype) *const fn_binding.BoundFn(@TypeOf(func), @TypeOf(vars)) {
    return fn_binding.bind(func, vars) catch unreachable;
}

pub fn registerClass(
    comptime T: type,
    comptime Userdata: type,
    class_name: *StringName,
    base_name: *StringName,
    info: ClassCreationInfo(T, Userdata),
) void {
    const Info = @TypeOf(info);
    const Func = struct {
        fn set(instance: c.GDExtensionClassInstancePtr, name: c.GDExtensionConstStringNamePtr, variant: c.GDExtensionConstVariantPtr, callback_ptr: *anyopaque) callconv(.c) c.GDExtensionBool {
            const callback: *const Info.callback.Set = @ptrCast(@alignCast(callback_ptr));
            const result = callback(@ptrCast(@alignCast(instance.?)), @ptrCast(name.?), @ptrCast(@alignCast(variant.?)));
            return @intFromBool(result);
        }
        fn get(instance: c.GDExtensionClassInstancePtr, name: c.GDExtensionConstStringNamePtr, variant: c.GDExtensionVariantPtr, callback_ptr: *anyopaque) callconv(.c) c.GDExtensionBool {
            const callback: *const Info.callback.Get = @ptrCast(@alignCast(callback_ptr));
            if (callback(@ptrCast(@alignCast(instance.?)), @ptrCast(name.?))) |result| {
                @as(*Variant, @ptrCast(@alignCast(variant.?))).* = result;
                return 1;
            }
            return 0;
        }
        fn getPropertyList(instance: c.GDExtensionClassInstancePtr, count: [*c]u32, callback_ptr: *anyopaque) callconv(.c) [*c]const c.GDExtensionPropertyInfo {
            const callback: *const Info.callback.GetPropertyList = @ptrCast(@alignCast(callback_ptr));
            const slice = callback(@ptrCast(@alignCast(instance.?)));
            count.* = @intCast(slice.len);
            return @ptrCast(slice.ptr);
        }
        fn freePropertyList(instance: c.GDExtensionClassInstancePtr, list: [*c]const c.GDExtensionPropertyInfo, callback_ptr: *anyopaque) callconv(.c) void {
            const callback: *const Info.callback.FreePropertyList = @ptrCast(@alignCast(callback_ptr));
            callback(@ptrCast(@alignCast(instance.?)), list);
        }
        fn freePropertyList2(instance: c.GDExtensionClassInstancePtr, list: [*c]const c.GDExtensionPropertyInfo, count: u32, callback_ptr: *anyopaque) callconv(.c) void {
            const callback: *const Info.callback.FreePropertyList2 = @ptrCast(@alignCast(callback_ptr));
            callback(@ptrCast(@alignCast(instance.?)), @ptrCast(@constCast(list[0..count])));
        }
        fn propertyCanRevert(instance: c.GDExtensionClassInstancePtr, name: c.GDExtensionConstStringNamePtr, callback_ptr: *anyopaque) callconv(.c) c.GDExtensionBool {
            const callback: *const Info.callback.PropertyCanRevert = @ptrCast(@alignCast(callback_ptr));
            const result = callback(@ptrCast(@alignCast(instance.?)), @ptrCast(name.?));
            return @intFromBool(result);
        }
        fn propertyGetRevert(instance: c.GDExtensionClassInstancePtr, name: c.GDExtensionConstStringNamePtr, variant: c.GDExtensionVariantPtr, callback_ptr: *anyopaque) callconv(.c) c.GDExtensionBool {
            const callback: *const Info.callback.PropertyGetRevert = @ptrCast(@alignCast(callback_ptr));
            if (callback(@ptrCast(@alignCast(instance.?)), @ptrCast(name.?))) |result| {
                @as(*Variant, @ptrCast(@alignCast(variant.?))).* = result;
                return 1;
            }
            return 0;
        }
        fn validateProperty(instance: c.GDExtensionClassInstancePtr, property: [*c]c.GDExtensionPropertyInfo, callback_ptr: *anyopaque) callconv(.c) c.GDExtensionBool {
            const callback: *const Info.callback.ValidateProperty = @ptrCast(@alignCast(callback_ptr));
            const result = callback(@ptrCast(@alignCast(instance.?)), @ptrCast(property));
            return @intFromBool(result);
        }
        fn notification(instance: c.GDExtensionClassInstancePtr, what: i32, callback_ptr: *anyopaque) callconv(.c) void {
            const callback: *const Info.callback.Notification = @ptrCast(@alignCast(callback_ptr));
            callback(@ptrCast(@alignCast(instance.?)), what);
        }
        fn notification2(instance: c.GDExtensionClassInstancePtr, what: i32, reversed: c.GDExtensionBool, callback_ptr: *anyopaque) callconv(.c) void {
            const callback: *const Info.callback.Notification2 = @ptrCast(@alignCast(callback_ptr));
            callback(@ptrCast(@alignCast(instance.?)), what, reversed != 0);
        }
        fn toString(instance: c.GDExtensionClassInstancePtr, is_valid: [*c]c.GDExtensionBool, string: c.GDExtensionStringPtr, callback_ptr: *anyopaque) callconv(.c) void {
            const callback: *const Info.callback.ToString = @ptrCast(@alignCast(callback_ptr));
            if (callback(@ptrCast(@alignCast(instance.?)))) |result| {
                @as(*String, @ptrCast(@alignCast(string.?))).* = result;
                @as(*u8, @ptrCast(is_valid.?)).* = 1;
            } else {
                @as(*u8, @ptrCast(is_valid.?)).* = 0;
            }
        }
        fn reference(instance: c.GDExtensionClassInstancePtr, callback_ptr: *anyopaque) callconv(.c) void {
            const callback: *const Info.callback.Reference = @ptrCast(@alignCast(callback_ptr));
            callback(@ptrCast(@alignCast(instance.?)));
        }
        fn unreference(instance: c.GDExtensionClassInstancePtr, callback_ptr: *anyopaque) callconv(.c) void {
            const callback: *const Info.callback.Unreference = @ptrCast(@alignCast(callback_ptr));
            callback(@ptrCast(@alignCast(instance.?)));
        }
        fn createInstance(userdata: ?*anyopaque, callback_ptr: *anyopaque) callconv(.c) c.GDExtensionObjectPtr {
            const callback: *const Info.callback.CreateInstance = @ptrCast(@alignCast(callback_ptr));
            if (Userdata == void) {
                return @ptrCast(callback());
            } else {
                return @ptrCast(callback(@ptrCast(userdata.?)));
            }
        }
        fn createInstance2(userdata: ?*anyopaque, notify_postinitialize: c.GDExtensionBool, callback_ptr: *anyopaque) callconv(.c) c.GDExtensionObjectPtr {
            const callback: *const Info.callback.CreateInstance2 = @ptrCast(@alignCast(callback_ptr));
            if (Userdata == void) {
                return @ptrCast(callback(notify_postinitialize));
            } else {
                return @ptrCast(callback(@ptrCast(userdata.?), notify_postinitialize != 0));
            }
        }
        fn freeInstance(userdata: ?*anyopaque, instance: c.GDExtensionClassInstancePtr, callback_ptr: *anyopaque) callconv(.c) void {
            const callback: *const Info.callback.FreeInstance = @ptrCast(@alignCast(callback_ptr));
            if (Userdata == void) {
                callback(@ptrCast(@alignCast(instance.?)));
            } else {
                callback(@ptrCast(userdata.?), @ptrCast(@alignCast(instance.?)));
            }
        }
        fn recreateInstance(userdata: ?*anyopaque, object: c.GDExtensionObjectPtr, callback_ptr: *anyopaque) callconv(.c) c.GDExtensionClassInstancePtr {
            const callback: *const Info.callback.RecreateInstance = @ptrCast(@alignCast(callback_ptr));
            if (Userdata == void) {
                return @ptrCast(callback(@ptrCast(object.?)));
            } else {
                return @ptrCast(callback(@ptrCast(userdata.?), @ptrCast(object.?)));
            }
        }
        fn getVirtual(userdata: ?*anyopaque, name: c.GDExtensionConstStringNamePtr, callback_ptr: *anyopaque) callconv(.c) c.GDExtensionClassCallVirtual {
            _ = userdata; // autofix
            _ = name; // autofix
            const callback: *const Info.callback.GetVirtual = @ptrCast(@alignCast(callback_ptr));
            _ = callback; // autofix
            if (Userdata == void) {
                @panic("TODO: wrap the returned callback");
                // return callback(@ptrCast(name.?));
            } else {
                @panic("TODO: wrap the returned callback");
                // return callback(@ptrCast(userdata.?), @ptrCast(name.?));
            }
        }
        fn getVirtual2(userdata: ?*anyopaque, name: c.GDExtensionConstStringNamePtr, hash: u32, callback_ptr: *anyopaque) callconv(.c) c.GDExtensionClassCallVirtual {
            _ = userdata; // autofix
            _ = name; // autofix
            _ = hash; // autofix
            const callback: *const Info.callback.GetVirtual2 = @ptrCast(@alignCast(callback_ptr));
            _ = callback; // autofix
            if (Userdata == void) {
                @panic("TODO: wrap the returned callback");
                // return callback(@ptrCast(name.?), hash);
            } else {
                @panic("TODO: wrap the returned callback");
                // return callback(@ptrCast(userdata.?), @ptrCast(name.?), hash);
            }
        }
        fn getVirtualCallData(userdata: ?*anyopaque, name: c.GDExtensionConstStringNamePtr, callback_ptr: *anyopaque) callconv(.c) ?*anyopaque {
            const callback: *const Info.callback.GetVirtualCallData = @ptrCast(@alignCast(callback_ptr));
            if (Userdata == void) {
                return callback(@ptrCast(name.?));
            } else {
                return callback(@ptrCast(userdata.?), @ptrCast(name.?));
            }
        }
        fn getVirtualCallData2(userdata: ?*anyopaque, name: c.GDExtensionConstStringNamePtr, hash: u32, callback_ptr: *anyopaque) callconv(.c) ?*anyopaque {
            const callback: *const Info.callback.GetVirtualCallData2 = @ptrCast(@alignCast(callback_ptr));
            if (Userdata == void) {
                return callback(@ptrCast(name.?), hash);
            } else {
                return callback(@ptrCast(userdata.?), @ptrCast(name.?), hash);
            }
        }
        fn callVirtualWithData(instance: c.GDExtensionClassInstancePtr, name: c.GDExtensionConstStringNamePtr, virtual_call_userdata: ?*anyopaque, args: [*c]const c.GDExtensionConstTypePtr, ret: c.GDExtensionTypePtr, callback_ptr: *anyopaque) callconv(.c) void {
            _ = instance; // autofix
            _ = name; // autofix
            _ = virtual_call_userdata; // autofix
            _ = args; // autofix
            _ = ret; // autofix
            const callback: *const Info.callback.CallVirtualWithData = @ptrCast(@alignCast(callback_ptr));
            _ = callback; // autofix
            // ret.* = callback(@ptrCast(@alignCast(instance.?)), @ptrCast(name.?), virtual_call_userdata, args, ret);
            @panic("TODO: implement");
        }
        fn getRid(instance: c.GDExtensionClassInstancePtr, callback_ptr: *anyopaque) callconv(.c) u64 {
            const callback: *const Info.callback.GetRid = @ptrCast(@alignCast(callback_ptr));
            return callback(@ptrCast(@alignCast(instance.?)));
        }
    };

    return if (@hasDecl(godot.c, "GDExtensionClassCreationInfo4"))
        godot.interface.classdbRegisterExtensionClass4(godot.interface.library, base_name, class_name, &.{
            .is_virtual = @intFromBool(info.is_virtual),
            .is_abstract = @intFromBool(info.is_abstract),
            .is_exposed = @intFromBool(info.is_exposed),
            .is_runtime = @intFromBool(info.is_runtime),
            .icon_path = @ptrCast(info.icon_path), // added in v4
            .set_func = if (info.set) |cb| bind(Func.set, .{ .@"-1" = @as(*anyopaque, @ptrCast(@constCast(cb))) }) else null,
            .get_func = if (info.get) |cb| bind(Func.get, .{ .@"-1" = @as(*anyopaque, @ptrCast(@constCast(cb))) }) else null,
            .get_property_list_func = if (info.get_property_list) |cb| bind(Func.getPropertyList, .{ .@"-1" = @as(*anyopaque, @ptrCast(@constCast(cb))) }) else null,
            .free_property_list_func = if (info.free_property_list) |cb| bind(Func.freePropertyList2, .{ .@"-1" = @as(*anyopaque, @ptrCast(@constCast(cb))) }) else null,
            .property_can_revert_func = if (info.property_can_revert) |cb| bind(Func.propertyCanRevert, .{ .@"-1" = @as(*anyopaque, @ptrCast(@constCast(cb))) }) else null,
            .property_get_revert_func = if (info.property_get_revert) |cb| bind(Func.propertyGetRevert, .{ .@"-1" = @as(*anyopaque, @ptrCast(@constCast(cb))) }) else null,
            .validate_property_func = if (info.validate_property) |cb| bind(Func.validateProperty, .{ .@"-1" = @as(*anyopaque, @ptrCast(@constCast(cb))) }) else null,
            .notification_func = if (info.notification) |cb| bind(Func.notification2, .{ .@"-1" = @as(*anyopaque, @ptrCast(@constCast(cb))) }) else null,
            .to_string_func = if (info.to_string) |cb| bind(Func.toString, .{ .@"-1" = @as(*anyopaque, @ptrCast(@constCast(cb))) }) else null,
            .reference_func = if (info.reference) |cb| bind(Func.reference, .{ .@"-1" = @as(*anyopaque, @ptrCast(@constCast(cb))) }) else null,
            .unreference_func = if (info.unreference) |cb| bind(Func.unreference, .{ .@"-1" = @as(*anyopaque, @ptrCast(@constCast(cb))) }) else null,
            .create_instance_func = bind(Func.createInstance2, .{ .@"-1" = @as(*anyopaque, @ptrCast(@constCast(info.create_instance))) }), // signature changed in v4
            .free_instance_func = bind(Func.freeInstance, .{ .@"-1" = @as(*anyopaque, @ptrCast(@constCast(info.free_instance))) }),
            .recreate_instance_func = if (info.recreate_instance) |cb| bind(Func.recreateInstance, .{ .@"-1" = @as(*anyopaque, @ptrCast(@constCast(cb))) }) else null,
            .get_virtual_func = if (info.get_virtual) |cb| bind(Func.getVirtual2, .{ .@"-1" = @as(*anyopaque, @ptrCast(@constCast(cb))) }) else null, // signature changed in v4
            .get_virtual_call_data_func = if (info.get_virtual_call_data) |cb| bind(Func.getVirtualCallData2, .{ .@"-1" = @as(*anyopaque, @ptrCast(@constCast(cb))) }) else null, // signature changed in v4
            .call_virtual_with_data_func = if (info.call_virtual_with_data) |cb| bind(Func.callVirtualWithData, .{ .@"-1" = @as(*anyopaque, @ptrCast(@constCast(cb))) }) else null,
            .class_userdata = if (Userdata == void) null else @ptrCast(info.class_userdata),
        })
    else if (@hasDecl(godot.c, "GDExtensionClassCreationInfo3"))
        godot.interface.classdbRegisterExtensionClass3(godot.interface.library, base_name, class_name, &.{
            .is_virtual = @intFromBool(info.is_virtual),
            .is_abstract = @intFromBool(info.is_abstract),
            .is_exposed = @intFromBool(info.is_exposed),
            .is_runtime = @intFromBool(info.is_runtime), // added in v3
            .set_func = if (info.set) |cb| bind(Func.set, .{ .@"-1" = @as(*anyopaque, @ptrCast(@constCast(cb))) }) else null,
            .get_func = if (info.get) |cb| bind(Func.get, .{ .@"-1" = @as(*anyopaque, @ptrCast(@constCast(cb))) }) else null,
            .get_property_list_func = if (info.get_property_list) |cb| bind(Func.getPropertyList, .{ .@"-1" = @as(*anyopaque, @ptrCast(@constCast(cb))) }) else null,
            .free_property_list_func = if (info.free_property_list) |cb| bind(Func.freePropertyList2, .{ .@"-1" = @as(*anyopaque, @ptrCast(@constCast(cb))) }) else null, // signature changed in v3
            .property_can_revert_func = if (info.property_can_revert) |cb| bind(Func.propertyCanRevert, .{ .@"-1" = @as(*anyopaque, @ptrCast(@constCast(cb))) }) else null,
            .property_get_revert_func = if (info.property_get_revert) |cb| bind(Func.propertyGetRevert, .{ .@"-1" = @as(*anyopaque, @ptrCast(@constCast(cb))) }) else null,
            .validate_property_func = if (info.validate_property) |cb| bind(Func.validateProperty, .{ .@"-1" = @as(*anyopaque, @ptrCast(@constCast(cb))) }) else null,
            .notification_func = if (info.notification) |cb| bind(Func.notification2, .{ .@"-1" = @as(*anyopaque, @ptrCast(@constCast(cb))) }) else null,
            .to_string_func = if (info.to_string) |cb| bind(Func.toString, .{ .@"-1" = @as(*anyopaque, @ptrCast(@constCast(cb))) }) else null,
            .reference_func = if (info.reference) |cb| bind(Func.reference, .{ .@"-1" = @as(*anyopaque, @ptrCast(@constCast(cb))) }) else null,
            .unreference_func = if (info.unreference) |cb| bind(Func.unreference, .{ .@"-1" = @as(*anyopaque, @ptrCast(@constCast(cb))) }) else null,
            .create_instance_func = bind(Func.createInstance, .{ .@"-1" = info.create_instance }),
            .free_instance_func = bind(Func.freeInstance, .{ .@"-1" = info.free_instance }),
            .recreate_instance_func = if (info.recreate_instance) |cb| bind(Func.recreateInstance, .{ .@"-1" = @as(*anyopaque, @ptrCast(@constCast(cb))) }) else null,
            .get_virtual_func = if (info.get_virtual) |cb| bind(Func.getVirtual, .{ .@"-1" = @as(*anyopaque, @ptrCast(@constCast(cb))) }) else null,
            .get_virtual_call_data_func = if (info.get_virtual_call_data) |cb| bind(Func.getVirtualCallData, .{ .@"-1" = @as(*anyopaque, @ptrCast(@constCast(cb))) }) else null,
            .call_virtual_with_data_func = if (info.call_virtual_with_data) |cb| bind(Func.callVirtualWithData, .{ .@"-1" = @as(*anyopaque, @ptrCast(@constCast(cb))) }) else null,
            .get_rid_func = if (info.get_rid) |cb| bind(Func.getRid, .{ .@"-1" = @as(*anyopaque, @ptrCast(@constCast(cb))) }) else null,
            .class_userdata = if (Userdata == void) null else @ptrCast(info.class_userdata),
        })
    else if (@hasDecl(godot.c, "GDExtensionClassCreationInfo2"))
        godot.interface.classdbRegisterExtensionClass2(godot.interface.library, base_name, class_name, &.{
            .is_virtual = @intFromBool(info.is_virtual),
            .is_abstract = @intFromBool(info.is_abstract),
            .is_exposed = @intFromBool(info.is_exposed), // added in v2
            .set_func = if (info.set) |cb| bind(Func.set, .{ .@"-1" = @as(*anyopaque, @ptrCast(@constCast(cb))) }) else null,
            .get_func = if (info.get) |cb| bind(Func.get, .{ .@"-1" = @as(*anyopaque, @ptrCast(@constCast(cb))) }) else null,
            .get_property_list_func = if (info.get_property_list) |cb| bind(Func.getPropertyList, .{ .@"-1" = @as(*anyopaque, @ptrCast(@constCast(cb))) }) else null,
            .free_property_list_func = if (info.free_property_list) |cb| bind(Func.freePropertyList, .{ .@"-1" = @as(*anyopaque, @ptrCast(@constCast(cb))) }) else null,
            .property_can_revert_func = if (info.property_can_revert) |cb| bind(Func.propertyCanRevert, .{ .@"-1" = @as(*anyopaque, @ptrCast(@constCast(cb))) }) else null,
            .property_get_revert_func = if (info.property_get_revert) |cb| bind(Func.propertyGetRevert, .{ .@"-1" = @as(*anyopaque, @ptrCast(@constCast(cb))) }) else null,
            .validate_property_func = if (info.validate_property) |cb| bind(Func.validateProperty, .{ .@"-1" = @as(*anyopaque, @ptrCast(@constCast(cb))) }) else null, // added in v2
            .notification_func = if (info.notification) |cb| bind(Func.notification2, .{ .@"-1" = @as(*anyopaque, @ptrCast(@constCast(cb))) }) else null, // signature changed in v2
            .to_string_func = if (info.to_string) |cb| bind(Func.toString, .{ .@"-1" = @as(*anyopaque, @ptrCast(@constCast(cb))) }) else null,
            .reference_func = if (info.reference) |cb| bind(Func.reference, .{ .@"-1" = @as(*anyopaque, @ptrCast(@constCast(cb))) }) else null,
            .unreference_func = if (info.unreference) |cb| bind(Func.unreference, .{ .@"-1" = @as(*anyopaque, @ptrCast(@constCast(cb))) }) else null,
            .create_instance_func = bind(Func.createInstance, .{ .@"-1" = info.create_instance }),
            .free_instance_func = bind(Func.freeInstance, .{ .@"-1" = info.free_instance }),
            .recreate_instance_func = if (info.recreate_instance) |cb| bind(Func.recreateInstance, .{ .@"-1" = @as(*anyopaque, @ptrCast(@constCast(cb))) }) else null, // added in v2
            .get_virtual_func = if (info.get_virtual) |cb| bind(Func.getVirtual, .{ .@"-1" = @as(*anyopaque, @ptrCast(@constCast(cb))) }) else null,
            .get_virtual_call_data_func = if (info.get_virtual_call_data) |cb| bind(Func.getVirtualCallData, .{ .@"-1" = @as(*anyopaque, @ptrCast(@constCast(cb))) }) else null, // added in v2
            .call_virtual_with_data_func = if (info.call_virtual_with_data) |cb| bind(Func.callVirtualWithData, .{ .@"-1" = @as(*anyopaque, @ptrCast(@constCast(cb))) }) else null, // added in v2
            .get_rid_func = if (info.get_rid) |cb| bind(Func.getRid, .{ .@"-1" = @as(*anyopaque, @ptrCast(@constCast(cb))) }) else null,
            .class_userdata = if (Userdata == void) null else @ptrCast(info.class_userdata),
        })
    else if (@hasDecl(godot.c, "GDExtensionClassCreationInfo"))
        godot.interface.classdbRegisterExtensionClass(godot.interface.library, base_name, class_name, &.{
            .is_virtual = @intFromBool(info.is_virtual),
            .is_abstract = @intFromBool(info.is_abstract),
            .set_func = if (info.set) |cb| bind(Func.set, .{ .@"-1" = @as(*anyopaque, @ptrCast(@constCast(cb))) }) else null,
            .get_func = if (info.get) |cb| bind(Func.get, .{ .@"-1" = @as(*anyopaque, @ptrCast(@constCast(cb))) }) else null,
            .get_property_list_func = if (info.get_property_list) |cb| bind(Func.getPropertyList, .{ .@"-1" = @as(*anyopaque, @ptrCast(@constCast(cb))) }) else null,
            .free_property_list_func = if (info.free_property_list) |cb| bind(Func.freePropertyList, .{ .@"-1" = @as(*anyopaque, @ptrCast(@constCast(cb))) }) else null,
            .property_can_revert_func = if (info.property_can_revert) |cb| bind(Func.propertyCanRevert, .{ .@"-1" = @as(*anyopaque, @ptrCast(@constCast(cb))) }) else null,
            .property_get_revert_func = if (info.property_get_revert) |cb| bind(Func.propertyGetRevert, .{ .@"-1" = @as(*anyopaque, @ptrCast(@constCast(cb))) }) else null,
            .notification_func = if (info.notification) |cb| bind(Func.notification, .{ .@"-1" = @as(*anyopaque, @ptrCast(@constCast(cb))) }) else null,
            .to_string_func = if (info.to_string) |cb| bind(Func.toString, .{ .@"-1" = @as(*anyopaque, @ptrCast(@constCast(cb))) }) else null,
            .reference_func = if (info.reference) |cb| bind(Func.reference, .{ .@"-1" = @as(*anyopaque, @ptrCast(@constCast(cb))) }) else null,
            .unreference_func = if (info.unreference) |cb| bind(Func.unreference, .{ .@"-1" = @as(*anyopaque, @ptrCast(@constCast(cb))) }) else null,
            .create_instance_func = bind(Func.createInstance, .{ .@"-1" = info.create_instance }),
            .free_instance_func = bind(Func.freeInstance, .{ .@"-1" = info.free_instance }),
            .get_virtual_func = if (info.get_virtual) |cb| bind(Func.getVirtual, .{ .@"-1" = @as(*anyopaque, @ptrCast(@constCast(cb))) }) else null,
            .get_rid_func = if (info.get_rid) |cb| bind(Func.getRid, .{ .@"-1" = @as(*anyopaque, @ptrCast(@constCast(cb))) }) else null,
            .class_userdata = if (Userdata == void) null else @ptrCast(info.class_userdata),
        })
    else
        @compileError("Godot version 4.1 or higher is required.");
}

pub fn ClassCreationInfo(comptime T: type, comptime Userdata: type) type {
    comptime godot.debug.assertIsObjectType(T);

    const cb = struct {
        pub const Set = fn (self: *T, *const StringName, *const Variant) bool;
        pub const Get = fn (self: *T, name: *const StringName) ?Variant;
        pub const GetPropertyList = fn (self: *T) []PropertyInfo;
        pub const FreePropertyList = fn (self: *T, [*]PropertyInfo) void;
        pub const FreePropertyList2 = fn (self: *T, []PropertyInfo) void;
        pub const PropertyCanRevert = fn (self: *T, name: *const StringName) bool;
        pub const PropertyGetRevert = fn (self: *T, name: *const StringName) ?Variant;
        pub const ValidateProperty = fn (self: *T, info: *PropertyInfo) bool;
        pub const Notification = fn (self: *T, what: i32) void;
        pub const Notification2 = fn (self: *T, what: i32, reversed: bool) void;
        pub const ToString = fn (self: *T) ?String;
        pub const Reference = fn (self: *T) void;
        pub const Unreference = fn (self: *T) void;
        pub const CreateInstance = if (Userdata == void) fn () *Object else fn (userdata: *Userdata) *Object;
        pub const CreateInstance2 = if (Userdata == void) fn (notify_postinitialize: bool) *Object else fn (userdata: *Userdata, notify_postinitialize: bool) *Object;
        pub const FreeInstance = if (Userdata == void) fn (instance: *T) void else fn (userdata: *Userdata, instance: *T) void;
        pub const RecreateInstance = if (Userdata == void) fn (object: *Object) *T else fn (userdata: *Userdata, object: *Object) *T;
        pub const GetVirtual = if (Userdata == void) fn (name: *const StringName) ?*const CallVirtual else fn (userdata: *Userdata, name: *const StringName) ?*const CallVirtual;
        pub const GetVirtual2 = if (Userdata == void) fn (name: *const StringName, hash: u32) ?*const CallVirtual else fn (userdata: *Userdata, name: *const StringName, hash: u32) ?*const CallVirtual;
        pub const GetVirtualCallData = if (Userdata == void) fn (name: *const StringName) ?*anyopaque else fn (userdata: *Userdata, name: *const StringName) ?*anyopaque;
        pub const GetVirtualCallData2 = if (Userdata == void) fn (name: *const StringName, hash: u32) ?*anyopaque else fn (userdata: *Userdata, name: *const StringName, hash: u32) ?*anyopaque;
        pub const CallVirtual = fn (self: *T, args: []const *anyopaque) *anyopaque;
        pub const CallVirtualWithData = fn (self: *T, name: *const StringName, virtual_call_userdata: ?*anyopaque, args: []const *anyopaque) ?*anyopaque;
        pub const GetRID = fn (self: *T) u64;
    };

    return if (@hasDecl(c, "GDExtensionClassCreationInfo4"))
        struct {
            pub const callback = cb;

            is_virtual: bool = false,
            is_abstract: bool = false,
            is_exposed: bool = false,
            is_runtime: bool = false,
            icon_path: ?*const String = null, // added in v4
            set: ?*const callback.Set = null,
            get: ?*const callback.Get = null,
            get_property_list: ?*const callback.GetPropertyList = null,
            free_property_list: ?*const callback.FreePropertyList2 = null,
            property_can_revert: ?*const callback.PropertyCanRevert = null,
            property_get_revert: ?*const callback.PropertyGetRevert = null,
            validate_property: ?*const callback.ValidateProperty = null,
            notification: ?*const callback.Notification2 = null,
            to_string: ?*const callback.ToString = null,
            reference: ?*const callback.Reference = null,
            unreference: ?*const callback.Unreference = null,
            create_instance: *const callback.CreateInstance2, // signature changed in v4
            free_instance: *const callback.FreeInstance,
            recreate_instance: ?*const callback.RecreateInstance = null,
            get_virtual: ?*const callback.GetVirtual2 = null, // signature changed in v4
            get_virtual_call_data: ?*const callback.GetVirtualCallData2 = null, // signature changed in v4
            call_virtual_with_data: ?*const callback.CallVirtualWithData = null,
            class_userdata: if (Userdata == void) void else *Userdata = if (Userdata == void) {} else undefined,
        }
    else if (@hasDecl(c, "GDExtensionClassCreationInfo3"))
        struct {
            pub const callback = cb;

            is_virtual: bool = false,
            is_abstract: bool = false,
            is_exposed: bool = false,
            is_runtime: bool = false, // added in v3
            set: ?*const callback.Set = null,
            get: ?*const callback.Get = null,
            get_property_list: ?*const callback.GetPropertyList = null,
            free_property_list: ?*const callback.FreePropertyList2 = null, // signature changed in v3
            property_can_revert: ?*const callback.PropertyCanRevert = null,
            property_get_revert: ?*const callback.PropertyGetRevert = null,
            validate_property: ?*const callback.ValidateProperty = null,
            notification: ?*const callback.Notification2 = null,
            to_string: ?*const callback.ToString = null,
            reference: ?*const callback.Reference = null,
            unreference: ?*const callback.Unreference = null,
            create_instance: *const callback.CreateInstance,
            free_instance: *const callback.FreeInstance,
            recreate_instance: ?*const callback.RecreateInstance = null,
            get_virtual: ?*const callback.GetVirtual = null,
            get_virtual_call_data: ?*const callback.GetVirtualCallData = null,
            call_virtual_with_data: ?*const callback.CallVirtualWithData = null,
            get_rid: ?*const callback.GetRID = null, // removed in v4
            class_userdata: if (Userdata == void) void else *Userdata = if (Userdata == void) {} else undefined,
        }
    else if (@hasDecl(c, "GDExtensionClassCreationInfo2"))
        struct {
            pub const callback = cb;

            is_virtual: bool = false,
            is_abstract: bool = false,
            is_exposed: bool = false, // added in v2
            set: ?*const callback.Set = null,
            get: ?*const callback.Get = null,
            get_property_list: ?*const callback.GetPropertyList = null,
            free_property_list: ?*const callback.FreePropertyList = null,
            property_can_revert: ?*const callback.PropertyCanRevert = null,
            property_get_revert: ?*const callback.PropertyGetRevert = null,
            validate_property: ?*const callback.ValidateProperty = null, // added in v2
            notification: ?*const callback.Notification2 = null, // signature changed in v2
            to_string: ?*const callback.ToString = null,
            reference: ?*const callback.Reference = null,
            unreference: ?*const callback.Unreference = null,
            create_instance: *const callback.CreateInstance,
            free_instance: *const callback.FreeInstance,
            recreate_instance: ?*const callback.RecreateInstance = null, // added in v2
            get_virtual: ?*const callback.GetVirtual = null,
            get_virtual_call_data: ?*const callback.GetVirtualCallData = null, // added in v2
            call_virtual_with_data: ?*const callback.CallVirtualWithData = null, // added in v2
            get_rid: ?*const callback.GetRID = null,
            class_userdata: if (Userdata == void) void else *Userdata = if (Userdata == void) {} else undefined,
        }
    else if (@hasDecl(c, "GDExtensionClassCreationInfo"))
        struct {
            pub const callback = cb;

            is_virtual: bool = false,
            is_abstract: bool = false,
            set: ?*const callback.Set = null,
            get: ?*const callback.Get = null,
            get_property_list: ?*const callback.GetPropertyList = null,
            free_property_list: ?*const callback.FreePropertyList = null,
            property_can_revert: ?*const callback.PropertyCanRevert = null,
            property_get_revert: ?*const callback.PropertyGetRevert = null,
            notification: ?*const callback.Notification = null,
            to_string: ?*const callback.ToString = null,
            reference: ?*const callback.Reference = null,
            unreference: ?*const callback.Unreference = null,
            create_instance: *const callback.CreateInstance,
            free_instance: *const callback.FreeInstance,
            get_virtual: ?*const callback.GetVirtual = null,
            get_rid: ?*const callback.GetRID = null,
            class_userdata: if (Userdata == void) void else *Userdata = if (Userdata == void) {} else undefined,
        }
    else
        @compileError("Godot version 4.1 or higher is required.");
}

pub const PropertyInfo = extern struct {
    type: Variant.Tag = .nil,
    name: ?*StringName = null,
    class_name: ?*StringName = null,
    hint: PropertyHint = .property_hint_none,
    hint_string: ?*String = null,
    usage: PropertyUsageFlags = .property_usage_default,
};

const godot = @import("../gdzig.zig");
const c = godot.c;
const PropertyHint = godot.global.PropertyHint;
const PropertyUsageFlags = godot.global.PropertyUsageFlags;
const Object = godot.class.Object;
const String = godot.builtin.String;
const StringName = godot.builtin.StringName;
const Variant = godot.builtin.Variant;
const fn_binding = @import("../util/fn_binding.zig");
