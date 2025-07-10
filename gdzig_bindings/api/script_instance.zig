const raw: *Interface = &@import("../../gdzig_bindings.zig").raw;

pub const PlaceHolderScriptInstance = opaque {
    pub fn ptr(self: *PlaceHolderScriptInstance) *anyopaque {
        return @ptrCast(self);
    }

    pub fn constPtr(self: *const PlaceHolderScriptInstance) *const anyopaque {
        return @ptrCast(self);
    }
};

/// **Deprecated** in Godot 4.2. Use `scriptInstanceCreate3` instead.
///
/// Creates a script instance that contains the given info and instance data.
///
/// @param info A pointer to a GDExtensionScriptInstanceInfo struct.
/// @param instance_data A pointer to a data representing the script instance in the GDExtension. This will be passed to all the function pointers on info.
///
/// @return A pointer to a ScriptInstanceExtension object.
///
/// @since 4.1
pub inline fn scriptInstanceCreate(
    comptime T: type,
    instance_data: *T,
    comptime callbacks: *const ScriptInstanceCallbacks(T),
) *Script {
    return raw.scriptInstanceCreate(&c.GDExtensionScriptInstanceInfo{
        .set_func = if (callbacks.set) |f| &wrapSet(T, f) else null,
        .get_func = if (callbacks.get) |f| &wrapGet(T, f) else null,
        .get_property_list_func = if (callbacks.get_property_list) |f| &wrapGetPropertyList(T, f) else null,
        .free_property_list_func = if (callbacks.free_property_list) |f| &wrapFreePropertyList(T, f) else null,
        .property_can_revert_func = if (callbacks.property_can_revert) |f| &wrapPropertyCanRevert(T, f) else null,
        .property_get_revert_func = if (callbacks.property_get_revert) |f| &wrapPropertyGetRevert(T, f) else null,
        .get_owner_func = if (callbacks.get_owner) |f| &wrapGetOwner(T, f) else null,
        .get_property_state_func = if (callbacks.get_property_state) |f| &wrapGetPropertyState(T, f) else null,
        .get_method_list_func = if (callbacks.get_method_list) |f| &wrapGetMethodList(T, f) else null,
        .free_method_list_func = if (callbacks.free_method_list) |f| &wrapFreeMethodList(T, f) else null,
        .get_property_type_func = if (callbacks.get_property_type) |f| &wrapGetPropertyType(T, f) else null,
        .has_method_func = if (callbacks.has_method) |f| &wrapHasMethod(T, f) else null,
        .call_func = if (callbacks.call) |f| &wrapCall(T, f) else null,
        .notification_func = if (callbacks.notification) |f| &wrapNotification(T, f) else null,
        .to_string_func = if (callbacks.to_string) |f| &wrapToString(T, f) else null,
        .refcount_incremented_func = if (callbacks.refcount_incremented) |f| &wrapRefCountIncremented(T, f) else null,
        .refcount_decremented_func = if (callbacks.refcount_decremented) |f| &wrapRefCountDecremented(T, f) else null,
        .get_script_func = if (callbacks.get_script) |f| &wrapGetScript(T, f) else null,
        .is_placeholder_func = if (callbacks.is_placeholder) |f| &wrapIsPlaceholder(T, f) else null,
        .set_fallback_func = if (callbacks.set_fallback) |f| &wrapSet(T, f) else null,
        .get_fallback_func = if (callbacks.get_fallback) |f| &wrapGet(T, f) else null,
        .get_language_func = if (callbacks.get_language) |f| &wrapGetLanguage(T, f) else null,
        .free_func = if (callbacks.free) |f| &wrapFree(T, f) else null,
    }, @ptrCast(instance_data));
}

/// **Deprecated** in Godot 4.3. Use `scriptInstanceCreate3` instead.
///
/// Creates a script instance that contains the given info and instance data.
///
/// @param info A pointer to a GDExtensionScriptInstanceInfo2 struct.
/// @param instance_data A pointer to a data representing the script instance in the GDExtension. This will be passed to all the function pointers on info.
///
/// @return A pointer to a ScriptInstanceExtension object.
///
/// @since 4.2
pub inline fn scriptInstanceCreate2(
    comptime T: type,
    instance_data: *T,
    comptime callbacks: *const ScriptInstanceCallbacks2(T),
) *Script {
    return raw.scriptInstanceCreate2(&c.GDExtensionScriptInstanceInfo2{
        .set_func = if (callbacks.set) |f| &wrapSet(T, f) else null,
        .get_func = if (callbacks.get) |f| &wrapGet(T, f) else null,
        .get_property_list_func = if (callbacks.get_property_list) |f| &wrapGetPropertyList(T, f) else null,
        .free_property_list_func = if (callbacks.free_property_list) |f| &wrapFreePropertyList2(T, f) else null,
        .get_class_category_func = if (callbacks.get_class_category) |f| &wrapGetClassCategory(T, f) else null,
        .property_can_revert_func = if (callbacks.property_can_revert) |f| &wrapPropertyCanRevert(T, f) else null,
        .property_get_revert_func = if (callbacks.property_get_revert) |f| &wrapPropertyGetRevert(T, f) else null,
        .get_owner_func = if (callbacks.get_owner) |f| &wrapGetOwner(T, f) else null,
        .get_property_state_func = if (callbacks.get_property_state) |f| &wrapGetPropertyState(T, f) else null,
        .get_method_list_func = if (callbacks.get_method_list) |f| &wrapGetMethodList(T, f) else null,
        .free_method_list_func = if (callbacks.free_method_list) |f| &wrapFreeMethodList2(T, f) else null,
        .get_property_type_func = if (callbacks.get_property_type) |f| &wrapGetPropertyType(T, f) else null,
        .validate_property_func = if (callbacks.validate_property) |f| &wrapValidateProperty(T, f) else null,
        .has_method_func = if (callbacks.has_method) |f| &wrapHasMethod(T, f) else null,
        .call_func = if (callbacks.call) |f| &wrapCall(T, f) else null,
        .notification_func = if (callbacks.notification) |f| &wrapNotification2(T, f) else null,
        .to_string_func = if (callbacks.to_string) |f| &wrapToString(T, f) else null,
        .refcount_incremented_func = if (callbacks.refcount_incremented) |f| &wrapRefCountIncremented(T, f) else null,
        .refcount_decremented_func = if (callbacks.refcount_decremented) |f| &wrapRefCountDecremented(T, f) else null,
        .get_script_func = if (callbacks.get_script) |f| &wrapGetScript(T, f) else null,
        .is_placeholder_func = if (callbacks.is_placeholder) |f| &wrapIsPlaceholder(T, f) else null,
        .set_fallback_func = if (callbacks.set_fallback) |f| &wrapSet(T, f) else null,
        .get_fallback_func = if (callbacks.get_fallback) |f| &wrapGet(T, f) else null,
        .get_language_func = if (callbacks.get_language) |f| &wrapGetLanguage(T, f) else null,
        .free_func = if (callbacks.free) |f| &wrapFree(T, f) else null,
    }, @ptrCast(instance_data));
}

/// Creates a script instance that contains the given info and instance data.
///
/// @param info A pointer to a GDExtensionScriptInstanceInfo3 struct.
/// @param instance_data A pointer to a data representing the script instance in the GDExtension. This will be passed to all the function pointers on info.
///
/// @return A pointer to a ScriptInstanceExtension object.
///
/// @since 4.3
pub inline fn scriptInstanceCreate3(
    comptime T: type,
    instance_data: *T,
    comptime callbacks: *const ScriptInstanceCallbacks3(T),
) *Script {
    return raw.scriptInstanceCreate3(&c.GDExtensionScriptInstanceInfo3{
        .set_func = if (callbacks.set) |f| &wrapSet(T, f) else null,
        .get_func = if (callbacks.get) |f| &wrapGet(T, f) else null,
        .get_property_list_func = if (callbacks.get_property_list) |f| &wrapGetPropertyList(T, f) else null,
        .free_property_list_func = if (callbacks.free_property_list) |f| &wrapFreePropertyList2(T, f) else null,
        .get_class_category_func = if (callbacks.get_class_category) |f| &wrapGetClassCategory(T, f) else null,
        .property_can_revert_func = if (callbacks.property_can_revert) |f| &wrapPropertyCanRevert(T, f) else null,
        .property_get_revert_func = if (callbacks.property_get_revert) |f| &wrapPropertyGetRevert(T, f) else null,
        .get_owner_func = if (callbacks.get_owner) |f| &wrapGetOwner(T, f) else null,
        .get_property_state_func = if (callbacks.get_property_state) |f| &wrapGetPropertyState(T, f) else null,
        .get_method_list_func = if (callbacks.get_method_list) |f| &wrapGetMethodList(T, f) else null,
        .free_method_list_func = if (callbacks.free_method_list) |f| &wrapFreeMethodList2(T, f) else null,
        .get_property_type_func = if (callbacks.get_property_type) |f| &wrapGetPropertyType(T, f) else null,
        .validate_property_func = if (callbacks.validate_property) |f| &wrapValidateProperty(T, f) else null,
        .has_method_func = if (callbacks.has_method) |f| &wrapHasMethod(T, f) else null,
        .get_method_argument_count_func = if (callbacks.get_method_argument_count) |f| &wrapGetMethodArgumentCount(T, f) else null,
        .call_func = if (callbacks.call) |f| &wrapCall(T, f) else null,
        .notification_func = if (callbacks.notification) |f| &wrapNotification2(T, f) else null,
        .to_string_func = if (callbacks.to_string) |f| &wrapToString(T, f) else null,
        .refcount_incremented_func = if (callbacks.refcount_incremented) |f| &wrapRefCountIncremented(T, f) else null,
        .refcount_decremented_func = if (callbacks.refcount_decremented) |f| &wrapRefCountDecremented(T, f) else null,
        .get_script_func = if (callbacks.get_script) |f| &wrapGetScript(T, f) else null,
        .is_placeholder_func = if (callbacks.is_placeholder) |f| &wrapIsPlaceholder(T, f) else null,
        .set_fallback_func = if (callbacks.set_fallback) |f| &wrapSet(T, f) else null,
        .get_fallback_func = if (callbacks.get_fallback) |f| &wrapGet(T, f) else null,
        .get_language_func = if (callbacks.get_language) |f| &wrapGetLanguage(T, f) else null,
        .free_func = if (callbacks.free) |f| &wrapFree(T, f) else null,
    }, @ptrCast(instance_data));
}

/// Creates a placeholder script instance for a given script and instance.
///
/// This interface is optional as a custom placeholder could also be created with script_instance_create().
///
/// @param language A pointer to a ScriptLanguage.
/// @param script A pointer to a Script.
/// @param owner A pointer to an Object.
///
/// @return A pointer to a PlaceHolderScriptInstance object.
///
/// @since 4.2
pub inline fn placeholderScriptInstanceCreate(language: *ScriptLanguage, script: *Script, owner: *Object) *PlaceHolderScriptInstance {
    return raw.placeholderScriptInstanceCreate(language.ptr(), script.ptr(), owner.ptr());
}

/// Updates a placeholder script instance with the given properties and values.
///
/// The passed in placeholder must be an instance of PlaceHolderScriptInstance
/// such as the one returned by placeholder_script_instance_create().
///
/// @param placeholder A pointer to a PlaceHolderScriptInstance.
/// @param properties A pointer to an Array of Dictionary representing PropertyInfo.
/// @param values A pointer to a Dictionary mapping StringName to Variant values.
///
/// @since 4.2
pub inline fn placeholderScriptInstanceUpdate(placeholder: *PlaceHolderScriptInstance, properties: *const Array, values: *const Dictionary) void {
    raw.placeholderScriptInstanceUpdate(placeholder, properties.constPtr(), values.constPtr());
}

pub const MethodInfo = extern struct {
    name: *StringName,
    return_value: PropertyInfo,
    flags: MethodFlags,
    id: i32,
    argument_count: u32,
    arguments: [*]PropertyInfo,
    default_argument_count: u32,
    default_arguments: [*]*Variant,
};

// Script Instance Callback Structs
pub fn ScriptInstanceCallbacks(comptime T: type) type {
    return struct {
        set: ?*const Set(T) = null,
        get: ?*const Get(T) = null,
        get_property_list: ?*const GetPropertyList(T) = null,
        free_property_list: ?*const FreePropertyList(T) = null,
        property_can_revert: ?*const PropertyCanRevert(T) = null,
        property_get_revert: ?*const PropertyGetRevert(T) = null,
        get_owner: ?*const GetOwner(T) = null,
        get_property_state: ?*const GetPropertyState(T) = null,
        get_method_list: ?*const GetMethodList(T) = null,
        free_method_list: ?*const FreeMethodList(T) = null,
        get_property_type: ?*const GetPropertyType(T) = null,
        has_method: ?*const HasMethod(T) = null,
        call: ?*const Call(T) = null,
        notification: ?*const Notification(T) = null,
        to_string: ?*const ToString(T) = null,
        refcount_incremented: ?*const RefCountIncremented(T) = null,
        refcount_decremented: ?*const RefCountDecremented(T) = null,
        get_script: ?*const GetScript(T) = null,
        is_placeholder: ?*const IsPlaceholder(T) = null,
        set_fallback: ?*const Set(T) = null,
        get_fallback: ?*const Get(T) = null,
        get_language: ?*const GetLanguage(T) = null,
        free: ?*const Free(T) = null,
    };
}

pub fn ScriptInstanceCallbacks2(comptime T: type) type {
    return struct {
        set: ?*const Set(T) = null,
        get: ?*const Get(T) = null,
        get_property_list: ?*const GetPropertyList(T) = null,
        free_property_list: ?*const FreePropertyList2(T) = null,
        get_class_category: ?*const GetClassCategory(T) = null,
        property_can_revert: ?*const PropertyCanRevert(T) = null,
        property_get_revert: ?*const PropertyGetRevert(T) = null,
        get_owner: ?*const GetOwner(T) = null,
        get_property_state: ?*const GetPropertyState(T) = null,
        get_method_list: ?*const GetMethodList(T) = null,
        free_method_list: ?*const FreeMethodList2(T) = null,
        get_property_type: ?*const GetPropertyType(T) = null,
        validate_property: ?*const ValidateProperty(T) = null,
        has_method: ?*const HasMethod(T) = null,
        call: ?*const Call(T) = null,
        notification: ?*const Notification2(T) = null,
        to_string: ?*const ToString(T) = null,
        refcount_incremented: ?*const RefCountIncremented(T) = null,
        refcount_decremented: ?*const RefCountDecremented(T) = null,
        get_script: ?*const GetScript(T) = null,
        is_placeholder: ?*const IsPlaceholder(T) = null,
        set_fallback: ?*const Set(T) = null,
        get_fallback: ?*const Get(T) = null,
        get_language: ?*const GetLanguage(T) = null,
        free: ?*const Free(T) = null,
    };
}

pub fn ScriptInstanceCallbacks3(comptime T: type) type {
    return struct {
        set: ?*const Set(T) = null,
        get: ?*const Get(T) = null,
        get_property_list: ?*const GetPropertyList(T) = null,
        free_property_list: ?*const FreePropertyList2(T) = null,
        get_class_category: ?*const GetClassCategory(T) = null,
        property_can_revert: ?*const PropertyCanRevert(T) = null,
        property_get_revert: ?*const PropertyGetRevert(T) = null,
        get_owner: ?*const GetOwner(T) = null,
        get_property_state: ?*const GetPropertyState(T) = null,
        get_method_list: ?*const GetMethodList(T) = null,
        free_method_list: ?*const FreeMethodList2(T) = null,
        get_property_type: ?*const GetPropertyType(T) = null,
        validate_property: ?*const ValidateProperty(T) = null,
        has_method: ?*const HasMethod(T) = null,
        get_method_argument_count: ?*const GetMethodArgumentCount(T) = null,
        call: ?*const Call(T) = null,
        notification: ?*const Notification2(T) = null,
        to_string: ?*const ToString(T) = null,
        refcount_incremented: ?*const RefCountIncremented(T) = null,
        refcount_decremented: ?*const RefCountDecremented(T) = null,
        get_script: ?*const GetScript(T) = null,
        is_placeholder: ?*const IsPlaceholder(T) = null,
        set_fallback: ?*const Set(T) = null,
        get_fallback: ?*const Get(T) = null,
        get_language: ?*const GetLanguage(T) = null,
        free: ?*const Free(T) = null,
    };
}

// Script Instance Callback Types

pub fn Set(comptime T: type) type {
    return fn (instance: *T, name: *const StringName, value: *const Variant) Error!void;
}

pub fn wrapSet(comptime T: type, comptime callback: *const Set(T)) Child(c.GDExtensionScriptInstanceSet) {
    return struct {
        fn wrapped(p_instance: c.GDExtensionScriptInstanceDataPtr, p_name: c.GDExtensionConstStringNamePtr, p_value: c.GDExtensionConstVariantPtr) callconv(.c) c.GDExtensionBool {
            const instance = @as(*T, @ptrCast(@alignCast(p_instance)));
            const name = @as(*const StringName, @ptrCast(p_name));
            const value = @as(*const Variant, @ptrCast(p_value));
            callback(instance, name, value) catch return 0;
            return 1;
        }
    }.wrapped;
}

pub fn Get(comptime T: type) type {
    return fn (instance: *T, name: *const StringName) Error!Variant;
}

pub fn wrapGet(comptime T: type, comptime callback: *const Get(T)) Child(c.GDExtensionScriptInstanceGet) {
    return struct {
        fn wrapped(p_instance: c.GDExtensionScriptInstanceDataPtr, p_name: c.GDExtensionConstStringNamePtr, r_ret: c.GDExtensionVariantPtr) callconv(.c) c.GDExtensionBool {
            const instance = @as(*T, @ptrCast(@alignCast(p_instance)));
            const name = @as(*const StringName, @ptrCast(p_name));
            const ret = @as(*Variant, @ptrCast(@alignCast(r_ret)));
            ret.* = callback(instance, name) catch return 0;
            return 1;
        }
    }.wrapped;
}

pub fn GetPropertyList(comptime T: type) type {
    return fn (instance: *T) []PropertyInfo;
}

pub fn wrapGetPropertyList(comptime T: type, comptime callback: *const GetPropertyList(T)) Child(c.GDExtensionScriptInstanceGetPropertyList) {
    return struct {
        fn wrapped(p_instance: c.GDExtensionScriptInstanceDataPtr, r_count: [*c]u32) callconv(.c) [*c]const c.GDExtensionPropertyInfo {
            const instance = @as(*T, @ptrCast(@alignCast(p_instance)));
            const list = callback(instance);
            r_count.* = @intCast(list.len);
            if (list.len == 0) return null;
            return @ptrCast(list.ptr);
        }
    }.wrapped;
}

pub fn FreePropertyList(comptime T: type) type {
    return fn (instance: *T, list: [*]PropertyInfo) void;
}

pub fn wrapFreePropertyList(comptime T: type, comptime callback: *const FreePropertyList(T)) Child(c.GDExtensionScriptInstanceFreePropertyList) {
    return struct {
        fn wrapped(p_instance: c.GDExtensionScriptInstanceDataPtr, p_list: [*c]const c.GDExtensionPropertyInfo) callconv(.c) void {
            const instance = @as(*T, @ptrCast(@alignCast(p_instance)));
            if (p_list) |list| {
                callback(instance, @ptrCast(list));
            }
        }
    }.wrapped;
}

pub fn FreePropertyList2(comptime T: type) type {
    return fn (instance: *T, list: []const PropertyInfo) void;
}

pub fn wrapFreePropertyList2(comptime T: type, comptime callback: *const FreePropertyList2(T)) Child(c.GDExtensionScriptInstanceFreePropertyList2) {
    return struct {
        fn wrapped(p_instance: c.GDExtensionScriptInstanceDataPtr, p_list: [*c]const c.GDExtensionPropertyInfo, p_count: u32) callconv(.c) void {
            const instance = @as(*T, @ptrCast(@alignCast(p_instance)));
            if (p_list) |list| {
                const slice = @as([*]const PropertyInfo, @ptrCast(list))[0..p_count];
                callback(instance, slice);
            }
        }
    }.wrapped;
}

pub fn GetClassCategory(comptime T: type) type {
    return fn (instance: *T) ?PropertyInfo;
}

pub fn wrapGetClassCategory(comptime T: type, comptime callback: *const GetClassCategory(T)) Child(c.GDExtensionScriptInstanceGetClassCategory) {
    return struct {
        fn wrapped(p_instance: c.GDExtensionScriptInstanceDataPtr, p_class_category: [*c]c.GDExtensionPropertyInfo) callconv(.c) c.GDExtensionBool {
            const instance = @as(*T, @ptrCast(@alignCast(p_instance)));
            if (callback(instance)) |category| {
                p_class_category.* = @bitCast(category);
                return 1;
            }
            return 0;
        }
    }.wrapped;
}

pub fn GetPropertyType(comptime T: type) type {
    return fn (instance: *T, name: *const StringName) ?Variant.Tag;
}

pub fn wrapGetPropertyType(comptime T: type, comptime callback: *const GetPropertyType(T)) Child(c.GDExtensionScriptInstanceGetPropertyType) {
    return struct {
        fn wrapped(p_instance: c.GDExtensionScriptInstanceDataPtr, p_name: c.GDExtensionConstStringNamePtr, r_is_valid: [*c]c.GDExtensionBool) callconv(.c) c.GDExtensionVariantType {
            const instance = @as(*T, @ptrCast(@alignCast(p_instance)));
            const name = @as(*const StringName, @ptrCast(p_name));
            if (callback(instance, name)) |tag| {
                r_is_valid.* = 1;
                return @intFromEnum(tag);
            } else {
                r_is_valid.* = 0;
                return c.GDEXTENSION_VARIANT_TYPE_NIL;
            }
        }
    }.wrapped;
}

pub fn ValidateProperty(comptime T: type) type {
    return fn (instance: *T, property: *PropertyInfo) bool;
}

pub fn wrapValidateProperty(comptime T: type, comptime callback: *const ValidateProperty(T)) Child(c.GDExtensionScriptInstanceValidateProperty) {
    return struct {
        fn wrapped(p_instance: c.GDExtensionScriptInstanceDataPtr, p_property: [*c]c.GDExtensionPropertyInfo) callconv(.c) c.GDExtensionBool {
            const instance = @as(*T, @ptrCast(@alignCast(p_instance)));
            const property = @as(*PropertyInfo, @ptrCast(p_property));
            return if (callback(instance, property)) 1 else 0;
        }
    }.wrapped;
}

pub fn PropertyCanRevert(comptime T: type) type {
    return fn (instance: *T, name: *const StringName) bool;
}

pub fn wrapPropertyCanRevert(comptime T: type, comptime callback: *const PropertyCanRevert(T)) Child(c.GDExtensionScriptInstancePropertyCanRevert) {
    return struct {
        fn wrapped(p_instance: c.GDExtensionScriptInstanceDataPtr, p_name: c.GDExtensionConstStringNamePtr) callconv(.c) c.GDExtensionBool {
            const instance = @as(*T, @ptrCast(@alignCast(p_instance)));
            const name = @as(*const StringName, @ptrCast(p_name));
            return if (callback(instance, name)) 1 else 0;
        }
    }.wrapped;
}

pub fn PropertyGetRevert(comptime T: type) type {
    return fn (instance: *T, name: *const StringName) Error!Variant;
}

pub fn wrapPropertyGetRevert(comptime T: type, comptime callback: *const PropertyGetRevert(T)) Child(c.GDExtensionScriptInstancePropertyGetRevert) {
    return struct {
        fn wrapped(p_instance: c.GDExtensionScriptInstanceDataPtr, p_name: c.GDExtensionConstStringNamePtr, r_ret: c.GDExtensionVariantPtr) callconv(.c) c.GDExtensionBool {
            const instance = @as(*T, @ptrCast(@alignCast(p_instance)));
            const name = @as(*const StringName, @ptrCast(p_name));
            const ret = @as(*Variant, @ptrCast(@alignCast(r_ret)));
            ret.* = callback(instance, name) catch return 0;
            return 1;
        }
    }.wrapped;
}

pub fn GetOwner(comptime T: type) type {
    return fn (instance: *T) *Object;
}

pub fn wrapGetOwner(comptime T: type, comptime callback: *const GetOwner(T)) Child(c.GDExtensionScriptInstanceGetOwner) {
    return struct {
        fn wrapped(p_instance: c.GDExtensionScriptInstanceDataPtr) callconv(.c) c.GDExtensionObjectPtr {
            const instance = @as(*T, @ptrCast(@alignCast(p_instance)));
            return @ptrCast(callback(instance));
        }
    }.wrapped;
}

pub const PropertyStateAdd = fn (name: *const StringName, value: *const Variant, userdata: ?*anyopaque) void;

pub fn GetPropertyState(comptime T: type) type {
    return fn (instance: *T, add_func: *const PropertyStateAdd, userdata: ?*anyopaque) void;
}

pub fn wrapGetPropertyState(comptime T: type, comptime callback: *const GetPropertyState(T)) Child(c.GDExtensionScriptInstanceGetPropertyState) {
    return struct {
        fn wrapped(p_instance: c.GDExtensionScriptInstanceDataPtr, p_add_func: ?*const c.GDExtensionScriptInstancePropertyStateAdd, p_userdata: ?*anyopaque) callconv(.c) void {
            const instance = @as(*T, @ptrCast(@alignCast(p_instance)));
            if (p_add_func) |add_func| {
                callback(instance, @ptrCast(add_func), p_userdata);
            }
        }
    }.wrapped;
}

pub fn GetMethodList(comptime T: type) type {
    return fn (instance: *T) []MethodInfo;
}

pub fn wrapGetMethodList(comptime T: type, comptime callback: *const GetMethodList(T)) Child(c.GDExtensionScriptInstanceGetMethodList) {
    return struct {
        fn wrapped(p_instance: c.GDExtensionScriptInstanceDataPtr, r_count: [*c]u32) callconv(.c) [*c]const c.GDExtensionMethodInfo {
            const instance = @as(*T, @ptrCast(@alignCast(p_instance)));
            const list = callback(instance);
            r_count.* = @intCast(list.len);
            if (list.len == 0) return null;
            return @ptrCast(list.ptr);
        }
    }.wrapped;
}

pub fn FreeMethodList(comptime T: type) type {
    return fn (instance: *T, list: [*]MethodInfo) void;
}

pub fn wrapFreeMethodList(comptime T: type, comptime callback: *const FreeMethodList(T)) Child(c.GDExtensionScriptInstanceFreeMethodList) {
    return struct {
        fn wrapped(p_instance: c.GDExtensionScriptInstanceDataPtr, p_list: [*c]const c.GDExtensionMethodInfo) callconv(.c) void {
            const instance = @as(*T, @ptrCast(@alignCast(p_instance)));
            if (p_list) |list| {
                callback(instance, @ptrCast(list));
            }
        }
    }.wrapped;
}

pub fn FreeMethodList2(comptime T: type) type {
    return fn (instance: *T, list: []const MethodInfo) void;
}

pub fn wrapFreeMethodList2(comptime T: type, comptime callback: *const FreeMethodList2(T)) Child(c.GDExtensionScriptInstanceFreeMethodList2) {
    return struct {
        fn wrapped(p_instance: c.GDExtensionScriptInstanceDataPtr, p_list: [*c]const c.GDExtensionMethodInfo, p_count: u32) callconv(.c) void {
            const instance = @as(*T, @ptrCast(@alignCast(p_instance)));
            if (p_list) |list| {
                const slice = @as([*]const MethodInfo, @ptrCast(list))[0..p_count];
                callback(instance, slice);
            }
        }
    }.wrapped;
}

pub fn HasMethod(comptime T: type) type {
    return fn (instance: *T, name: *const StringName) bool;
}

pub fn wrapHasMethod(comptime T: type, comptime callback: *const HasMethod(T)) Child(c.GDExtensionScriptInstanceHasMethod) {
    return struct {
        fn wrapped(p_instance: c.GDExtensionScriptInstanceDataPtr, p_name: c.GDExtensionConstStringNamePtr) callconv(.c) c.GDExtensionBool {
            const instance = @as(*T, @ptrCast(@alignCast(p_instance)));
            const name = @as(*const StringName, @ptrCast(p_name));
            return if (callback(instance, name)) 1 else 0;
        }
    }.wrapped;
}

pub fn GetMethodArgumentCount(comptime T: type) type {
    return fn (instance: *T, name: *const StringName) ?i64;
}

pub fn wrapGetMethodArgumentCount(comptime T: type, comptime callback: *const GetMethodArgumentCount(T)) Child(c.GDExtensionScriptInstanceGetMethodArgumentCount) {
    return struct {
        fn wrapped(p_instance: c.GDExtensionScriptInstanceDataPtr, p_name: c.GDExtensionConstStringNamePtr, r_is_valid: [*c]c.GDExtensionBool) callconv(.c) c.GDExtensionInt {
            const instance = @as(*T, @ptrCast(@alignCast(p_instance)));
            const name = @as(*const StringName, @ptrCast(p_name));
            if (callback(instance, name)) |count| {
                r_is_valid.* = 1;
                return @intCast(count);
            }
            r_is_valid.* = 0;
            return 0;
        }
    }.wrapped;
}

pub fn Call(comptime T: type) type {
    return fn (instance: *T, method: *const StringName, args: []const *const Variant) CallError!Variant;
}

pub fn wrapCall(comptime T: type, comptime callback: *const Call(T)) Child(c.GDExtensionScriptInstanceCall) {
    return struct {
        fn wrapped(p_self: c.GDExtensionScriptInstanceDataPtr, p_method: c.GDExtensionConstStringNamePtr, p_args: [*c]const c.GDExtensionConstVariantPtr, p_argument_count: c.GDExtensionInt, r_return: c.GDExtensionVariantPtr, r_error: [*c]c.GDExtensionCallError) callconv(.c) void {
            const instance = @as(*T, @ptrCast(@alignCast(p_self)));
            const method = @as(*const StringName, @ptrCast(p_method));
            const args = @as([*]const *const Variant, @ptrCast(p_args))[0..@intCast(p_argument_count)];
            const ret = @as(*Variant, @ptrCast(@alignCast(r_return)));

            if (callback(instance, method, args)) |value| {
                ret.* = value;
                r_error.*.@"error" = c.GDEXTENSION_CALL_OK;
            } else |err| {
                r_error.*.@"error" = @intFromEnum(err.@"error");
                r_error.*.argument = err.argument;
                r_error.*.expected = err.expected;
            }
        }
    }.wrapped;
}

pub fn Notification(comptime T: type) type {
    return fn (instance: *T, what: i32) void;
}

pub fn wrapNotification(comptime T: type, comptime callback: *const Notification(T)) Child(c.GDExtensionScriptInstanceNotification) {
    return struct {
        fn wrapped(p_instance: c.GDExtensionScriptInstanceDataPtr, p_what: i32) callconv(.c) void {
            const instance = @as(*T, @ptrCast(@alignCast(p_instance)));
            callback(instance, p_what);
        }
    }.wrapped;
}

pub fn Notification2(comptime T: type) type {
    return fn (instance: *T, what: i32, reversed: bool) void;
}

pub fn wrapNotification2(comptime T: type, comptime callback: *const Notification2(T)) Child(c.GDExtensionScriptInstanceNotification2) {
    return struct {
        fn wrapped(p_instance: c.GDExtensionScriptInstanceDataPtr, p_what: i32, p_reversed: c.GDExtensionBool) callconv(.c) void {
            const instance = @as(*T, @ptrCast(@alignCast(p_instance)));
            callback(instance, p_what, p_reversed != 0);
        }
    }.wrapped;
}

pub fn ToString(comptime T: type) type {
    return fn (instance: *T) ?String;
}

pub fn wrapToString(comptime T: type, comptime callback: *const ToString(T)) Child(c.GDExtensionScriptInstanceToString) {
    return struct {
        fn wrapped(p_instance: c.GDExtensionScriptInstanceDataPtr, r_is_valid: [*c]c.GDExtensionBool, r_out: c.GDExtensionStringPtr) callconv(.c) void {
            const instance = @as(*T, @ptrCast(@alignCast(p_instance)));
            if (callback(instance)) |str| {
                @as(*String, @ptrCast(@alignCast(r_out))).* = str;
                r_is_valid.* = 1;
            } else {
                r_is_valid.* = 0;
            }
        }
    }.wrapped;
}

pub fn RefCountIncremented(comptime T: type) type {
    return fn (instance: *T) void;
}

pub fn wrapRefCountIncremented(comptime T: type, comptime callback: *const RefCountIncremented(T)) Child(c.GDExtensionScriptInstanceRefCountIncremented) {
    return struct {
        fn wrapped(p_instance: c.GDExtensionScriptInstanceDataPtr) callconv(.c) void {
            const instance = @as(*T, @ptrCast(@alignCast(p_instance)));
            callback(instance);
        }
    }.wrapped;
}

pub fn RefCountDecremented(comptime T: type) type {
    return fn (instance: *T) bool;
}

pub fn wrapRefCountDecremented(comptime T: type, comptime callback: *const RefCountDecremented(T)) Child(c.GDExtensionScriptInstanceRefCountDecremented) {
    return struct {
        fn wrapped(p_instance: c.GDExtensionScriptInstanceDataPtr) callconv(.c) c.GDExtensionBool {
            const instance = @as(*T, @ptrCast(@alignCast(p_instance)));
            return if (callback(instance)) 1 else 0;
        }
    }.wrapped;
}

pub fn GetScript(comptime T: type) type {
    return fn (instance: *T) *Object;
}

pub fn wrapGetScript(comptime T: type, comptime callback: *const GetScript(T)) Child(c.GDExtensionScriptInstanceGetScript) {
    return struct {
        fn wrapped(p_instance: c.GDExtensionScriptInstanceDataPtr) callconv(.c) c.GDExtensionObjectPtr {
            const instance = @as(*T, @ptrCast(@alignCast(p_instance)));
            return @ptrCast(callback(instance));
        }
    }.wrapped;
}

pub fn IsPlaceholder(comptime T: type) type {
    return fn (instance: *T) bool;
}

pub fn wrapIsPlaceholder(comptime T: type, comptime callback: *const IsPlaceholder(T)) Child(c.GDExtensionScriptInstanceIsPlaceholder) {
    return struct {
        fn wrapped(p_instance: c.GDExtensionScriptInstanceDataPtr) callconv(.c) c.GDExtensionBool {
            const instance = @as(*T, @ptrCast(@alignCast(p_instance)));
            return if (callback(instance)) 1 else 0;
        }
    }.wrapped;
}

pub fn GetLanguage(comptime T: type) type {
    return fn (instance: *T) *ScriptLanguage;
}

pub fn wrapGetLanguage(comptime T: type, comptime callback: *const GetLanguage(T)) Child(c.GDExtensionScriptInstanceGetLanguage) {
    return struct {
        fn wrapped(p_instance: c.GDExtensionScriptInstanceDataPtr) callconv(.c) c.GDExtensionScriptLanguagePtr {
            const instance = @as(*T, @ptrCast(@alignCast(p_instance)));
            return @ptrCast(callback(instance));
        }
    }.wrapped;
}

pub fn Free(comptime T: type) type {
    return fn (instance: *T) void;
}

pub fn wrapFree(comptime T: type, comptime callback: *const Free(T)) Child(c.GDExtensionScriptInstanceFree) {
    return struct {
        fn wrapped(p_instance: c.GDExtensionScriptInstanceDataPtr) callconv(.c) void {
            const instance = @as(*T, @ptrCast(@alignCast(p_instance)));
            callback(instance);
        }
    }.wrapped;
}

const std = @import("std");
const Child = std.meta.Child;

const c = @import("gdextension");

const api = @import("../api.zig");
const PropertyInfo = api.PropertyInfo;
const CallError = api.CallError;
const Error = api.Error;
const builtin = @import("../builtin.zig");
const StringName = builtin.StringName;
const String = builtin.String;
const Variant = builtin.Variant;
const Array = builtin.Array;
const Dictionary = builtin.Dictionary;
const class = @import("../class.zig");
const Object = class.Object;
const Script = class.Script;
const ScriptExtension = class.ScriptExtension;
const ScriptLanguage = class.ScriptLanguage;
const global = @import("../global.zig");
const MethodFlags = global.MethodFlags;
const Interface = @import("../Interface.zig");
