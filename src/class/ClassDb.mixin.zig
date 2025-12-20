// # Maintenance Guide
//
// When a new Godot version adds `GDExtensionClassCreationInfoN`, you'll need to:
//
// 1. Check `gdextension_interface.h` (or `gdextension_interface.zig`) for the new struct
// 2. Add `ClassInfoN` with any new fields (e.g., 4.2 added `is_exposed`, 4.3 added `is_runtime`)
// 3. Add `ClassCallbacksN` referencing the appropriate callback types
// 4. Add `registerClassN` that builds the C struct and calls the raw function
// 5. If new callback types were added, create the Zig type and `wrap*` function
//
// Follow similar conventions for the other types.
//
// ## Wrapping Conventions
//
// When mapping C callbacks to idiomatic Zig:
//
// - `?*anyopaque` userdata -> `*Userdata` (or omit param if `Userdata == void`)
// - `GDExtensionClassInstancePtr` -> `*T`
// - `GDExtensionConstVariantPtr` -> `*const Variant`
// - `GDExtensionVariantPtr` -> `*Variant`
// - `GDExtensionBool` -> `bool`
// - C ptr + count in-params -> Zig slice (`[]const T`)
//
// Return values require special care:
//
// - C success bool (0/1) <- Zig error union (return error = failure)
// - C out-param + validity flag <- Zig optional (`?T`)
// - C ptr + count out-params <- Zig slice (`[]const T`)
//
// ## Annotations
//
//  - `@ref`: The GDExtension C type this Zig type wraps
//  - `@since`: Godot version that introduced this type/callback
//
// ## Notes
//
// These are low level wrappers. Do not use any runtime version checking or "magic"; that belongs in
// a higher level abstraction like the registration helpers.
//

// @mixin start

//
// Class Info
//

// @ref GDExtensionClassCreationInfo (no callbacks)
// @since 4.1
pub fn ClassInfo1(comptime Userdata: type) type {
    return if (Userdata != void)
        struct {
            userdata: Userdata,
            is_virtual: bool = false,
            is_abstract: bool = false,
        }
    else
        struct {
            is_virtual: bool = false,
            is_abstract: bool = false,
        };
}

// @ref GDExtensionClassCreationInfo2 (no callbacks)
// @since 4.2 (adds is_exposed)
pub fn ClassInfo2(comptime Userdata: type) type {
    return if (Userdata != void)
        struct {
            userdata: Userdata,
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

// @ref GDExtensionClassCreationInfo3 (no callbacks)
// @since 4.3 (adds is_runtime)
pub fn ClassInfo3(comptime Userdata: type) type {
    return if (Userdata != void)
        struct {
            userdata: Userdata,
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

// @ref GDExtensionClassCreationInfo4 (no callbacks)
// @since 4.4 (adds icon_path)
pub fn ClassInfo4(comptime Userdata: type) type {
    return if (Userdata != void)
        struct {
            userdata: Userdata,
            is_virtual: bool = false,
            is_abstract: bool = false,
            is_exposed: bool = true,
            is_runtime: bool = false,
            icon_path: ?*const String = null,
        }
    else
        struct {
            is_virtual: bool = false,
            is_abstract: bool = false,
            is_exposed: bool = true,
            is_runtime: bool = false,
            icon_path: ?*const String = null,
        };
}

//
// Class Callbacks
//

// @ref GDExtensionClassCreationInfo (only the callbacks)
// @since 4.1
pub fn ClassCallbacks1(comptime T: type, comptime ClassUserdata: type) type {
    return struct {
        create: Create(T, ClassUserdata),
        destroy: Destroy(T, ClassUserdata),

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

// @ref GDExtensionClassCreationInfo2 (only the callbacks)
// @since 4.2 (adds recreate, validate_property, get_virtual_call_data, call_virtual_with_data; uses Notification2)
pub fn ClassCallbacks2(comptime T: type, comptime ClassUserdata: type, comptime VirtualCallUserdata: type) type {
    return struct {
        create: Create(T, ClassUserdata),
        destroy: Destroy(T, ClassUserdata),
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

// @ref GDExtensionClassCreationInfo3 (only the callbacks)
// @since 4.3 (uses DestroyPropertyList2 with count)
pub fn ClassCallbacks3(comptime T: type, comptime ClassUserdata: type, comptime VirtualCallUserdata: type) type {
    return struct {
        create: Create(T, ClassUserdata),
        destroy: Destroy(T, ClassUserdata),
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

// @ref GDExtensionClassCreationInfo4 (only the callbacks)
// @since 4.4 (uses Create2, GetVirtual2, GetVirtualCallData2; removes get_rid)
pub fn ClassCallbacks4(comptime T: type, comptime ClassUserdata: type, comptime VirtualCallUserdata: type) type {
    return struct {
        create: Create2(T, ClassUserdata),
        destroy: Destroy(T, ClassUserdata),
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

// @ref GDExtensionClassCreateInstance
// @since 4.1
pub fn Create(comptime T: type, comptime ClassUserdata: type) type {
    return if (ClassUserdata != void)
        fn (userdata: ClassUserdata) anyerror!*T
    else
        fn () anyerror!*T;
}

// @ref GDExtensionClassCreateInstance
fn wrapCreate(comptime T: type, comptime ClassUserdata: type, comptime callback: Create(T, ClassUserdata)) Child(c.GDExtensionClassCreateInstance) {
    return struct {
        fn wrapped(p_class_userdata: ?*anyopaque) callconv(.c) c.GDExtensionObjectPtr {
            const inst = if (ClassUserdata != void) blk: {
                const ud = @as(ClassUserdata, @ptrCast(@alignCast(p_class_userdata)));
                break :blk callback(ud) catch return null;
            } else callback() catch return null;
            return @ptrCast(Object.upcast(inst));
        }
    }.wrapped;
}

// @ref GDExtensionClassCreateInstance2
// @since 4.4 (adds notify_postinitialize)
pub fn Create2(comptime T: type, comptime ClassUserdata: type) type {
    return if (ClassUserdata != void)
        fn (userdata: ClassUserdata, notify_postinitialize: bool) anyerror!*T
    else
        fn (notify_postinitialize: bool) anyerror!*T;
}

// @ref GDExtensionClassCreateInstance2
fn wrapCreate2(comptime T: type, comptime ClassUserdata: type, comptime callback: Create2(T, ClassUserdata)) Child(c.GDExtensionClassCreateInstance2) {
    return struct {
        fn wrapped(p_class_userdata: ?*anyopaque, p_notify_postinitialize: c.GDExtensionBool) callconv(.c) c.GDExtensionObjectPtr {
            const notify = p_notify_postinitialize != 0;
            const inst = if (ClassUserdata != void) blk: {
                const ud = @as(ClassUserdata, @ptrCast(@alignCast(p_class_userdata)));
                break :blk callback(ud, notify) catch return null;
            } else callback(notify) catch return null;
            return @ptrCast(Object.upcast(inst));
        }
    }.wrapped;
}

// @ref GDExtensionClassFreeInstance
// @since 4.1
pub fn Destroy(comptime T: type, comptime ClassUserdata: type) type {
    return if (ClassUserdata != void)
        fn (instance: *T, userdata: ClassUserdata) void
    else
        fn (instance: *T) void;
}

// @ref GDExtensionClassFreeInstance
fn wrapDestroy(comptime T: type, comptime ClassUserdata: type, comptime callback: Destroy(T, ClassUserdata)) Child(c.GDExtensionClassFreeInstance) {
    return struct {
        fn wrapped(p_class_userdata: ?*anyopaque, p_instance: c.GDExtensionClassInstancePtr) callconv(.c) void {
            const inst = @as(*T, @ptrCast(@alignCast(p_instance)));
            if (ClassUserdata != void) {
                const ud = @as(ClassUserdata, @ptrCast(@alignCast(p_class_userdata)));
                callback(inst, ud);
            } else {
                callback(inst);
            }
        }
    }.wrapped;
}

// @ref GDExtensionClassRecreateInstance
// @since 4.2
pub fn Recreate(comptime T: type, comptime ClassUserdata: type) type {
    return if (ClassUserdata != void)
        fn (userdata: ClassUserdata, obj: *Object) *T
    else
        fn (obj: *Object) *T;
}

// @ref GDExtensionClassRecreateInstance
fn wrapRecreate(comptime T: type, comptime ClassUserdata: type, comptime callback: Recreate(T, ClassUserdata)) Child(c.GDExtensionClassRecreateInstance) {
    return struct {
        fn wrapped(p_class_userdata: ?*anyopaque, p_object: c.GDExtensionObjectPtr) callconv(.c) c.GDExtensionClassInstancePtr {
            const obj = @as(*Object, @ptrCast(@alignCast(p_object)));
            if (ClassUserdata != void) {
                const ud = @as(ClassUserdata, @ptrCast(@alignCast(p_class_userdata)));
                return @ptrCast(callback(ud, obj));
            } else {
                return @ptrCast(callback(obj));
            }
        }
    }.wrapped;
}

//
// Property Callbacks
//

// @ref GDExtensionClassSet
// @since 4.1
pub fn Set(comptime T: type) type {
    return fn (self: *T, name: *const StringName, value: *const Variant) PropertyError!void;
}

// @ref GDExtensionClassSet
fn wrapSet(comptime T: type, comptime callback: Set(T)) Child(c.GDExtensionClassSet) {
    return struct {
        fn wrapped(p_instance: c.GDExtensionClassInstancePtr, p_name: c.GDExtensionConstStringNamePtr, p_value: c.GDExtensionConstVariantPtr) callconv(.c) c.GDExtensionBool {
            const inst = @as(*T, @ptrCast(@alignCast(p_instance)));
            const name = @as(*const StringName, @ptrCast(p_name));
            const value = @as(*const Variant, @ptrCast(@alignCast(p_value)));
            callback(inst, name, value) catch return 0;
            return 1;
        }
    }.wrapped;
}

// @ref GDExtensionClassGet
// @since 4.1
pub fn Get(comptime T: type) type {
    return fn (self: *T, name: *const StringName) PropertyError!Variant;
}

// @ref GDExtensionClassGet
fn wrapGet(comptime T: type, comptime callback: Get(T)) Child(c.GDExtensionClassGet) {
    return struct {
        fn wrapped(p_instance: c.GDExtensionClassInstancePtr, p_name: c.GDExtensionConstStringNamePtr, r_ret: c.GDExtensionVariantPtr) callconv(.c) c.GDExtensionBool {
            const inst = @as(*T, @ptrCast(@alignCast(p_instance)));
            const name = @as(*const StringName, @ptrCast(p_name));
            const ret = @as(*Variant, @ptrCast(@alignCast(r_ret)));
            ret.* = callback(inst, name) catch return 0;
            return 1;
        }
    }.wrapped;
}

// @ref GDExtensionClassGetPropertyList
// @since 4.1
pub fn GetPropertyList(comptime T: type) type {
    return fn (self: *T) Allocator.Error![]const PropertyInfo;
}

// @ref GDExtensionClassGetPropertyList
fn wrapGetPropertyList(comptime T: type, comptime callback: GetPropertyList(T)) Child(c.GDExtensionClassGetPropertyList) {
    return struct {
        fn wrapped(p_instance: c.GDExtensionClassInstancePtr, r_count: [*c]u32) callconv(.c) [*c]const c.GDExtensionPropertyInfo {
            const inst = @as(*T, @ptrCast(@alignCast(p_instance)));
            const list = callback(inst) catch {
                if (r_count) |cnt| cnt.* = 0;
                return null;
            };
            if (r_count) |cnt| cnt.* = @intCast(list.len);
            if (list.len == 0) return null;
            return @ptrCast(list.ptr);
        }
    }.wrapped;
}

// @ref GDExtensionClassFreePropertyList
// @since 4.1
pub fn DestroyPropertyList(comptime T: type) type {
    return fn (self: *T, list: [*]const PropertyInfo) void;
}

// @ref GDExtensionClassFreePropertyList
fn wrapDestroyPropertyList(comptime T: type, comptime callback: DestroyPropertyList(T)) Child(c.GDExtensionClassFreePropertyList) {
    return struct {
        fn wrapped(p_instance: c.GDExtensionClassInstancePtr, p_list: ?*const c.GDExtensionPropertyInfo) callconv(.c) void {
            const inst = @as(*T, @ptrCast(@alignCast(p_instance)));
            if (p_list) |list| {
                callback(inst, @ptrCast(list));
            }
        }
    }.wrapped;
}

// @ref GDExtensionClassFreePropertyList2
// @since 4.3 (adds count parameter)
pub fn DestroyPropertyList2(comptime T: type) type {
    return fn (self: *T, list: []const PropertyInfo) void;
}

// @ref GDExtensionClassFreePropertyList2
fn wrapDestroyPropertyList2(comptime T: type, comptime callback: DestroyPropertyList2(T)) Child(c.GDExtensionClassFreePropertyList2) {
    return struct {
        fn wrapped(p_instance: c.GDExtensionClassInstancePtr, p_list: ?*const c.GDExtensionPropertyInfo, p_count: u32) callconv(.c) void {
            const inst = @as(*T, @ptrCast(@alignCast(p_instance)));
            if (p_list) |list| {
                const slice = @as([*]const PropertyInfo, @ptrCast(list))[0..p_count];
                callback(inst, slice);
            }
        }
    }.wrapped;
}

// @ref GDExtensionClassPropertyCanRevert
// @since 4.1
pub fn PropertyCanRevert(comptime T: type) type {
    return fn (self: *T, name: *const StringName) bool;
}

// @ref GDExtensionClassPropertyCanRevert
fn wrapPropertyCanRevert(comptime T: type, comptime callback: PropertyCanRevert(T)) Child(c.GDExtensionClassPropertyCanRevert) {
    return struct {
        fn wrapped(p_instance: c.GDExtensionClassInstancePtr, p_name: c.GDExtensionConstStringNamePtr) callconv(.c) c.GDExtensionBool {
            const inst = @as(*T, @ptrCast(@alignCast(p_instance)));
            const name = @as(*const StringName, @ptrCast(p_name));
            return if (callback(inst, name)) 1 else 0;
        }
    }.wrapped;
}

// @ref GDExtensionClassPropertyGetRevert
// @since 4.1
pub fn PropertyGetRevert(comptime T: type) type {
    return fn (self: *T, name: *const StringName) PropertyError!Variant;
}

// @ref GDExtensionClassPropertyGetRevert
fn wrapPropertyGetRevert(comptime T: type, comptime callback: PropertyGetRevert(T)) Child(c.GDExtensionClassPropertyGetRevert) {
    return struct {
        fn wrapped(p_instance: c.GDExtensionClassInstancePtr, p_name: c.GDExtensionConstStringNamePtr, r_ret: c.GDExtensionVariantPtr) callconv(.c) c.GDExtensionBool {
            const inst = @as(*T, @ptrCast(@alignCast(p_instance)));
            const name = @as(*const StringName, @ptrCast(p_name));
            const ret = @as(*Variant, @ptrCast(@alignCast(r_ret)));
            ret.* = callback(inst, name) catch return 0;
            return 1;
        }
    }.wrapped;
}

// @ref GDExtensionClassValidateProperty
// @since 4.2
pub fn ValidateProperty(comptime T: type) type {
    return fn (self: *T, property: *PropertyInfo) bool;
}

// @ref GDExtensionClassValidateProperty
fn wrapValidateProperty(comptime T: type, comptime callback: ValidateProperty(T)) Child(c.GDExtensionClassValidateProperty) {
    return struct {
        fn wrapped(p_instance: c.GDExtensionClassInstancePtr, p_property: *c.GDExtensionPropertyInfo) callconv(.c) c.GDExtensionBool {
            const inst = @as(*T, @ptrCast(@alignCast(p_instance)));
            const property = @as(*PropertyInfo, @ptrCast(p_property));
            return if (callback(inst, property)) 1 else 0;
        }
    }.wrapped;
}

//
// Notification & ToString Callbacks
//

// @ref GDExtensionClassNotification
// @since 4.1 (deprecated)
pub fn Notification1(comptime T: type) type {
    return fn (self: *T, what: i32) void;
}

// @ref GDExtensionClassNotification
fn wrapNotification1(comptime T: type, comptime callback: Notification1(T)) Child(c.GDExtensionClassNotification) {
    return struct {
        fn wrapped(p_instance: c.GDExtensionClassInstancePtr, p_what: i32) callconv(.c) void {
            const inst = @as(*T, @ptrCast(@alignCast(p_instance)));
            callback(inst, p_what);
        }
    }.wrapped;
}

// @ref GDExtensionClassNotification2
// @since 4.2 (adds reversed parameter)
pub fn Notification2(comptime T: type) type {
    return fn (self: *T, what: i32, reversed: bool) void;
}

// @ref GDExtensionClassNotification2
fn wrapNotification2(comptime T: type, comptime callback: Notification2(T)) Child(c.GDExtensionClassNotification2) {
    return struct {
        fn wrapped(p_instance: c.GDExtensionClassInstancePtr, p_what: i32, p_reversed: c.GDExtensionBool) callconv(.c) void {
            const inst = @as(*T, @ptrCast(@alignCast(p_instance)));
            callback(inst, p_what, p_reversed != 0);
        }
    }.wrapped;
}

// @ref GDExtensionClassToString
// @since 4.1
pub fn ToString(comptime T: type) type {
    return fn (self: *T) ?String;
}

// @ref GDExtensionClassToString
fn wrapToString(comptime T: type, comptime callback: ToString(T)) Child(c.GDExtensionClassToString) {
    return struct {
        fn wrapped(p_instance: c.GDExtensionClassInstancePtr, r_is_valid: [*c]c.GDExtensionBool, p_out: c.GDExtensionStringPtr) callconv(.c) void {
            const inst = @as(*T, @ptrCast(@alignCast(p_instance)));
            const out = @as(*String, @ptrCast(@alignCast(p_out)));
            out.* = callback(inst) orelse {
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

// @ref GDExtensionClassReference
// @since 4.1
pub fn Reference(comptime T: type) type {
    return fn (self: *T) void;
}

// @ref GDExtensionClassReference
fn wrapReference(comptime T: type, comptime callback: Reference(T)) Child(c.GDExtensionClassReference) {
    return struct {
        fn wrapped(p_instance: c.GDExtensionClassInstancePtr) callconv(.c) void {
            const inst = @as(*T, @ptrCast(@alignCast(p_instance)));
            callback(inst);
        }
    }.wrapped;
}

// @ref GDExtensionClassUnreference
// @since 4.1
pub fn Unreference(comptime T: type) type {
    return fn (self: *T) void;
}

// @ref GDExtensionClassUnreference
fn wrapUnreference(comptime T: type, comptime callback: Unreference(T)) Child(c.GDExtensionClassUnreference) {
    return struct {
        fn wrapped(p_instance: c.GDExtensionClassInstancePtr) callconv(.c) void {
            const inst = @as(*T, @ptrCast(@alignCast(p_instance)));
            callback(inst);
        }
    }.wrapped;
}

// @ref GDExtensionClassGetRID
// @since 4.1 (removed in 4.4)
pub fn GetRID(comptime T: type) type {
    return fn (self: *T) Rid;
}

// @ref GDExtensionClassGetRID
fn wrapGetRID(comptime T: type, comptime callback: GetRID(T)) Child(c.GDExtensionClassGetRID) {
    return struct {
        fn wrapped(p_instance: c.GDExtensionClassInstancePtr) callconv(.c) u64 {
            const inst = @as(*T, @ptrCast(@alignCast(p_instance)));
            const rid = callback(inst);
            return @bitCast(rid);
        }
    }.wrapped;
}

//
// Virtual Method Callbacks
//

// @ref GDExtensionClassCallVirtual
// @since 4.1
pub fn CallVirtual(comptime T: type) type {
    return fn (self: *T, args: [*]const *const anyopaque, ret: *anyopaque) void;
}

// @ref GDExtensionClassCallVirtual
fn wrapCallVirtual(comptime T: type, comptime callback: CallVirtual(T)) Child(c.GDExtensionClassCallVirtual) {
    return struct {
        fn wrapped(p_instance: c.GDExtensionClassInstancePtr, p_args: [*c]const c.GDExtensionConstTypePtr, r_ret: c.GDExtensionTypePtr) callconv(.c) void {
            const inst = @as(*T, @ptrCast(@alignCast(p_instance)));
            callback(inst, @ptrCast(p_args), @ptrCast(r_ret));
        }
    }.wrapped;
}

// @ref GDExtensionClassGetVirtual
// @since 4.1
pub fn GetVirtual(comptime T: type, comptime ClassUserdata: type) type {
    return if (ClassUserdata != void)
        fn (userdata: ClassUserdata, name: *const StringName) ?*const CallVirtual(T)
    else
        fn (name: *const StringName) ?*const CallVirtual(T);
}

// @ref GDExtensionClassGetVirtual
fn wrapGetVirtual(comptime T: type, comptime ClassUserdata: type, comptime callback: GetVirtual(T, ClassUserdata)) Child(c.GDExtensionClassGetVirtual) {
    return struct {
        fn wrapped(p_class_userdata: ?*anyopaque, p_name: c.GDExtensionConstStringNamePtr) callconv(.c) c.GDExtensionClassCallVirtual {
            const name = @as(*const StringName, @ptrCast(p_name));
            const virtual: ?*const CallVirtual(T) = if (ClassUserdata != void) blk: {
                const userdata = @as(ClassUserdata, @ptrCast(@alignCast(p_class_userdata)));
                break :blk callback(userdata, name);
            } else callback(name);

            if (virtual) |v| {
                return @ptrCast(v);
            }
            return null;
        }
    }.wrapped;
}

// @ref GDExtensionClassGetVirtual2
// @since 4.4 (adds hash parameter)
pub fn GetVirtual2(comptime T: type, comptime ClassUserdata: type) type {
    return if (ClassUserdata != void)
        fn (userdata: ClassUserdata, name: *const StringName, hash: u32) ?*const CallVirtual(T)
    else
        fn (name: *const StringName, hash: u32) ?*const CallVirtual(T);
}

// @ref GDExtensionClassGetVirtual2
fn wrapGetVirtual2(comptime T: type, comptime ClassUserdata: type, comptime callback: GetVirtual2(T, ClassUserdata)) Child(c.GDExtensionClassGetVirtual2) {
    return struct {
        fn wrapped(p_class_userdata: ?*anyopaque, p_name: c.GDExtensionConstStringNamePtr, p_hash: u32) callconv(.c) c.GDExtensionClassCallVirtual {
            const name = @as(*const StringName, @ptrCast(p_name));
            const virtual: ?*const CallVirtual(T) = if (ClassUserdata != void) blk: {
                const userdata = @as(ClassUserdata, @ptrCast(@alignCast(p_class_userdata)));
                break :blk callback(userdata, name, p_hash);
            } else callback(name, p_hash);

            if (virtual) |v| {
                return @ptrCast(v);
            }
            return null;
        }
    }.wrapped;
}

// @ref GDExtensionClassGetVirtualCallData
// @since 4.2
pub fn GetVirtualCallData(comptime ClassUserdata: type, comptime VirtualCallUserdata: type) type {
    return if (ClassUserdata != void)
        fn (userdata: ClassUserdata, name: *const StringName) ?*VirtualCallUserdata
    else
        fn (name: *const StringName) ?*VirtualCallUserdata;
}

// @ref GDExtensionClassGetVirtualCallData
fn wrapGetVirtualCallData(comptime ClassUserdata: type, comptime VirtualCallUserdata: type, comptime callback: GetVirtualCallData(ClassUserdata, VirtualCallUserdata)) Child(c.GDExtensionClassGetVirtualCallData) {
    return struct {
        fn wrapped(p_class_userdata: ?*anyopaque, p_name: c.GDExtensionConstStringNamePtr) callconv(.c) ?*anyopaque {
            const name = @as(*const StringName, @ptrCast(p_name));
            if (ClassUserdata != void) {
                const userdata = @as(ClassUserdata, @ptrCast(@alignCast(p_class_userdata)));
                return @ptrCast(callback(userdata, name));
            } else {
                return @ptrCast(callback(name));
            }
        }
    }.wrapped;
}

// @ref GDExtensionClassGetVirtualCallData2
// @since 4.4 (adds hash parameter)
pub fn GetVirtualCallData2(comptime ClassUserdata: type, comptime VirtualCallUserdata: type) type {
    return if (ClassUserdata != void)
        fn (userdata: ClassUserdata, name: *const StringName, hash: u32) ?*VirtualCallUserdata
    else
        fn (name: *const StringName, hash: u32) ?*VirtualCallUserdata;
}

// @ref GDExtensionClassGetVirtualCallData2
fn wrapGetVirtualCallData2(comptime ClassUserdata: type, comptime VirtualCallUserdata: type, comptime callback: GetVirtualCallData2(ClassUserdata, VirtualCallUserdata)) Child(c.GDExtensionClassGetVirtualCallData2) {
    return struct {
        fn wrapped(p_class_userdata: ?*anyopaque, p_name: c.GDExtensionConstStringNamePtr, p_hash: u32) callconv(.c) ?*anyopaque {
            const name = @as(*const StringName, @ptrCast(p_name));
            if (ClassUserdata != void) {
                const userdata = @as(ClassUserdata, @ptrCast(@alignCast(p_class_userdata)));
                return @ptrCast(callback(userdata, name, p_hash));
            } else {
                return @ptrCast(callback(name, p_hash));
            }
        }
    }.wrapped;
}

// @ref GDExtensionClassCallVirtualWithData
// @since 4.2
pub fn CallVirtualWithData(comptime T: type, comptime VirtualCallUserdata: type) type {
    return if (VirtualCallUserdata != void)
        fn (instance: *T, name: *const StringName, virtual_call_userdata: *VirtualCallUserdata, args: [*]const *const anyopaque, ret: *anyopaque) void
    else
        fn (instance: *T, name: *const StringName, args: [*]const *const anyopaque, ret: *anyopaque) void;
}

// @ref GDExtensionClassCallVirtualWithData
fn wrapCallVirtualWithData(comptime T: type, comptime VirtualCallUserdata: type, comptime callback: CallVirtualWithData(T, VirtualCallUserdata)) Child(c.GDExtensionClassCallVirtualWithData) {
    return struct {
        fn wrapped(p_instance: c.GDExtensionClassInstancePtr, p_name: c.GDExtensionConstStringNamePtr, p_virtual_call_userdata: ?*anyopaque, p_args: [*c]const c.GDExtensionConstTypePtr, r_ret: c.GDExtensionTypePtr) callconv(.c) void {
            const inst = @as(*T, @ptrCast(@alignCast(p_instance)));
            const name = @as(*const StringName, @ptrCast(p_name));
            if (VirtualCallUserdata != void) {
                const userdata = @as(*VirtualCallUserdata, @ptrCast(@alignCast(p_virtual_call_userdata)));
                callback(inst, name, userdata, @ptrCast(p_args), @ptrCast(r_ret));
            } else {
                callback(inst, name, @ptrCast(p_args), @ptrCast(r_ret));
            }
        }
    }.wrapped;
}

//
// Method Types
//

// @ref GDExtensionClassMethodInfo (non-callback fields)
// @since 4.1
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

// @ref GDExtensionClassMethodInfo (callback fields only)
// @since 4.1
pub fn MethodCallbacks(comptime T: type, comptime Userdata: type) type {
    return struct {
        call: ?Call(T, Userdata) = null,
        ptr_call: ?PtrCall(T, Userdata) = null,
    };
}

// @ref GDExtensionClassMethodArgumentMetadata
// @since 4.1
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

// @ref GDExtensionClassMethodCall
// @since 4.1
pub fn Call(comptime T: type, comptime Userdata: type) type {
    return if (Userdata != void)
        fn (userdata: *Userdata, instance: *T, args: []const *const Variant) CallError!Variant
    else
        fn (instance: *T, args: []const *const Variant) CallError!Variant;
}

// @ref GDExtensionClassMethodCall
fn wrapCall(comptime T: type, comptime Userdata: type, comptime callback: Call(T, Userdata)) Child(c.GDExtensionClassMethodCall) {
    return struct {
        fn wrapped(method_userdata: ?*anyopaque, p_instance: c.GDExtensionClassInstancePtr, p_args: [*c]const c.GDExtensionConstVariantPtr, p_argument_count: c.GDExtensionInt, r_return: c.GDExtensionVariantPtr, r_error: [*c]c.GDExtensionCallError) callconv(.c) void {
            const inst = @as(*T, @ptrCast(@alignCast(p_instance)));
            const arg_count: usize = @intCast(p_argument_count);
            const args: []const *const Variant = if (arg_count > 0 and p_args != null)
                @as([*]const *const Variant, @ptrCast(p_args))[0..arg_count]
            else
                &.{};
            const ret = @as(*Variant, @ptrCast(@alignCast(r_return)));

            if (Userdata != void) {
                const userdata = @as(*Userdata, @ptrCast(@alignCast(method_userdata)));
                ret.* = callback(userdata, inst, args) catch |err| {
                    if (r_error) |e| e.* = @bitCast(CallResult.fromError(err));
                    return;
                };
            } else {
                ret.* = callback(inst, args) catch |err| {
                    if (r_error) |e| e.* = @bitCast(CallResult.fromError(err));
                    return;
                };
            }
            if (r_error) |e| e.*.@"error" = c.GDEXTENSION_CALL_OK;
        }
    }.wrapped;
}

// @ref GDExtensionClassMethodPtrCall
// @since 4.1
pub fn PtrCall(comptime T: type, comptime Userdata: type) type {
    return if (Userdata != void)
        fn (userdata: *Userdata, instance: *T, args: [*]const *const anyopaque, ret: ?*anyopaque) void
    else
        fn (instance: *T, args: [*]const *const anyopaque, ret: ?*anyopaque) void;
}

// @ref GDExtensionClassMethodPtrCall
fn wrapPtrCall(comptime T: type, comptime Userdata: type, comptime callback: PtrCall(T, Userdata)) Child(c.GDExtensionClassMethodPtrCall) {
    return struct {
        fn wrapped(method_userdata: ?*anyopaque, p_instance: c.GDExtensionClassInstancePtr, p_args: [*c]const c.GDExtensionConstTypePtr, r_ret: c.GDExtensionTypePtr) callconv(.c) void {
            const inst = @as(*T, @ptrCast(@alignCast(p_instance)));

            if (Userdata != void) {
                const userdata = @as(*Userdata, @ptrCast(@alignCast(method_userdata)));
                callback(userdata, inst, @ptrCast(p_args), @ptrCast(r_ret));
            } else {
                callback(inst, @ptrCast(p_args), @ptrCast(r_ret));
            }
        }
    }.wrapped;
}

//
// Call Result
//

// @ref GDExtensionCallError
// @since 4.1
pub const CallResult = extern struct {
    @"error": Status = .ok,
    argument: i32 = 0,
    expected: i32 = 0,

    pub const Status = enum(c.GDExtensionCallErrorType) {
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

// @ref GDExtensionPropertyInfo
// @since 4.1
pub const PropertyInfo = extern struct {
    type: Variant.Tag,
    name: *const StringName = &StringName.empty,
    class_name: *const StringName = &StringName.empty,
    hint: PropertyHint = .property_hint_none,
    hint_string: *const String = &String.empty,
    usage: PropertyUsageFlags = .property_usage_default,
};

//
// Registration Functions
//

/// Registers an extension class in the ClassDb.
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
    const userdata: ?*anyopaque = if (Userdata != void) @ptrCast(@constCast(info.userdata)) else null;

    raw.classdbRegisterExtensionClass(
        raw.library,
        @ptrCast(class_name),
        @ptrCast(base_class_name),
        &c.GDExtensionClassCreationInfo{
            .is_virtual = @intFromBool(info.is_virtual),
            .is_abstract = @intFromBool(info.is_abstract),

            .create_instance_func = wrapCreate(T, Userdata, callbacks.create),
            .free_instance_func = wrapDestroy(T, Userdata, callbacks.destroy),
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

/// Registers an extension class in the ClassDb.
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
    const userdata: ?*anyopaque = if (Userdata != void) @ptrCast(@constCast(info.userdata)) else null;

    const func = raw.classdbRegisterExtensionClass2 orelse @panic("classdb_register_extension_class2 requires Godot 4.2+");
    func(
        raw.library,
        @ptrCast(class_name),
        @ptrCast(base_class_name),
        &c.GDExtensionClassCreationInfo2{
            .is_virtual = @intFromBool(info.is_virtual),
            .is_abstract = @intFromBool(info.is_abstract),
            .is_exposed = @intFromBool(info.is_exposed),

            .create_instance_func = wrapCreate(T, Userdata, callbacks.create),
            .free_instance_func = wrapDestroy(T, Userdata, callbacks.destroy),
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
            .notification_func = if (callbacks.notification) |f| wrapNotification2(T, f) else null,
            .to_string_func = if (callbacks.to_string) |f| wrapToString(T, f) else null,
            .reference_func = if (callbacks.reference) |f| wrapReference(T, f) else null,
            .unreference_func = if (callbacks.unreference) |f| wrapUnreference(T, f) else null,
            .get_rid_func = if (callbacks.get_rid) |f| wrapGetRID(T, f) else null,

            .class_userdata = userdata,
        },
    );
}

/// Registers an extension class in the ClassDb.
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
    const userdata: ?*anyopaque = if (Userdata != void) @ptrCast(@constCast(info.userdata)) else null;

    const func = raw.classdbRegisterExtensionClass3 orelse @panic("classdb_register_extension_class3 requires Godot 4.3+");
    func(
        raw.library,
        @ptrCast(class_name),
        @ptrCast(base_class_name),
        &c.GDExtensionClassCreationInfo3{
            .is_virtual = @intFromBool(info.is_virtual),
            .is_abstract = @intFromBool(info.is_abstract),
            .is_exposed = @intFromBool(info.is_exposed),
            .is_runtime = @intFromBool(info.is_runtime),

            .create_instance_func = wrapCreate(T, Userdata, callbacks.create),
            .free_instance_func = wrapDestroy(T, Userdata, callbacks.destroy),
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
            .notification_func = if (callbacks.notification) |f| wrapNotification2(T, f) else null,
            .to_string_func = if (callbacks.to_string) |f| wrapToString(T, f) else null,
            .reference_func = if (callbacks.reference) |f| wrapReference(T, f) else null,
            .unreference_func = if (callbacks.unreference) |f| wrapUnreference(T, f) else null,
            .get_rid_func = if (callbacks.get_rid) |f| wrapGetRID(T, f) else null,

            .class_userdata = userdata,
        },
    );
}

/// Registers an extension class in the ClassDb.
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
    const userdata: ?*anyopaque = if (Userdata != void) @ptrCast(@constCast(info.userdata)) else null;

    const func = raw.classdbRegisterExtensionClass4 orelse @panic("classdb_register_extension_class4 requires Godot 4.4+");
    func(
        raw.library,
        @ptrCast(class_name),
        @ptrCast(base_class_name),
        &c.GDExtensionClassCreationInfo4{
            .is_virtual = @intFromBool(info.is_virtual),
            .is_abstract = @intFromBool(info.is_abstract),
            .is_exposed = @intFromBool(info.is_exposed),
            .is_runtime = @intFromBool(info.is_runtime),
            .icon_path = @ptrCast(info.icon_path),

            .create_instance_func = wrapCreate2(T, Userdata, callbacks.create),
            .free_instance_func = wrapDestroy(T, Userdata, callbacks.destroy),
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
            .notification_func = if (callbacks.notification) |f| wrapNotification2(T, f) else null,
            .to_string_func = if (callbacks.to_string) |f| wrapToString(T, f) else null,
            .reference_func = if (callbacks.reference) |f| wrapReference(T, f) else null,
            .unreference_func = if (callbacks.unreference) |f| wrapUnreference(T, f) else null,

            .class_userdata = userdata,
        },
    );
}

/// Registers a method on an extension class in the ClassDb.
///
/// @since 4.1
pub inline fn registerMethod(
    comptime T: type,
    comptime Userdata: type,
    class_name: *const StringName,
    info: MethodInfo(Userdata),
    comptime callbacks: MethodCallbacks(T, Userdata),
) void {
    const userdata: ?*anyopaque = if (Userdata != void) @ptrCast(@constCast(info.userdata)) else null;

    raw.classdbRegisterExtensionClassMethod(
        raw.library,
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
            .arguments_info = if (info.argument_info.len > 0) @ptrCast(@constCast(info.argument_info.ptr)) else null,
            .arguments_metadata = if (info.argument_metadata.len > 0) @ptrCast(@constCast(info.argument_metadata.ptr)) else null,
            .default_argument_count = @intCast(info.default_arguments.len),
            .default_arguments = if (info.default_arguments.len > 0) @ptrCast(@constCast(info.default_arguments.ptr)) else null,
        },
    );
}

/// Registers a signal on an extension class in the ClassDb.
///
/// @since 4.1
pub inline fn registerSignal(class_name: *const StringName, signal_name: *const StringName, argument_info: []const PropertyInfo) void {
    raw.classdbRegisterExtensionClassSignal(
        raw.library,
        @ptrCast(class_name),
        @ptrCast(signal_name),
        @ptrCast(argument_info.ptr),
        @intCast(argument_info.len),
    );
}

/// Registers a property on an extension class in the ClassDb.
///
/// @since 4.1
pub inline fn registerProperty(class_name: *const StringName, info: *const PropertyInfo, setter: *const StringName, getter: *const StringName) void {
    raw.classdbRegisterExtensionClassProperty(
        raw.library,
        @ptrCast(class_name),
        @ptrCast(info),
        @ptrCast(setter),
        @ptrCast(getter),
    );
}

/// Registers an indexed property on an extension class in the ClassDb.
///
/// @since 4.2
pub inline fn registerPropertyIndexed(class_name: *const StringName, info: *const PropertyInfo, setter: *const StringName, getter: *const StringName, index: i64) void {
    const func = raw.classdbRegisterExtensionClassPropertyIndexed orelse @panic("classdb_register_extension_class_property_indexed requires Godot 4.2+");
    func(
        raw.library,
        @ptrCast(class_name),
        @ptrCast(info),
        @ptrCast(setter),
        @ptrCast(getter),
        index,
    );
}

/// Registers a property group on an extension class in the ClassDb.
///
/// @since 4.1
pub inline fn registerPropertyGroup(class_name: *const StringName, group_name: *const String, prefix: *const String) void {
    raw.classdbRegisterExtensionClassPropertyGroup(
        raw.library,
        @ptrCast(class_name),
        @ptrCast(group_name),
        @ptrCast(prefix),
    );
}

/// Registers a property subgroup on an extension class in the ClassDb.
///
/// @since 4.1
pub inline fn registerPropertySubgroup(class_name: *const StringName, subgroup_name: *const String, prefix: *const String) void {
    raw.classdbRegisterExtensionClassPropertySubgroup(
        raw.library,
        @ptrCast(class_name),
        @ptrCast(subgroup_name),
        @ptrCast(prefix),
    );
}

/// Registers an integer constant on an extension class in the ClassDb.
///
/// @since 4.1
pub inline fn registerIntegerConstant(class_name: *const StringName, enum_name: *const StringName, constant_name: *const StringName, constant_value: i64, is_bitfield: bool) void {
    raw.classdbRegisterExtensionClassIntegerConstant(
        raw.library,
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

/// Registers a virtual method on an extension class in the ClassDb.
/// This allows scripts or other extensions to implement the method.
///
/// @since 4.3
pub inline fn registerVirtualMethod(class_name: *const StringName, info: VirtualMethodInfo) void {
    const func = raw.classdbRegisterExtensionClassVirtualMethod orelse @panic("classdb_register_extension_class_virtual_method requires Godot 4.3+");
    func(
        raw.library,
        @ptrCast(class_name),
        &c.GDExtensionClassVirtualMethodInfo{
            .name = @ptrCast(@constCast(info.name)),
            .method_flags = @bitCast(info.flags),
            .return_value = @bitCast(info.return_value),
            .return_value_metadata = @intFromEnum(info.return_value_metadata),
            .argument_count = @intCast(info.arguments.len),
            .arguments = @ptrCast(@constCast(info.arguments.ptr)),
            .arguments_metadata = @ptrCast(@constCast(info.arguments_metadata.ptr)),
        },
    );
}

/// Unregisters an extension class in the ClassDb.
///
/// @since 4.1
pub inline fn unregisterClass(class_name: *const StringName) void {
    raw.classdbUnregisterExtensionClass(
        raw.library,
        @ptrCast(class_name),
    );
}

const Allocator = std.mem.Allocator;
const Child = std.meta.Child;
const CallError = gdzig.CallError;
const PropertyError = gdzig.PropertyError;
const MethodFlags = gdzig.global.MethodFlags;
const PropertyHint = gdzig.global.PropertyHint;
const PropertyUsageFlags = gdzig.global.PropertyUsageFlags;
const Rid = gdzig.builtin.Rid;

// @mixin stop

const std = @import("std");

const c = @import("gdextension");

const gdzig = @import("gdzig");
const raw = &gdzig.raw;
const Object = gdzig.class.Object;
const String = gdzig.builtin.String;
const StringName = gdzig.builtin.StringName;
const Variant = gdzig.builtin.Variant;
