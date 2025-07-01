pub const ObjectInstanceID = enum(u64) {
    pub const zero: ObjectInstanceID = @enumFromInt(0);
    _,
};

pub const MethodFlags = packed struct {
    normal: bool = true,
    editor: bool = false,
    @"const": bool = false,
    virtual: bool = false,
    vararg: bool = false,
    static: bool = false,

    pub const default: MethodFlags = .{};
};

pub const MethodArgumentMetadata = enum(u32) {
    none = 0,
    int_is_int_8 = 1,
    int_is_int_16 = 2,
    int_is_int_32 = 3,
    int_is_int_64 = 4,
    int_is_uint_8 = 5,
    int_is_uint_16 = 6,
    int_is_uint_32 = 7,
    int_is_uint_64 = 8,
    real_is_float = 9,
    real_is_double = 10,
    int_is_char_16 = 11,
    int_is_char_32 = 12,
};

pub const InitializationLevel = enum(u32) {
    core = 0,
    servers = 1,
    scene = 2,
    editor = 3,
    max = 4,
};

pub const CallError = struct {
    err: Type = .ok,
    argument: i32 = 0,
    expected: i32 = 0,

    pub const Type = enum(u32) {
        ok = 0,
        invalid_method = 1,
        invalid_argument = 2,
        too_many_arguments = 3,
        too_few_arguments = 4,
        instance_is_null = 5,
        method_not_const = 6,
    };
};

pub const InstanceBindingCallbacks = struct {
    create_callback: ?InstanceBindingCreateCallback = null,
    free_callback: ?InstanceBindingFreeCallback = null,
    reference_callback: ?InstanceBindingReferenceCallback = null,
};

pub const PropertyInfo = struct {
    type: Variant.Tag = .nil,
    name: ?*const StringName = null,
    class_name: ?*const StringName = null,
    hint: PropertyHint = .property_hint_none,
    hint_string: ?*const String = null,
    usage: PropertyUsageFlags = .{},
};

pub const MethodInfo = struct {
    name: ?*const StringName = null,
    return_value: PropertyInfo = .{},
    flags: MethodFlags = .default,
    id: i32 = 0,
    arguments: []PropertyInfo = &.{},
    default_arguments: []*Variant = &.{},
};

pub const ClassCreationInfo = struct {
    is_virtual: bool = false,
    is_abstract: bool = false,
    set_func: ?ClassSet = null,
    get_func: ?ClassGet = null,
    get_property_list_func: ?ClassGetPropertyList = null,
    free_property_list_func: ?ClassFreePropertyList = null,
    property_can_revert_func: ?ClassPropertyCanRevert = null,
    property_get_revert_func: ?ClassPropertyGetRevert = null,
    notification_func: ?ClassNotification = null,
    to_string_func: ?ClassToString = null,
    reference_func: ?ClassReference = null,
    unreference_func: ?ClassUnreference = null,
    create_instance_func: ?ClassCreateInstance = null,
    free_instance_func: ?ClassFreeInstance = null,
    get_virtual_func: ?ClassGetVirtual = null,
    get_rid_func: ?ClassGetRID = null,
    class_userdata: ?*anyopaque = null,
};

pub const ClassCreationInfo2 = struct {
    is_virtual: bool = false,
    is_abstract: bool = false,
    is_exposed: bool = false,
    set_func: ?ClassSet = null,
    get_func: ?ClassGet = null,
    get_property_list_func: ?ClassGetPropertyList = null,
    free_property_list_func: ?ClassFreePropertyList = null,
    property_can_revert_func: ?ClassPropertyCanRevert = null,
    property_get_revert_func: ?ClassPropertyGetRevert = null,
    validate_property_func: ?ClassValidateProperty = null,
    notification_func: ?ClassNotification2 = null,
    to_string_func: ?ClassToString = null,
    reference_func: ?ClassReference = null,
    unreference_func: ?ClassUnreference = null,
    create_instance_func: ?ClassCreateInstance = null,
    free_instance_func: ?ClassFreeInstance = null,
    recreate_instance_func: ?ClassRecreateInstance = null,
    get_virtual_func: ?ClassGetVirtual = null,
    get_virtual_call_data_func: ?ClassGetVirtualCallData = null,
    call_virtual_with_data_func: ?ClassCallVirtualWithData = null,
    get_rid_func: ?ClassGetRID = null,
    class_userdata: ?*anyopaque = null,
};

pub const ClassCreationInfo3 = struct {
    is_virtual: bool = false,
    is_abstract: bool = false,
    is_exposed: bool = false,
    is_runtime: bool = false,
    set_func: ?ClassSet = null,
    get_func: ?ClassGet = null,
    get_property_list_func: ?ClassGetPropertyList = null,
    free_property_list_func: ?ClassFreePropertyList2 = null,
    property_can_revert_func: ?ClassPropertyCanRevert = null,
    property_get_revert_func: ?ClassPropertyGetRevert = null,
    validate_property_func: ?ClassValidateProperty = null,
    notification_func: ?ClassNotification2 = null,
    to_string_func: ?ClassToString = null,
    reference_func: ?ClassReference = null,
    unreference_func: ?ClassUnreference = null,
    create_instance_func: ?ClassCreateInstance = null,
    free_instance_func: ?ClassFreeInstance = null,
    recreate_instance_func: ?ClassRecreateInstance = null,
    get_virtual_func: ?ClassGetVirtual = null,
    get_virtual_call_data_func: ?ClassGetVirtualCallData = null,
    call_virtual_with_data_func: ?ClassCallVirtualWithData = null,
    get_rid_func: ?ClassGetRID = null,
    class_userdata: ?*anyopaque = null,
};

pub const ClassCreationInfo4 = struct {
    is_virtual: bool = false,
    is_abstract: bool = false,
    is_exposed: bool = false,
    is_runtime: bool = false,
    icon_path: ?*const String = null,
    set_func: ?ClassSet = null,
    get_func: ?ClassGet = null,
    get_property_list_func: ?ClassGetPropertyList = null,
    free_property_list_func: ?ClassFreePropertyList2 = null,
    property_can_revert_func: ?ClassPropertyCanRevert = null,
    property_get_revert_func: ?ClassPropertyGetRevert = null,
    validate_property_func: ?ClassValidateProperty = null,
    notification_func: ?ClassNotification2 = null,
    to_string_func: ?ClassToString = null,
    reference_func: ?ClassReference = null,
    unreference_func: ?ClassUnreference = null,
    create_instance_func: ?ClassCreateInstance2 = null,
    free_instance_func: ?ClassFreeInstance = null,
    recreate_instance_func: ?ClassRecreateInstance = null,
    get_virtual_func: ?ClassGetVirtual2 = null,
    get_virtual_call_data_func: ?ClassGetVirtualCallData2 = null,
    call_virtual_with_data_func: ?ClassCallVirtualWithData = null,
    class_userdata: ?*anyopaque = null,
};

pub const ClassMethodInfo = struct {
    name: ?*const StringName = null,
    method_userdata: ?*anyopaque = null,
    call_func: ?ClassMethodCall = null,
    ptrcall_func: ?ClassMethodPtrCall = null,
    method_flags: MethodFlags = .default,
    has_return_value: bool = false,
    return_value_info: ?*const PropertyInfo = null,
    return_value_metadata: ?*const MethodArgumentMetadata = null,
    argument_info: []*const PropertyInfo = &.{},
    argument_meta: []*const MethodArgumentMetadata = &.{},
    default_arguments: []*const Variant = &.{},
};

pub const ClassVirtualMethodInfo = struct {
    name: ?*const StringName = null,
    method_flags: MethodFlags = .default,
    return_value: PropertyInfo = .{},
    return_value_metadata: MethodArgumentMetadata = .none,
    argument_info: []*const PropertyInfo = &.{},
    argument_metadata: []*const MethodArgumentMetadata = &.{},
};

pub const CallableCustomInfo = struct {
    callable_userdata: ?*anyopaque = null,
    token: ?*anyopaque = null,
    object_id: ObjectInstanceID = .zero,
    call_func: ?CallableCustomCall = null,
    is_valid_func: ?CallableCustomIsValid = null,
    free_func: ?CallableCustomFree = null,
    hash_func: ?CallableCustomHash = null,
    equal_func: ?CallableCustomEqual = null,
    less_than_func: ?CallableCustomLessThan = null,
    to_string_func: ?CallableCustomToString = null,
};

pub const CallableCustomInfo2 = struct {
    callable_userdata: ?*anyopaque = null,
    token: ?*anyopaque = null,
    object_id: ObjectInstanceID = .zero,
    call_func: ?CallableCustomCall = null,
    is_valid_func: ?CallableCustomIsValid = null,
    free_func: ?CallableCustomFree = null,
    hash_func: ?CallableCustomHash = null,
    equal_func: ?CallableCustomEqual = null,
    less_than_func: ?CallableCustomLessThan = null,
    to_string_func: ?CallableCustomToString = null,
    get_argument_count_func: ?CallableCustomGetArgumentCount = null,
};

pub const ScriptInstanceInfo = struct {
    set_func: ?ScriptInstanceSet = null,
    get_func: ?ScriptInstanceGet = null,
    get_property_list_func: ?ScriptInstanceGetPropertyList = null,
    free_property_list_func: ?ScriptInstanceFreePropertyList = null,
    property_can_revert_func: ?ScriptInstancePropertyCanRevert = null,
    property_get_revert_func: ?ScriptInstancePropertyGetRevert = null,
    get_owner_func: ?ScriptInstanceGetOwner = null,
    get_property_state_func: ?ScriptInstanceGetPropertyState = null,
    get_method_list_func: ?ScriptInstanceGetMethodList = null,
    free_method_list_func: ?ScriptInstanceFreeMethodList = null,
    get_property_type_func: ?ScriptInstanceGetPropertyType = null,
    has_method_func: ?ScriptInstanceHasMethod = null,
    call_func: ?ScriptInstanceCall = null,
    notification_func: ?ScriptInstanceNotification = null,
    to_string_func: ?ScriptInstanceToString = null,
    refcount_incremented_func: ?ScriptInstanceRefCountIncremented = null,
    refcount_decremented_func: ?ScriptInstanceRefCountDecremented = null,
    get_script_func: ?ScriptInstanceGetScript = null,
    is_placeholder_func: ?ScriptInstanceIsPlaceholder = null,
    set_fallback_func: ?ScriptInstanceSet = null,
    get_fallback_func: ?ScriptInstanceGet = null,
    get_language_func: ?ScriptInstanceGetLanguage = null,
    free_func: ?ScriptInstanceFree = null,
};

pub const ScriptInstanceInfo2 = struct {
    set_func: ?ScriptInstanceSet = null,
    get_func: ?ScriptInstanceGet = null,
    get_property_list_func: ?ScriptInstanceGetPropertyList = null,
    free_property_list_func: ?ScriptInstanceFreePropertyList = null,
    get_class_category_func: ?ScriptInstanceGetClassCategory = null,
    property_can_revert_func: ?ScriptInstancePropertyCanRevert = null,
    property_get_revert_func: ?ScriptInstancePropertyGetRevert = null,
    get_owner_func: ?ScriptInstanceGetOwner = null,
    get_property_state_func: ?ScriptInstanceGetPropertyState = null,
    get_method_list_func: ?ScriptInstanceGetMethodList = null,
    free_method_list_func: ?ScriptInstanceFreeMethodList = null,
    get_property_type_func: ?ScriptInstanceGetPropertyType = null,
    validate_property_func: ?ScriptInstanceValidateProperty = null,
    has_method_func: ?ScriptInstanceHasMethod = null,
    call_func: ?ScriptInstanceCall = null,
    notification_func: ?ScriptInstanceNotification2 = null,
    to_string_func: ?ScriptInstanceToString = null,
    refcount_incremented_func: ?ScriptInstanceRefCountIncremented = null,
    refcount_decremented_func: ?ScriptInstanceRefCountDecremented = null,
    get_script_func: ?ScriptInstanceGetScript = null,
    is_placeholder_func: ?ScriptInstanceIsPlaceholder = null,
    set_fallback_func: ?ScriptInstanceSet = null,
    get_fallback_func: ?ScriptInstanceGet = null,
    get_language_func: ?ScriptInstanceGetLanguage = null,
    free_func: ?ScriptInstanceFree = null,
};

pub const ScriptInstanceInfo3 = struct {
    set_func: ?ScriptInstanceSet = null,
    get_func: ?ScriptInstanceGet = null,
    get_property_list_func: ?ScriptInstanceGetPropertyList = null,
    free_property_list_func: ?ScriptInstanceFreePropertyList2 = null,
    get_class_category_func: ?ScriptInstanceGetClassCategory = null,
    property_can_revert_func: ?ScriptInstancePropertyCanRevert = null,
    property_get_revert_func: ?ScriptInstancePropertyGetRevert = null,
    get_owner_func: ?ScriptInstanceGetOwner = null,
    get_property_state_func: ?ScriptInstanceGetPropertyState = null,
    get_method_list_func: ?ScriptInstanceGetMethodList = null,
    free_method_list_func: ?ScriptInstanceFreeMethodList2 = null,
    get_property_type_func: ?ScriptInstanceGetPropertyType = null,
    validate_property_func: ?ScriptInstanceValidateProperty = null,
    has_method_func: ?ScriptInstanceHasMethod = null,
    get_method_argument_count_func: ?ScriptInstanceGetMethodArgumentCount = null,
    call_func: ?ScriptInstanceCall = null,
    notification_func: ?ScriptInstanceNotification2 = null,
    to_string_func: ?ScriptInstanceToString = null,
    refcount_incremented_func: ?ScriptInstanceRefCountIncremented = null,
    refcount_decremented_func: ?ScriptInstanceRefCountDecremented = null,
    get_script_func: ?ScriptInstanceGetScript = null,
    is_placeholder_func: ?ScriptInstanceIsPlaceholder = null,
    set_fallback_func: ?ScriptInstanceSet = null,
    get_fallback_func: ?ScriptInstanceGet = null,
    get_language_func: ?ScriptInstanceGetLanguage = null,
    free_func: ?ScriptInstanceFree = null,
};

pub const Initialization = struct {
    minimum_initialization_level: InitializationLevel = .core,
    userdata: ?*anyopaque = null,
    initialize: ?*const fn (?*anyopaque, InitializationLevel) void = null,
    deinitialize: ?*const fn (?*anyopaque, InitializationLevel) void = null,
};

pub const GodotVersion = struct {
    major: u32 = 0,
    minor: u32 = 0,
    patch: u32 = 0,
    string: [:0]const u8 = "",
};

const std = @import("std");
const MultiArrayList = std.MultiArrayList;

const c = @import("gdextension");

const godot = @import("gdzig.zig");
const PropertyHint = godot.global.PropertyHint;
const PropertyUsageFlags = godot.global.PropertyUsageFlags;
const String = godot.builtin.String;
const StringName = godot.builtin.StringName;
const Variant = godot.builtin.Variant;
