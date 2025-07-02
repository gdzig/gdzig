pub const ObjectInstanceID = enum(u64) {
    pub const none: ObjectInstanceID = @enumFromInt(0);
    _,
};

pub const MethodFlags = packed struct {
    normal: bool = true,
    editor: bool = false,
    @"const": bool = false,
    virtual: bool = false,
    vararg: bool = false,
    static: bool = false,
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

pub const GodotVersion = struct {
    major: u32 = 0,
    minor: u32 = 0,
    patch: u32 = 0,
    string: [:0]const u8 = "",
};

pub const PropertyInfo = struct {
    type: Variant.Tag = .nil,
    name: *const StringName,
    class_name: *const StringName,
    hint: PropertyHint = .property_hint_none,
    hint_string: ?*const String = null,
    usage: PropertyUsageFlags = .{},
};

pub const MethodInfo = struct {
    name: *const StringName,
    return_value: PropertyInfo = .{},
    flags: MethodFlags = .default,
    id: i32,
    arguments: []PropertyInfo = &.{},
    default_arguments: []Variant = &.{},
};

pub fn ClassInfo(comptime T: type, comptime U: type) type {
    return struct {
        is_virtual: bool = false,
        is_abstract: bool = false,
        is_exposed: bool = false,
        is_runtime: bool = false,
        icon_path: String,
        set: ?*const fn (self: *T, name: *const StringName, value: *const Variant) bool = null,
        get: ?*const fn (self: *const T, name: *const StringName, ret: *Variant) bool = null,
        get_property_list: ?*const fn (self: *const T) []PropertyInfo = null,
        free_property_list: ?*const fn (self: *const T, list: []PropertyInfo) void = null,
        property_can_revert: ?*const fn (self: *const T, name: *const StringName) bool = null,
        property_get_revert: ?*const fn (self: *const T, name: *const StringName) anyerror!Variant = null,
        validate_property: ?*const fn (self: *const T, property: *PropertyInfo) bool = null,
        notification: ?*const fn (self: *const T, what: i32, reversed: bool) void = null,
        to_string: ?*const fn (self: *const T) anyerror!String = null,
        reference: ?*const fn (self: *T) void = null,
        unreference: ?*const fn (self: *T) void = null,
        create: *const fn (userdata: *U, notify_postinitialized: bool) *T = null,
        free: *const fn (userdata: *U, instance: *T) void = null,
        recreate: ?*const fn (userdata: *U, object: Object) *T = null,
        get_virtual: ?*const fn (userdata: *U, name: *const StringName, hash: u32) ?*const FnCallVirtual = null,
        // get_virtual_call_data: ?*const fn (userdata: *Userdata, *const StringName, u32) ?*anyopaque = null,
        // call_virtual_with_data: ?*const fn (GDExtensionClassInstancePtr, *const StringName, ?*anyopaque, [*c]const GDExtensionConstTypePtr, GDExtensionTypePtr) void = null,

        userdata: *U = null,

        pub const FnCallVirtual = fn (self: *T, args: anytype, ret: *anyopaque) void;
    };
}

const std = @import("std");
const MultiArrayList = std.MultiArrayList;

const c = @import("gdextension");

const godot = @import("gdzig.zig");
const Object = godot.class.Object;
const PropertyHint = godot.global.PropertyHint;
const PropertyUsageFlags = godot.global.PropertyUsageFlags;
const String = godot.builtin.String;
const StringName = godot.builtin.StringName;
const Variant = godot.builtin.Variant;
