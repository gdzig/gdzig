pub fn MethodInfo(comptime Userdata: type) type {
    return if (Userdata != void)
        struct {
            userdata: *Userdata,
            name: *StringName,
            flags: MethodFlags,
            has_return_value: bool,
            return_value_info: *PropertyInfo,
            return_value_metadata: MethodArgumentMetadata,
            argument_info: []PropertyInfo,
            argument_metadata: []MethodArgumentMetadata,
            default_arguments: []*Variant,
        }
    else
        struct {
            name: *StringName,
            flags: MethodFlags,
            has_return_value: bool,
            return_value_info: *PropertyInfo,
            return_value_metadata: MethodArgumentMetadata,
            argument_info: []PropertyInfo,
            argument_metadata: []MethodArgumentMetadata,
            default_arguments: []*Variant,
        };
}

pub fn MethodCallbacks(comptime T: type, comptime Userdata: type) type {
    return struct {
        call: ?*const Call(T, Userdata) = null,
        ptr_call: ?*const PtrCall(T, Userdata) = null,
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

pub const VirtualMethodInfo = struct {
    name: *StringName,
    flags: MethodFlags,
    return_value: PropertyInfo,
    return_value_metadata: MethodArgumentMetadata,
    arguments: []PropertyInfo,
    argument_metadata: []MethodArgumentMetadata,
};

pub fn Call(comptime T: type, comptime Userdata: type) type {
    return if (Userdata != void)
        fn (userdata: *Userdata, instance: *T, args: []const *const Variant) CallError!Variant
    else
        fn (instance: *T, args: []const *const Variant) CallError!Variant;
}

pub fn wrapCall(comptime T: type, comptime Userdata: type, comptime original: *const Call(T, Userdata)) Child(c.GDExtensionClassMethodCall) {
    return struct {
        fn wrapped(method_userdata: ?*anyopaque, p_instance: c.GDExtensionClassInstancePtr, p_args: [*c]const c.GDExtensionConstVariantPtr, p_argument_count: c.GDExtensionInt, r_return: c.GDExtensionVariantPtr, r_error: *c.GDExtensionCallError) callconv(.c) void {
            const instance = @as(*T, @ptrCast(@alignCast(p_instance)));
            const args = @as([*]const *const Variant, @ptrCast(p_args))[0..@intCast(p_argument_count)];
            const ret = @as(*Variant, @ptrCast(@alignCast(r_return)));

            const result = if (Userdata != void) blk: {
                const userdata = @as(*Userdata, @ptrCast(@alignCast(method_userdata)));
                break :blk original(userdata, instance, args);
            } else original(instance, args);

            if (result) |value| {
                ret.* = value;
                r_error.*.@"error" = c.GDEXTENSION_CALL_OK;
            } else |err| {
                r_error.*.@"error" = c.GDEXTENSION_CALL_ERROR_INVALID_METHOD;
                _ = err;
            }
        }
    }.wrapped;
}

pub fn PtrCall(comptime T: type, comptime Userdata: type) type {
    return if (Userdata != void)
        fn (userdata: *Userdata, instance: *T, args: [*]const *const anyopaque, ret: *anyopaque) void
    else
        fn (instance: *T, args: [*]const *const anyopaque, ret: *anyopaque) void;
}

pub fn wrapPtrCall(comptime T: type, comptime Userdata: type, comptime original: *const PtrCall(T, Userdata)) Child(c.GDExtensionClassMethodPtrCall) {
    return struct {
        fn wrapped(method_userdata: ?*anyopaque, p_instance: c.GDExtensionClassInstancePtr, p_args: [*c]const c.GDExtensionConstTypePtr, r_ret: c.GDExtensionTypePtr) callconv(.c) void {
            const instance = @as(*T, @ptrCast(@alignCast(p_instance)));

            if (Userdata != void) {
                const userdata = @as(*Userdata, @ptrCast(@alignCast(method_userdata)));
                original(userdata, instance, @ptrCast(p_args), @ptrCast(r_ret));
            } else {
                original(instance, @ptrCast(p_args), @ptrCast(r_ret));
            }
        }
    }.wrapped;
}

const std = @import("std");
const Child = std.meta.Child;

const c = @import("gdextension");

const api = @import("../../api.zig");
const PropertyInfo = api.PropertyInfo;
const CallError = api.CallError;
const Error = api.Error;
const builtin = @import("../../builtin.zig");
const StringName = builtin.StringName;
const String = builtin.String;
const Variant = builtin.Variant;
const class = @import("../../class.zig");
const Object = class.Object;
const global = @import("../../global.zig");
const MethodFlags = global.MethodFlags;
const Interface = @import("../../Interface.zig");
const ClassLibrary = Interface.ClassLibrary;
