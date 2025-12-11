//
// Class Info
//

pub fn ClassInfo1(comptime Userdata: type) type {
    return if (Userdata != void)
        struct {
            userdata: *Userdata,
            is_virtual: bool = false,
            is_abstract: bool = false,
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
            userdata: *Userdata,
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
            userdata: *Userdata,
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

/// Takes ownership of icon_path; requires deinit
pub fn ClassInfo4(comptime Userdata: type) type {
    return if (Userdata != void)
        struct {
            userdata: *Userdata,
            is_virtual: bool = false,
            is_abstract: bool = false,
            is_exposed: bool = true,
            is_runtime: bool = false,
            icon_path: ?*const String = null,

            pub fn deinit(self: *@This()) void {
                self.icon_path.deinit();
                self.* = undefined;
            }
        }
    else
        struct {
            is_virtual: bool = false,
            is_abstract: bool = false,
            is_exposed: bool = true,
            is_runtime: bool = false,
            icon_path: ?*const String = null,

            pub fn deinit(self: *@This()) void {
                self.icon_path.deinit();
                self.* = undefined;
            }
        };
}

//
// Class Callbacks
//

pub fn ClassCallbacks1(comptime T: type, comptime ClassUserdata: type) type {
    return struct {
        create: Create(T, ClassUserdata),
        destroy: Free(T, ClassUserdata),

        get_virtual: ?GetVirtual(T, ClassUserdata) = null,

        set: ?Set(T) = null,
        get: ?Get(T) = null,
        get_property_list: ?GetPropertyList(T) = null,
        destroy_property_list: ?DestroyPropertyList(T) = null,
        property_can_revert: ?PropertyCanRevert(T) = null,
        property_get_revert: ?PropertyGetRevert(T) = null,
        notification: ?Notification1(T) = null,
        to_string: ?ToString(T) = null,
        reference: ?Reference(T) = null,
        unreference: ?Unreference(T) = null,
        get_rid: ?GetRID(T) = null,
    };
}

pub fn ClassCallbacks2(comptime T: type, comptime ClassUserdata: type, comptime VirtualCallUserdata: type) type {
    return struct {
        create: Create(T, ClassUserdata),
        destroy: Free(T, ClassUserdata),
        recreate: ?Recreate(T, ClassUserdata) = null,

        get_virtual: ?GetVirtual(T, ClassUserdata) = null,
        get_virtual_call_data: ?GetVirtualCallData(ClassUserdata, VirtualCallUserdata) = null,
        call_virtual_with_data: ?CallVirtualWithData(T, VirtualCallUserdata) = null,

        set: ?Set(T) = null,
        get: ?Get(T) = null,
        get_property_list: ?GetPropertyList(T) = null,
        destroy_property_list: ?DestroyPropertyList(T) = null,
        property_can_revert: ?PropertyCanRevert(T) = null,
        property_get_revert: ?PropertyGetRevert(T) = null,
        validate_property: ?ValidateProperty(T) = null,
        notification: ?Notification2(T) = null,
        to_string: ?ToString(T) = null,
        reference: ?Reference(T) = null,
        unreference: ?Unreference(T) = null,
        get_rid: ?GetRID(T) = null,
    };
}

pub fn ClassCallbacks3(comptime T: type, comptime ClassUserdata: type, comptime VirtualCallUserdata: type) type {
    return struct {
        create: Create(T, ClassUserdata),
        destroy: Free(T, ClassUserdata),
        recreate: ?Recreate(T, ClassUserdata) = null,

        get_virtual: ?GetVirtual(T, ClassUserdata) = null,
        get_virtual_call_data: ?GetVirtualCallData(ClassUserdata, VirtualCallUserdata) = null,
        call_virtual_with_data: ?CallVirtualWithData(T, VirtualCallUserdata) = null,

        set: ?Set(T) = null,
        get: ?Get(T) = null,
        get_property_list: ?GetPropertyList(T) = null,
        destroy_property_list: ?DestroyPropertyList2(T) = null,
        property_can_revert: ?PropertyCanRevert(T) = null,
        property_get_revert: ?PropertyGetRevert(T) = null,
        validate_property: ?ValidateProperty(T) = null,
        notification: ?Notification2(T) = null,
        to_string: ?ToString(T) = null,
        reference: ?Reference(T) = null,
        unreference: ?Unreference(T) = null,
        get_rid: ?GetRID(T) = null,
    };
}

pub fn ClassCallbacks4(comptime T: type, comptime ClassUserdata: type, comptime VirtualCallUserdata: type) type {
    return struct {
        create: Create2(T, ClassUserdata),
        destroy: Free(T, ClassUserdata),
        recreate: ?Recreate(T, ClassUserdata) = null,

        get_virtual: ?GetVirtual2(T, ClassUserdata) = null,
        get_virtual_call_data: ?GetVirtualCallData2(ClassUserdata, VirtualCallUserdata) = null,
        call_virtual_with_data: ?CallVirtualWithData(T, VirtualCallUserdata) = null,

        set: ?Set(T) = null,
        get: ?Get(T) = null,
        get_property_list: ?GetPropertyList(T) = null,
        destroy_property_list: ?DestroyPropertyList2(T) = null,
        property_can_revert: ?PropertyCanRevert(T) = null,
        property_get_revert: ?PropertyGetRevert(T) = null,
        validate_property: ?ValidateProperty(T) = null,
        notification: ?Notification2(T) = null,
        to_string: ?ToString(T) = null,
        reference: ?Reference(T) = null,
        unreference: ?Unreference(T) = null,
    };
}

//
// Instance Lifecycle Callbacks
//

pub fn Create(comptime T: type, comptime ClassUserdata: type) type {
    return if (ClassUserdata != void)
        fn (userdata: *ClassUserdata) *T
    else
        fn () *T;
}

fn wrapCreate(comptime T: type, comptime ClassUserdata: type, comptime callback: Create(T, ClassUserdata)) Child(c.GDExtensionClassCreateInstance) {
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
    return if (ClassUserdata != void)
        fn (userdata: *ClassUserdata, notify_postinitialize: bool) *T
    else
        fn (notify_postinitialize: bool) *T;
}

fn wrapCreate2(comptime T: type, comptime ClassUserdata: type, comptime callback: Create2(T, ClassUserdata)) Child(c.GDExtensionClassCreateInstance2) {
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
    return if (ClassUserdata != void)
        fn (userdata: *ClassUserdata, instance: *T) void
    else
        fn (instance: *T) void;
}

fn wrapFree(comptime T: type, comptime ClassUserdata: type, comptime callback: Free(T, ClassUserdata)) Child(c.GDExtensionClassFreeInstance) {
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
    return if (ClassUserdata != void)
        fn (userdata: *ClassUserdata, obj: *Object) *T
    else
        fn (obj: *Object) *T;
}

fn wrapRecreate(comptime T: type, comptime ClassUserdata: type, comptime callback: Recreate(T, ClassUserdata)) Child(c.GDExtensionClassRecreateInstance) {
    return struct {
        fn wrapped(p_class_userdata: ?*anyopaque, p_object: c.GDExtensionObjectPtr) callconv(.c) c.GDExtensionClassInstancePtr {
            const obj = @as(*Object, @ptrCast(@alignCast(p_object)));
            if (ClassUserdata != void) {
                const userdata = @as(*ClassUserdata, @ptrCast(@alignCast(p_class_userdata)));
                const instance = callback(userdata, obj);
                return @ptrCast(instance);
            } else {
                const instance = callback(obj);
                return @ptrCast(instance);
            }
        }
    }.wrapped;
}

//
// Property Callbacks
//

pub fn Set(comptime T: type) type {
    return fn (self: *T, name: *const StringName, value: *const Variant) PropertyError!void;
}

fn wrapSet(comptime T: type, comptime callback: Set(T)) Child(c.GDExtensionClassSet) {
    return struct {
        fn wrapped(p_instance: c.GDExtensionClassInstancePtr, p_name: c.GDExtensionConstStringNamePtr, p_value: c.GDExtensionConstVariantPtr) callconv(.c) c.GDExtensionBool {
            const instance = @as(*T, @ptrCast(@alignCast(p_instance)));
            const name = @as(*const StringName, @ptrCast(p_name));
            const value = @as(*const Variant, @ptrCast(@alignCast(p_value)));
            callback(instance, name, value) catch return 0;
            return 1;
        }
    }.wrapped;
}

pub fn Get(comptime T: type) type {
    return fn (self: *T, name: *const StringName) PropertyError!Variant;
}

fn wrapGet(comptime T: type, comptime callback: Get(T)) Child(c.GDExtensionClassGet) {
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

pub fn GetPropertyList(comptime T: type) type {
    return fn (self: *T) Allocator.Error![]const PropertyInfo;
}

fn wrapGetPropertyList(comptime T: type, comptime callback: GetPropertyList(T)) Child(c.GDExtensionClassGetPropertyList) {
    return struct {
        fn wrapped(p_instance: c.GDExtensionClassInstancePtr, r_count: [*c]u32) callconv(.c) [*c]const c.GDExtensionPropertyInfo {
            const instance = @as(*T, @ptrCast(@alignCast(p_instance)));
            const list = callback(instance) catch {
                if (r_count) |cnt| cnt.* = 0;
                return null;
            };
            if (r_count) |cnt| cnt.* = @intCast(list.len);
            if (list.len == 0) return null;
            return @ptrCast(list.ptr);
        }
    }.wrapped;
}

pub fn DestroyPropertyList(comptime T: type) type {
    return fn (self: *T, list: [*]const PropertyInfo) void;
}

fn wrapDestroyPropertyList(comptime T: type, comptime callback: DestroyPropertyList(T)) Child(c.GDExtensionClassFreePropertyList) {
    return struct {
        fn wrapped(p_instance: c.GDExtensionClassInstancePtr, p_list: ?*const c.GDExtensionPropertyInfo) callconv(.c) void {
            const instance = @as(*T, @ptrCast(@alignCast(p_instance)));
            if (p_list) |list| {
                callback(instance, @ptrCast(list));
            }
        }
    }.wrapped;
}

pub fn DestroyPropertyList2(comptime T: type) type {
    return fn (self: *T, list: []const PropertyInfo) void;
}

fn wrapDestroyPropertyList2(comptime T: type, comptime callback: DestroyPropertyList2(T)) Child(c.GDExtensionClassFreePropertyList2) {
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

fn wrapPropertyCanRevert(comptime T: type, comptime callback: PropertyCanRevert(T)) Child(c.GDExtensionClassPropertyCanRevert) {
    return struct {
        fn wrapped(p_instance: c.GDExtensionClassInstancePtr, p_name: c.GDExtensionConstStringNamePtr) callconv(.c) c.GDExtensionBool {
            const instance = @as(*T, @ptrCast(@alignCast(p_instance)));
            const name = @as(*const StringName, @ptrCast(p_name));
            return if (callback(instance, name)) 1 else 0;
        }
    }.wrapped;
}

pub fn PropertyGetRevert(comptime T: type) type {
    return fn (self: *T, name: *const StringName) PropertyError!Variant;
}

fn wrapPropertyGetRevert(comptime T: type, comptime callback: PropertyGetRevert(T)) Child(c.GDExtensionClassPropertyGetRevert) {
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

fn wrapValidateProperty(comptime T: type, comptime callback: ValidateProperty(T)) Child(c.GDExtensionClassValidateProperty) {
    return struct {
        fn wrapped(p_instance: c.GDExtensionClassInstancePtr, p_property: *c.GDExtensionPropertyInfo) callconv(.c) c.GDExtensionBool {
            const instance = @as(*T, @ptrCast(@alignCast(p_instance)));
            const property = @as(*PropertyInfo, @ptrCast(p_property));
            return if (callback(instance, property)) 1 else 0;
        }
    }.wrapped;
}

//
// Notification & ToString Callbacks
//

pub fn Notification1(comptime T: type) type {
    return fn (self: *T, what: i32) void;
}

fn wrapNotification1(comptime T: type, comptime callback: Notification1(T)) Child(c.GDExtensionClassNotification) {
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

fn wrapNotification(comptime T: type, comptime callback: Notification2(T)) Child(c.GDExtensionClassNotification2) {
    return struct {
        fn wrapped(p_instance: c.GDExtensionClassInstancePtr, p_what: i32, p_reversed: c.GDExtensionBool) callconv(.c) void {
            const instance = @as(*T, @ptrCast(@alignCast(p_instance)));
            callback(instance, p_what, p_reversed != 0);
        }
    }.wrapped;
}

pub fn ToString(comptime T: type) type {
    return fn (self: *T) ?String;
}

fn wrapToString(comptime T: type, comptime callback: ToString(T)) Child(c.GDExtensionClassToString) {
    return struct {
        fn wrapped(p_instance: c.GDExtensionClassInstancePtr, r_is_valid: [*c]c.GDExtensionBool, p_out: c.GDExtensionStringPtr) callconv(.c) void {
            const instance = @as(*T, @ptrCast(@alignCast(p_instance)));
            const out = @as(*String, @ptrCast(@alignCast(p_out)));
            out.* = callback(instance) orelse {
                if (r_is_valid) |v| v.* = 0;
                return;
            };
            if (r_is_valid) |v| v.* = 1;
        }
    }.wrapped;
}

//
// Reference Counting Callbacks
//

pub fn Reference(comptime T: type) type {
    return fn (self: *T) void;
}

fn wrapReference(comptime T: type, comptime callback: Reference(T)) Child(c.GDExtensionClassReference) {
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

fn wrapUnreference(comptime T: type, comptime callback: Unreference(T)) Child(c.GDExtensionClassUnreference) {
    return struct {
        fn wrapped(p_instance: c.GDExtensionClassInstancePtr) callconv(.c) void {
            const instance = @as(*T, @ptrCast(@alignCast(p_instance)));
            callback(instance);
        }
    }.wrapped;
}

pub fn GetRID(comptime T: type) type {
    return fn (self: *T) RID;
}

fn wrapGetRID(comptime T: type, comptime callback: GetRID(T)) Child(c.GDExtensionClassGetRID) {
    return struct {
        fn wrapped(p_instance: c.GDExtensionClassInstancePtr) callconv(.c) u64 {
            const instance = @as(*T, @ptrCast(@alignCast(p_instance)));
            const rid = callback(instance);
            return @bitCast(rid);
        }
    }.wrapped;
}

//
// Virtual Method Callbacks
//

pub fn CallVirtual(comptime T: type) type {
    return fn (self: *T, args: [*]const *const anyopaque, ret: *anyopaque) void;
}

fn wrapCallVirtual(comptime T: type, comptime callback: CallVirtual(T)) Child(c.GDExtensionClassCallVirtual) {
    return struct {
        fn wrapped(p_instance: c.GDExtensionClassInstancePtr, p_args: [*c]const c.GDExtensionConstTypePtr, r_ret: c.GDExtensionTypePtr) callconv(.c) void {
            const instance = @as(*T, @ptrCast(@alignCast(p_instance)));
            callback(instance, @ptrCast(p_args), @ptrCast(r_ret));
        }
    }.wrapped;
}

pub fn GetVirtual(comptime T: type, comptime ClassUserdata: type) type {
    return if (ClassUserdata != void)
        fn (userdata: *ClassUserdata, name: *const StringName) ?*const CallVirtual(T)
    else
        fn (name: *const StringName) ?*const CallVirtual(T);
}

fn wrapGetVirtual(comptime T: type, comptime ClassUserdata: type, comptime callback: GetVirtual(T, ClassUserdata)) Child(c.GDExtensionClassGetVirtual) {
    return struct {
        fn wrapped(p_class_userdata: ?*anyopaque, p_name: c.GDExtensionConstStringNamePtr) callconv(.c) c.GDExtensionClassCallVirtual {
            const name = @as(*const StringName, @ptrCast(p_name));
            const virtual: ?*const CallVirtual(T) = if (ClassUserdata != void) blk: {
                const userdata = @as(*ClassUserdata, @ptrCast(@alignCast(p_class_userdata)));
                break :blk callback(userdata, name);
            } else callback(name);

            if (virtual) |v| {
                return @ptrCast(v);
            }
            return null;
        }
    }.wrapped;
}

pub fn GetVirtual2(comptime T: type, comptime ClassUserdata: type) type {
    return if (ClassUserdata != void)
        fn (userdata: *ClassUserdata, name: *const StringName, hash: u32) ?*const CallVirtual(T)
    else
        fn (name: *const StringName, hash: u32) ?*const CallVirtual(T);
}

fn wrapGetVirtual2(comptime T: type, comptime ClassUserdata: type, comptime callback: GetVirtual2(T, ClassUserdata)) Child(c.GDExtensionClassGetVirtual2) {
    return struct {
        fn wrapped(p_class_userdata: ?*anyopaque, p_name: c.GDExtensionConstStringNamePtr, p_hash: u32) callconv(.c) c.GDExtensionClassCallVirtual {
            const name = @as(*const StringName, @ptrCast(p_name));
            const virtual: ?*const CallVirtual(T) = if (ClassUserdata != void) blk: {
                const userdata = @as(*ClassUserdata, @ptrCast(@alignCast(p_class_userdata)));
                break :blk callback(userdata, name, p_hash);
            } else callback(name, p_hash);

            if (virtual) |v| {
                return @ptrCast(v);
            }
            return null;
        }
    }.wrapped;
}

pub fn GetVirtualCallData(comptime ClassUserdata: type, comptime VirtualCallUserdata: type) type {
    return if (ClassUserdata != void)
        fn (userdata: *ClassUserdata, name: *const StringName) ?*VirtualCallUserdata
    else
        fn (name: *const StringName) ?*VirtualCallUserdata;
}

fn wrapGetVirtualCallData(comptime ClassUserdata: type, comptime VirtualCallUserdata: type, comptime callback: GetVirtualCallData(ClassUserdata, VirtualCallUserdata)) Child(c.GDExtensionClassGetVirtualCallData) {
    return struct {
        fn wrapped(p_class_userdata: ?*anyopaque, p_name: c.GDExtensionConstStringNamePtr) callconv(.c) ?*anyopaque {
            const name = @as(*const StringName, @ptrCast(p_name));
            if (ClassUserdata != void) {
                const userdata = @as(*ClassUserdata, @ptrCast(@alignCast(p_class_userdata)));
                return @ptrCast(callback(userdata, name));
            } else {
                return @ptrCast(callback(name));
            }
        }
    }.wrapped;
}

pub fn GetVirtualCallData2(comptime ClassUserdata: type, comptime VirtualCallUserdata: type) type {
    return if (ClassUserdata != void)
        fn (userdata: *ClassUserdata, name: *const StringName, hash: u32) ?*VirtualCallUserdata
    else
        fn (name: *const StringName, hash: u32) ?*VirtualCallUserdata;
}

fn wrapGetVirtualCallData2(comptime ClassUserdata: type, comptime VirtualCallUserdata: type, comptime callback: GetVirtualCallData2(ClassUserdata, VirtualCallUserdata)) Child(c.GDExtensionClassGetVirtualCallData2) {
    return struct {
        fn wrapped(p_class_userdata: ?*anyopaque, p_name: c.GDExtensionConstStringNamePtr, p_hash: u32) callconv(.c) ?*anyopaque {
            const name = @as(*const StringName, @ptrCast(p_name));
            if (ClassUserdata != void) {
                const userdata = @as(*ClassUserdata, @ptrCast(@alignCast(p_class_userdata)));
                return @ptrCast(callback(userdata, name, p_hash));
            } else {
                return @ptrCast(callback(name, p_hash));
            }
        }
    }.wrapped;
}

pub fn CallVirtualWithData(comptime T: type, comptime VirtualCallUserdata: type) type {
    return if (VirtualCallUserdata != void)
        fn (instance: *T, name: *const StringName, virtual_call_userdata: *VirtualCallUserdata, args: [*]const *const anyopaque, ret: *anyopaque) void
    else
        fn (instance: *T, name: *const StringName, args: [*]const *const anyopaque, ret: *anyopaque) void;
}

fn wrapCallVirtualWithData(comptime T: type, comptime VirtualCallUserdata: type, comptime callback: CallVirtualWithData(T, VirtualCallUserdata)) Child(c.GDExtensionClassCallVirtualWithData) {
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

//
// Method Types
//

pub fn MethodInfo(comptime Userdata: type) type {
    return if (Userdata != void)
        struct {
            userdata: *Userdata,
            name: *StringName,
            flags: MethodFlags = .{},
            return_value_info: ?*PropertyInfo = null,
            return_value_metadata: MethodArgumentMetadata = .none,
            argument_info: []const PropertyInfo = &.{},
            argument_metadata: []const MethodArgumentMetadata = &.{},
            default_arguments: []const *const Variant = &.{},
        }
    else
        struct {
            name: *StringName,
            flags: MethodFlags = .{},
            return_value_info: ?*PropertyInfo = null,
            return_value_metadata: MethodArgumentMetadata = .none,
            argument_info: []const PropertyInfo = &.{},
            argument_metadata: []const MethodArgumentMetadata = &.{},
            default_arguments: []const *const Variant = &.{},
        };
}

pub fn MethodCallbacks(comptime T: type, comptime Userdata: type) type {
    return struct {
        call: ?Call(T, Userdata) = null,
        ptr_call: ?PtrCall(T, Userdata) = null,
    };
}

pub const MethodArgumentMetadata = enum(c_uint) {
    none = c.GDEXTENSION_METHOD_ARGUMENT_METADATA_NONE,
    int_is_int8 = c.GDEXTENSION_METHOD_ARGUMENT_METADATA_INT_IS_INT8,
    int_is_int16 = c.GDEXTENSION_METHOD_ARGUMENT_METADATA_INT_IS_INT16,
    int_is_int32 = c.GDEXTENSION_METHOD_ARGUMENT_METADATA_INT_IS_INT32,
    int_is_int64 = c.GDEXTENSION_METHOD_ARGUMENT_METADATA_INT_IS_INT64,
    int_is_uint8 = c.GDEXTENSION_METHOD_ARGUMENT_METADATA_INT_IS_UINT8,
    int_is_uint16 = c.GDEXTENSION_METHOD_ARGUMENT_METADATA_INT_IS_UINT16,
    int_is_uint32 = c.GDEXTENSION_METHOD_ARGUMENT_METADATA_INT_IS_UINT32,
    int_is_uint64 = c.GDEXTENSION_METHOD_ARGUMENT_METADATA_INT_IS_UINT64,
    real_is_float = c.GDEXTENSION_METHOD_ARGUMENT_METADATA_REAL_IS_FLOAT,
    real_is_double = c.GDEXTENSION_METHOD_ARGUMENT_METADATA_REAL_IS_DOUBLE,
    int_is_char16 = c.GDEXTENSION_METHOD_ARGUMENT_METADATA_INT_IS_CHAR16,
    int_is_char32 = c.GDEXTENSION_METHOD_ARGUMENT_METADATA_INT_IS_CHAR32,
};

pub fn Call(comptime T: type, comptime Userdata: type) type {
    return if (Userdata != void)
        fn (userdata: *Userdata, instance: *T, args: []const *const Variant) CallError!Variant
    else
        fn (instance: *T, args: []const *const Variant) CallError!Variant;
}

fn wrapCall(comptime T: type, comptime Userdata: type, comptime callback: Call(T, Userdata)) Child(c.GDExtensionClassMethodCall) {
    return struct {
        fn wrapped(method_userdata: ?*anyopaque, p_instance: c.GDExtensionClassInstancePtr, p_args: [*c]const c.GDExtensionConstVariantPtr, p_argument_count: c.GDExtensionInt, r_return: c.GDExtensionVariantPtr, r_error: [*c]c.GDExtensionCallError) callconv(.c) void {
            const instance = @as(*T, @ptrCast(@alignCast(p_instance)));
            const args = @as([*]const *const Variant, @ptrCast(p_args))[0..@intCast(p_argument_count)];
            const ret = @as(*Variant, @ptrCast(@alignCast(r_return)));

            if (Userdata != void) {
                const userdata = @as(*Userdata, @ptrCast(@alignCast(method_userdata)));
                ret.* = callback(userdata, instance, args) catch |err| {
                    if (r_error) |e| e.* = @bitCast(CallResult.fromError(err));
                    return;
                };
            } else {
                ret.* = callback(instance, args) catch |err| {
                    if (r_error) |e| e.* = @bitCast(CallResult.fromError(err));
                    return;
                };
            }
            if (r_error) |e| e.*.@"error" = c.GDEXTENSION_CALL_OK;
        }
    }.wrapped;
}

pub fn PtrCall(comptime T: type, comptime Userdata: type) type {
    return if (Userdata != void)
        fn (userdata: *Userdata, instance: *T, args: [*]const *const anyopaque, ret: *anyopaque) void
    else
        fn (instance: *T, args: [*]const *const anyopaque, ret: *anyopaque) void;
}

fn wrapPtrCall(comptime T: type, comptime Userdata: type, comptime callback: PtrCall(T, Userdata)) Child(c.GDExtensionClassMethodPtrCall) {
    return struct {
        fn wrapped(method_userdata: ?*anyopaque, p_instance: c.GDExtensionClassInstancePtr, p_args: [*c]const c.GDExtensionConstTypePtr, r_ret: c.GDExtensionTypePtr) callconv(.c) void {
            const instance = @as(*T, @ptrCast(@alignCast(p_instance)));

            if (Userdata != void) {
                const userdata = @as(*Userdata, @ptrCast(@alignCast(method_userdata)));
                callback(userdata, instance, @ptrCast(p_args), @ptrCast(r_ret));
            } else {
                callback(instance, @ptrCast(p_args), @ptrCast(r_ret));
            }
        }
    }.wrapped;
}

//
// Call Result
//

pub const CallResult = extern struct {
    @"error": Status = .ok,
    argument: i32 = 0,
    expected: i32 = 0,

    pub const Status = enum(c_uint) {
        ok = c.GDEXTENSION_CALL_OK,
        invalid_method = c.GDEXTENSION_CALL_ERROR_INVALID_METHOD,
        invalid_argument = c.GDEXTENSION_CALL_ERROR_INVALID_ARGUMENT,
        too_many_arguments = c.GDEXTENSION_CALL_ERROR_TOO_MANY_ARGUMENTS,
        too_few_arguments = c.GDEXTENSION_CALL_ERROR_TOO_FEW_ARGUMENTS,
        instance_is_null = c.GDEXTENSION_CALL_ERROR_INSTANCE_IS_NULL,
        method_not_const = c.GDEXTENSION_CALL_ERROR_METHOD_NOT_CONST,
    };

    pub fn throw(self: CallResult) CallError!void {
        return switch (self.@"error") {
            .ok => {},
            .invalid_method => error.InvalidMethod,
            .invalid_argument => error.InvalidArgument,
            .too_many_arguments => error.TooManyArguments,
            .too_few_arguments => error.TooFewArguments,
            .instance_is_null => error.InstanceIsNull,
            .method_not_const => error.MethodNotConst,
        };
    }

    pub fn fromError(err: CallError) CallResult {
        return .{
            .@"error" = switch (err) {
                error.InvalidMethod => .invalid_method,
                error.InvalidArgument => .invalid_argument,
                error.TooManyArguments => .too_many_arguments,
                error.TooFewArguments => .too_few_arguments,
                error.InstanceIsNull => .instance_is_null,
                error.MethodNotConst => .method_not_const,
            },
        };
    }
};

//
// Property Info
//

pub const PropertyInfo = extern struct {
    type: Variant.Tag,
    name: ?*const StringName = null,
    class_name: ?*const StringName = null,
    hint: PropertyHint = .property_hint_none,
    hint_string: ?*const String = null,
    usage: PropertyUsageFlags = .property_usage_none,
};

//
// Registration Functions
//

/// Registers an extension class in the ClassDB.
///
/// @since 4.1
pub inline fn registerClass1(
    comptime T: type,
    comptime Userdata: type,
    class_name: *const StringName,
    base_class_name: *const StringName,
    info: ClassInfo1(Userdata),
    comptime callbacks: ClassCallbacks1(T, Userdata),
) void {
    const userdata: ?*anyopaque = if (Userdata != void) @ptrCast(info.userdata) else null;

    godot.interface.classdbRegisterExtensionClass(
        godot.interface.library,
        @ptrCast(class_name),
        @ptrCast(base_class_name),
        &c.GDExtensionClassCreationInfo{
            .is_virtual = @intFromBool(info.is_virtual),
            .is_abstract = @intFromBool(info.is_abstract),

            .create_instance_func = wrapCreate(T, Userdata, callbacks.create),
            .free_instance_func = wrapFree(T, Userdata, callbacks.destroy),
            .get_virtual_func = if (callbacks.get_virtual) |f| wrapGetVirtual(T, Userdata, f) else null,

            .set_func = if (callbacks.set) |f| wrapSet(T, f) else null,
            .get_func = if (callbacks.get) |f| wrapGet(T, f) else null,
            .get_property_list_func = if (callbacks.get_property_list) |f| wrapGetPropertyList(T, f) else null,
            .free_property_list_func = if (callbacks.destroy_property_list) |f| wrapDestroyPropertyList(T, f) else null,
            .property_can_revert_func = if (callbacks.property_can_revert) |f| wrapPropertyCanRevert(T, f) else null,
            .property_get_revert_func = if (callbacks.property_get_revert) |f| wrapPropertyGetRevert(T, f) else null,
            .notification_func = if (callbacks.notification) |f| wrapNotification1(T, f) else null,
            .to_string_func = if (callbacks.to_string) |f| wrapToString(T, f) else null,
            .reference_func = if (callbacks.reference) |f| wrapReference(T, f) else null,
            .unreference_func = if (callbacks.unreference) |f| wrapUnreference(T, f) else null,
            .get_rid_func = if (callbacks.get_rid) |f| wrapGetRID(T, f) else null,

            .class_userdata = userdata,
        },
    );
}

/// Registers an extension class in the ClassDB.
///
/// @since 4.2
pub inline fn registerClass2(
    comptime T: type,
    comptime Userdata: type,
    comptime VirtualCallData: type,
    class_name: *const StringName,
    base_class_name: *const StringName,
    info: ClassInfo2(Userdata),
    comptime callbacks: ClassCallbacks2(T, Userdata, VirtualCallData),
) void {
    const userdata: ?*anyopaque = if (Userdata != void) @ptrCast(info.userdata) else null;

    godot.interface.classdbRegisterExtensionClass2(
        godot.interface.library,
        @ptrCast(class_name),
        @ptrCast(base_class_name),
        &c.GDExtensionClassCreationInfo2{
            .is_virtual = @intFromBool(info.is_virtual),
            .is_abstract = @intFromBool(info.is_abstract),
            .is_exposed = @intFromBool(info.is_exposed),

            .create_instance_func = wrapCreate(T, Userdata, callbacks.create),
            .free_instance_func = wrapFree(T, Userdata, callbacks.destroy),
            .recreate_instance_func = if (callbacks.recreate) |f| wrapRecreate(T, Userdata, f) else null,
            .get_virtual_func = if (callbacks.get_virtual) |f| wrapGetVirtual(T, Userdata, f) else null,
            .get_virtual_call_data_func = if (callbacks.get_virtual_call_data) |f| wrapGetVirtualCallData(Userdata, VirtualCallData, f) else null,
            .call_virtual_with_data_func = if (callbacks.call_virtual_with_data) |f| wrapCallVirtualWithData(T, VirtualCallData, f) else null,

            .set_func = if (callbacks.set) |f| wrapSet(T, f) else null,
            .get_func = if (callbacks.get) |f| wrapGet(T, f) else null,
            .get_property_list_func = if (callbacks.get_property_list) |f| wrapGetPropertyList(T, f) else null,
            .free_property_list_func = if (callbacks.destroy_property_list) |f| wrapDestroyPropertyList(T, f) else null,
            .property_can_revert_func = if (callbacks.property_can_revert) |f| wrapPropertyCanRevert(T, f) else null,
            .property_get_revert_func = if (callbacks.property_get_revert) |f| wrapPropertyGetRevert(T, f) else null,
            .validate_property_func = if (callbacks.validate_property) |f| wrapValidateProperty(T, f) else null,
            .notification_func = if (callbacks.notification) |f| wrapNotification(T, f) else null,
            .to_string_func = if (callbacks.to_string) |f| wrapToString(T, f) else null,
            .reference_func = if (callbacks.reference) |f| wrapReference(T, f) else null,
            .unreference_func = if (callbacks.unreference) |f| wrapUnreference(T, f) else null,
            .get_rid_func = if (callbacks.get_rid) |f| wrapGetRID(T, f) else null,

            .class_userdata = userdata,
        },
    );
}

/// Registers an extension class in the ClassDB.
///
/// @since 4.3
pub inline fn registerClass3(
    comptime T: type,
    comptime Userdata: type,
    comptime VirtualCallData: type,
    class_name: *const StringName,
    base_class_name: *const StringName,
    info: ClassInfo3(Userdata),
    comptime callbacks: ClassCallbacks3(T, Userdata, VirtualCallData),
) void {
    const userdata: ?*anyopaque = if (Userdata != void) @ptrCast(info.userdata) else null;

    godot.interface.classdbRegisterExtensionClass3(
        godot.interface.library,
        @ptrCast(class_name),
        @ptrCast(base_class_name),
        &c.GDExtensionClassCreationInfo3{
            .is_virtual = @intFromBool(info.is_virtual),
            .is_abstract = @intFromBool(info.is_abstract),
            .is_exposed = @intFromBool(info.is_exposed),
            .is_runtime = @intFromBool(info.is_runtime),

            .create_instance_func = wrapCreate(T, Userdata, callbacks.create),
            .free_instance_func = wrapFree(T, Userdata, callbacks.destroy),
            .recreate_instance_func = if (callbacks.recreate) |f| wrapRecreate(T, Userdata, f) else null,
            .get_virtual_func = if (callbacks.get_virtual) |f| wrapGetVirtual(T, Userdata, f) else null,
            .get_virtual_call_data_func = if (callbacks.get_virtual_call_data) |f| wrapGetVirtualCallData(Userdata, VirtualCallData, f) else null,
            .call_virtual_with_data_func = if (callbacks.call_virtual_with_data) |f| wrapCallVirtualWithData(T, VirtualCallData, f) else null,

            .set_func = if (callbacks.set) |f| wrapSet(T, f) else null,
            .get_func = if (callbacks.get) |f| wrapGet(T, f) else null,
            .get_property_list_func = if (callbacks.get_property_list) |f| wrapGetPropertyList(T, f) else null,
            .free_property_list_func = if (callbacks.destroy_property_list) |f| wrapDestroyPropertyList2(T, f) else null,
            .property_can_revert_func = if (callbacks.property_can_revert) |f| wrapPropertyCanRevert(T, f) else null,
            .property_get_revert_func = if (callbacks.property_get_revert) |f| wrapPropertyGetRevert(T, f) else null,
            .validate_property_func = if (callbacks.validate_property) |f| wrapValidateProperty(T, f) else null,
            .notification_func = if (callbacks.notification) |f| wrapNotification(T, f) else null,
            .to_string_func = if (callbacks.to_string) |f| wrapToString(T, f) else null,
            .reference_func = if (callbacks.reference) |f| wrapReference(T, f) else null,
            .unreference_func = if (callbacks.unreference) |f| wrapUnreference(T, f) else null,
            .get_rid_func = if (callbacks.get_rid) |f| wrapGetRID(T, f) else null,

            .class_userdata = userdata,
        },
    );
}

/// Registers an extension class in the ClassDB.
///
/// @since 4.4
pub inline fn registerClass4(
    comptime T: type,
    comptime Userdata: type,
    comptime VirtualCallData: type,
    class_name: *const StringName,
    base_class_name: *const StringName,
    info: ClassInfo4(Userdata),
    comptime callbacks: ClassCallbacks4(T, Userdata, VirtualCallData),
) void {
    const userdata: ?*anyopaque = if (Userdata != void) @ptrCast(info.userdata) else null;

    godot.interface.classdbRegisterExtensionClass4(
        godot.interface.library,
        @ptrCast(class_name),
        @ptrCast(base_class_name),
        &c.GDExtensionClassCreationInfo4{
            .is_virtual = @intFromBool(info.is_virtual),
            .is_abstract = @intFromBool(info.is_abstract),
            .is_exposed = @intFromBool(info.is_exposed),
            .is_runtime = @intFromBool(info.is_runtime),
            .icon_path = @ptrCast(info.icon_path),

            .create_instance_func = wrapCreate2(T, Userdata, callbacks.create),
            .free_instance_func = wrapFree(T, Userdata, callbacks.destroy),
            .recreate_instance_func = if (callbacks.recreate) |f| wrapRecreate(T, Userdata, f) else null,
            .get_virtual_func = if (callbacks.get_virtual) |f| wrapGetVirtual2(T, Userdata, f) else null,
            .get_virtual_call_data_func = if (callbacks.get_virtual_call_data) |f| wrapGetVirtualCallData2(Userdata, VirtualCallData, f) else null,
            .call_virtual_with_data_func = if (callbacks.call_virtual_with_data) |f| wrapCallVirtualWithData(T, VirtualCallData, f) else null,

            .set_func = if (callbacks.set) |f| wrapSet(T, f) else null,
            .get_func = if (callbacks.get) |f| wrapGet(T, f) else null,
            .get_property_list_func = if (callbacks.get_property_list) |f| wrapGetPropertyList(T, f) else null,
            .free_property_list_func = if (callbacks.destroy_property_list) |f| wrapDestroyPropertyList2(T, f) else null,
            .property_can_revert_func = if (callbacks.property_can_revert) |f| wrapPropertyCanRevert(T, f) else null,
            .property_get_revert_func = if (callbacks.property_get_revert) |f| wrapPropertyGetRevert(T, f) else null,
            .validate_property_func = if (callbacks.validate_property) |f| wrapValidateProperty(T, f) else null,
            .notification_func = if (callbacks.notification) |f| wrapNotification(T, f) else null,
            .to_string_func = if (callbacks.to_string) |f| wrapToString(T, f) else null,
            .reference_func = if (callbacks.reference) |f| wrapReference(T, f) else null,
            .unreference_func = if (callbacks.unreference) |f| wrapUnreference(T, f) else null,

            .class_userdata = userdata,
        },
    );
}

/// Registers a method on an extension class in the ClassDB.
///
/// @since 4.1
pub inline fn registerMethod(
    comptime T: type,
    comptime Userdata: type,
    class_name: *const StringName,
    info: MethodInfo(Userdata),
    comptime callbacks: MethodCallbacks(T, Userdata),
) void {
    const userdata: ?*anyopaque = if (Userdata != void) @ptrCast(info.userdata) else null;

    godot.interface.classdbRegisterExtensionClassMethod(
        godot.interface.library,
        @ptrCast(class_name),
        &c.GDExtensionClassMethodInfo{
            .name = @ptrCast(info.name),
            .method_userdata = userdata,
            .call_func = if (callbacks.call) |f| wrapCall(T, Userdata, f) else null,
            .ptrcall_func = if (callbacks.ptr_call) |f| wrapPtrCall(T, Userdata, f) else null,
            .method_flags = @bitCast(info.flags),
            .has_return_value = @intFromBool(info.return_value_info != null),
            .return_value_info = @ptrCast(info.return_value_info),
            .return_value_metadata = @intFromEnum(info.return_value_metadata),
            .argument_count = @intCast(info.argument_info.len),
            .arguments_info = @ptrCast(@constCast(info.argument_info.ptr)),
            .arguments_metadata = @ptrCast(@constCast(info.argument_metadata.ptr)),
            .default_argument_count = @intCast(info.default_arguments.len),
            .default_arguments = @ptrCast(@constCast(info.default_arguments.ptr)),
        },
    );
}

/// Registers a signal on an extension class in the ClassDB.
///
/// @since 4.1
pub inline fn registerSignal(class_name: *const StringName, signal_name: *const StringName, argument_info: []const PropertyInfo) void {
    godot.interface.classdbRegisterExtensionClassSignal(
        godot.interface.library,
        @ptrCast(class_name),
        @ptrCast(signal_name),
        @ptrCast(argument_info.ptr),
        @intCast(argument_info.len),
    );
}

/// Registers a property on an extension class in the ClassDB.
///
/// @since 4.1
pub inline fn registerProperty(class_name: *const StringName, info: *const PropertyInfo, setter: *const StringName, getter: *const StringName) void {
    godot.interface.classdbRegisterExtensionClassProperty(
        godot.interface.library,
        @ptrCast(class_name),
        @ptrCast(info),
        @ptrCast(setter),
        @ptrCast(getter),
    );
}

/// Registers an indexed property on an extension class in the ClassDB.
///
/// @since 4.2
pub inline fn registerPropertyIndexed(class_name: *const StringName, info: *const PropertyInfo, setter: *const StringName, getter: *const StringName, index: i64) void {
    godot.interface.classdbRegisterExtensionClassPropertyIndexed(
        godot.interface.library,
        @ptrCast(class_name),
        @ptrCast(info),
        @ptrCast(setter),
        @ptrCast(getter),
        index,
    );
}

/// Registers a property group on an extension class in the ClassDB.
///
/// @since 4.1
pub inline fn registerPropertyGroup(class_name: *const StringName, group_name: *const String, prefix: *const String) void {
    godot.interface.classdbRegisterExtensionClassPropertyGroup(
        godot.interface.library,
        @ptrCast(class_name),
        @ptrCast(group_name),
        @ptrCast(prefix),
    );
}

/// Registers a property subgroup on an extension class in the ClassDB.
///
/// @since 4.1
pub inline fn registerPropertySubgroup(class_name: *const StringName, subgroup_name: *const String, prefix: *const String) void {
    godot.interface.classdbRegisterExtensionClassPropertySubgroup(
        godot.interface.library,
        @ptrCast(class_name),
        @ptrCast(subgroup_name),
        @ptrCast(prefix),
    );
}

/// Registers an integer constant on an extension class in the ClassDB.
///
/// @since 4.1
pub inline fn registerIntegerConstant(class_name: *const StringName, enum_name: *const StringName, constant_name: *const StringName, constant_value: i64, is_bitfield: bool) void {
    godot.interface.classdbRegisterExtensionClassIntegerConstant(
        godot.interface.library,
        @ptrCast(class_name),
        @ptrCast(enum_name),
        @ptrCast(constant_name),
        constant_value,
        @intFromBool(is_bitfield),
    );
}

/// Virtual method info for registration.
pub const VirtualMethodInfo = struct {
    name: *const StringName,
    flags: MethodFlags = .{},
    return_value: PropertyInfo,
    return_value_metadata: MethodArgumentMetadata = .none,
    arguments: []const PropertyInfo = &.{},
    arguments_metadata: []const MethodArgumentMetadata = &.{},
};

/// Registers a virtual method on an extension class in the ClassDB.
/// This allows scripts or other extensions to implement the method.
///
/// @since 4.3
pub inline fn registerVirtualMethod(class_name: *const StringName, info: VirtualMethodInfo) void {
    godot.interface.classdbRegisterExtensionClassVirtualMethod(
        godot.interface.library,
        @ptrCast(class_name),
        &c.GDExtensionClassVirtualMethodInfo{
            .name = @ptrCast(info.name),
            .method_flags = @bitCast(info.flags),
            .return_value = @bitCast(info.return_value),
            .return_value_metadata = @intFromEnum(info.return_value_metadata),
            .argument_count = @intCast(info.arguments.len),
            .arguments = @ptrCast(info.arguments.ptr),
            .arguments_metadata = @ptrCast(info.arguments_metadata.ptr),
        },
    );
}

/// Unregisters an extension class in the ClassDB.
///
/// @since 4.1
pub inline fn unregisterExtensionClass(class_name: *const StringName) void {
    godot.interface.classdbUnregisterExtensionClass(
        godot.interface.library,
        @ptrCast(class_name),
    );
}

//
// Tests
//

test {
    std.testing.refAllDecls(@This());
}

//
// Imports
//

const std = @import("std");
const Allocator = std.mem.Allocator;
const Child = std.meta.Child;

const c = @import("gdextension");

const godot = @import("gdzig.zig");
const CallError = godot.CallError;
const MethodFlags = global.MethodFlags;
const Object = godot.class.Object;
const PropertyError = godot.PropertyError;
const PropertyHint = global.PropertyHint;
const PropertyUsageFlags = global.PropertyUsageFlags;
const RID = builtin.RID;
const String = builtin.String;
const StringName = builtin.StringName;
const Variant = builtin.Variant;
const builtin = godot.builtin;
const global = godot.global;
