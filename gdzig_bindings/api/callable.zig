const raw: *Interface = &@import("../../gdzig_bindings.zig").raw;

pub fn CallableInfo1(comptime Userdata: type) type {
    return if (Userdata != void)
        struct {
            userdata: *Userdata,
            library: *ClassLibrary,
            object_id: OptionalObjectID = .none,
        }
    else
        struct {
            library: *ClassLibrary,
            object_id: OptionalObjectID = .none,
        };
}

pub fn CallableInfo2(comptime Userdata: type) type {
    return if (Userdata != void)
        struct {
            userdata: *Userdata,
            library: *ClassLibrary,
            object_id: OptionalObjectID = .none,
        }
    else
        struct {
            library: *ClassLibrary,
            object_id: OptionalObjectID = .none,
        };
}

pub fn CallableCallbacks1(comptime Userdata: type) type {
    return struct {
        call: *const Call(Userdata),
        is_valid: ?*const IsValid(Userdata) = null,
        free: ?*const Free(Userdata) = null,
        hash: ?*const Hash(Userdata) = null,
        equal: ?*const Equal(Userdata) = null,
        less_than: ?*const LessThan(Userdata) = null,
        to_string: ?*const ToString(Userdata) = null,
    };
}

pub fn CallableCallbacks2(comptime Userdata: type) type {
    return struct {
        call: *const Call(Userdata),
        is_valid: ?*const IsValid(Userdata) = null,
        free: ?*const Free(Userdata) = null,
        hash: ?*const Hash(Userdata) = null,
        equal: ?*const Equal(Userdata) = null,
        less_than: ?*const LessThan(Userdata) = null,
        to_string: ?*const ToString(Userdata) = null,
        get_argument_count: ?*const GetArgumentCount(Userdata) = null,
    };
}

pub fn Call(comptime CallableUserdata: type) type {
    if (CallableUserdata != void) {
        return fn (userdata: *CallableUserdata, args: []const *const Variant) CallError!Variant;
    } else {
        return fn (args: []const *const Variant) CallError!Variant;
    }
}

pub fn wrapCall(comptime CallableUserdata: type, comptime callback: *const Call(CallableUserdata)) Child(c.GDExtensionCallableCustomCall) {
    return struct {
        fn wrapped(p_callable_userdata: ?*anyopaque, p_args: [*c]const c.GDExtensionConstVariantPtr, p_argument_count: c.GDExtensionInt, r_return: c.GDExtensionVariantPtr, r_error: *c.GDExtensionCallError) callconv(.c) void {
            const args = @as([*]const *const Variant, @ptrCast(p_args))[0..@intCast(p_argument_count)];
            const ret = @as(*Variant, @ptrCast(@alignCast(r_return)));

            const result = if (CallableUserdata != void) blk: {
                const userdata = @as(*CallableUserdata, @ptrCast(@alignCast(p_callable_userdata)));
                break :blk callback(userdata, args);
            } else callback(args);

            if (result) |value| {
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

pub fn IsValid(comptime CallableUserdata: type) type {
    if (CallableUserdata != void) {
        return fn (userdata: *CallableUserdata) bool;
    } else {
        return fn () bool;
    }
}

pub fn wrapIsValid(comptime CallableUserdata: type, comptime callback: *const IsValid(CallableUserdata)) Child(c.GDExtensionCallableCustomIsValid) {
    return struct {
        fn wrapped(p_callable_userdata: ?*anyopaque) callconv(.c) c.GDExtensionBool {
            if (CallableUserdata != void) {
                const userdata = @as(*CallableUserdata, @ptrCast(@alignCast(p_callable_userdata)));
                return if (callback(userdata)) 1 else 0;
            } else {
                return if (callback()) 1 else 0;
            }
        }
    }.wrapped;
}

pub fn Free(comptime CallableUserdata: type) type {
    if (CallableUserdata != void) {
        return fn (userdata: *CallableUserdata) void;
    } else {
        return fn () void;
    }
}

pub fn wrapFree(comptime CallableUserdata: type, comptime callback: *const Free(CallableUserdata)) Child(c.GDExtensionCallableCustomFree) {
    return struct {
        fn wrapped(p_callable_userdata: ?*anyopaque) callconv(.c) void {
            if (CallableUserdata != void) {
                const userdata = @as(*CallableUserdata, @ptrCast(@alignCast(p_callable_userdata)));
                callback(userdata);
            } else {
                callback();
            }
        }
    }.wrapped;
}

pub fn Hash(comptime CallableUserdata: type) type {
    if (CallableUserdata != void) {
        return fn (userdata: *CallableUserdata) u32;
    } else {
        return fn () u32;
    }
}

pub fn wrapHash(comptime CallableUserdata: type, comptime callback: *const Hash(CallableUserdata)) Child(c.GDExtensionCallableCustomHash) {
    return struct {
        fn wrapped(p_callable_userdata: ?*anyopaque) callconv(.c) u32 {
            if (CallableUserdata != void) {
                const userdata = @as(*CallableUserdata, @ptrCast(@alignCast(p_callable_userdata)));
                return callback(userdata);
            } else {
                return callback();
            }
        }
    }.wrapped;
}

pub fn Equal(comptime CallableUserdata: type) type {
    if (CallableUserdata != void) {
        return fn (userdata_a: *CallableUserdata, userdata_b: *CallableUserdata) bool;
    } else {
        return fn () bool;
    }
}

pub fn wrapEqual(comptime CallableUserdata: type, comptime callback: *const Equal(CallableUserdata)) Child(c.GDExtensionCallableCustomEqual) {
    return struct {
        fn wrapped(p_callable_userdata_a: ?*anyopaque, p_callable_userdata_b: ?*anyopaque) callconv(.c) c.GDExtensionBool {
            if (CallableUserdata != void) {
                const userdata_a = @as(*CallableUserdata, @ptrCast(@alignCast(p_callable_userdata_a)));
                const userdata_b = @as(*CallableUserdata, @ptrCast(@alignCast(p_callable_userdata_b)));
                return if (callback(userdata_a, userdata_b)) 1 else 0;
            } else {
                return if (callback()) 1 else 0;
            }
        }
    }.wrapped;
}

pub fn LessThan(comptime CallableUserdata: type) type {
    if (CallableUserdata != void) {
        return fn (userdata_a: *CallableUserdata, userdata_b: *CallableUserdata) bool;
    } else {
        return fn () bool;
    }
}

pub fn wrapLessThan(comptime CallableUserdata: type, comptime callback: *const LessThan(CallableUserdata)) Child(c.GDExtensionCallableCustomLessThan) {
    return struct {
        fn wrapped(p_callable_userdata_a: ?*anyopaque, p_callable_userdata_b: ?*anyopaque) callconv(.c) c.GDExtensionBool {
            if (CallableUserdata != void) {
                const userdata_a = @as(*CallableUserdata, @ptrCast(@alignCast(p_callable_userdata_a)));
                const userdata_b = @as(*CallableUserdata, @ptrCast(@alignCast(p_callable_userdata_b)));
                return if (callback(userdata_a, userdata_b)) 1 else 0;
            } else {
                return if (callback()) 1 else 0;
            }
        }
    }.wrapped;
}

pub fn ToString(comptime CallableUserdata: type) type {
    if (CallableUserdata != void) {
        return fn (userdata: *CallableUserdata) Error!String;
    } else {
        return fn () Error!String;
    }
}

pub fn wrapToString(comptime CallableUserdata: type, comptime callback: *const ToString(CallableUserdata)) Child(c.GDExtensionCallableCustomToString) {
    return struct {
        fn wrapped(p_callable_userdata: ?*anyopaque, r_is_valid: *c.GDExtensionBool, p_out: c.GDExtensionStringPtr) callconv(.c) void {
            const out = @as(*String, @ptrCast(@alignCast(p_out)));

            const result = if (CallableUserdata != void) blk: {
                const userdata = @as(*CallableUserdata, @ptrCast(@alignCast(p_callable_userdata)));
                break :blk callback(userdata);
            } else callback();

            if (result) |str| {
                out.* = str;
                r_is_valid.* = 1;
            } else |_| {
                r_is_valid.* = 0;
            }
        }
    }.wrapped;
}

pub fn GetArgumentCount(comptime CallableUserdata: type) type {
    if (CallableUserdata != void) {
        return fn (userdata: *CallableUserdata) Error!c.GDExtensionInt;
    } else {
        return fn () Error!c.GDExtensionInt;
    }
}

pub fn wrapGetArgumentCount(comptime CallableUserdata: type, comptime callback: *const GetArgumentCount(CallableUserdata)) Child(c.GDExtensionCallableCustomGetArgumentCount) {
    return struct {
        fn wrapped(p_callable_userdata: ?*anyopaque, r_count: *c.GDExtensionInt) callconv(.c) c.GDExtensionBool {
            const result = if (CallableUserdata != void) blk: {
                const userdata = @as(*CallableUserdata, @ptrCast(@alignCast(p_callable_userdata)));
                break :blk callback(userdata);
            } else callback();

            if (result) |count| {
                r_count.* = count;
                return 1;
            } else |_| {
                return 0;
            }
        }
    }.wrapped;
}

/// **Deprecated** in Godot 4.3. Use `callableCustomCreate2` instead.
///
/// Creates a custom Callable object from a function pointer.
///
/// Provided struct can be safely freed once the function returns.
///
/// @param info The info required to construct a Callable.
///
/// @return The newly created Callable.
///
/// @since 4.2
pub inline fn callableCustomCreate(
    comptime CallableUserdata: type,
    info: *const CallableInfo1(CallableUserdata),
    comptime callbacks: *const CallableCallbacks1(CallableUserdata),
) Callable {
    var result: Callable = undefined;

    const c_info = c.GDExtensionCallableCustomInfo{
        .callable_userdata = if (CallableUserdata != void) @ptrCast(info.userdata) else null,
        .library = @ptrCast(info.library),
        .object_id = @bitCast(info.object_id),
        .call_func = @ptrCast(&wrapCall(CallableUserdata, callbacks.call)),
        .is_valid_func = if (callbacks.is_valid) |f| @ptrCast(&wrapIsValid(CallableUserdata, f)) else null,
        .free_func = if (callbacks.free) |f| @ptrCast(&wrapFree(CallableUserdata, f)) else null,
        .hash_func = if (callbacks.hash) |f| @ptrCast(&wrapHash(CallableUserdata, f)) else null,
        .equal_func = if (callbacks.equal) |f| @ptrCast(&wrapEqual(CallableUserdata, f)) else null,
        .less_than_func = if (callbacks.less_than) |f| @ptrCast(&wrapLessThan(CallableUserdata, f)) else null,
        .to_string_func = if (callbacks.to_string) |f| @ptrCast(&wrapToString(CallableUserdata, f)) else null,
    };

    raw.callableCustomCreate(result.ptr(), &c_info);
    return result;
}

/// Creates a custom Callable object from a function pointer.
///
/// Provided struct can be safely freed once the function returns.
///
/// @param info The info required to construct a Callable.
///
/// @return The newly created Callable.
///
/// @since 4.3
pub inline fn callableCustomCreate2(
    comptime Userdata: type,
    info: *const CallableInfo2(Userdata),
    comptime callbacks: *const CallableCallbacks2(Userdata),
) Callable {
    var result: Callable = undefined;

    const c_info = c.GDExtensionCallableCustomInfo2{
        .callable_userdata = if (Userdata != void) @ptrCast(info.userdata) else null,
        .library = @ptrCast(info.library),
        .object_id = @bitCast(info.object_id),
        .call_func = @ptrCast(&wrapCall(Userdata, callbacks.call)),
        .is_valid_func = if (callbacks.is_valid) |f| @ptrCast(&wrapIsValid(Userdata, f)) else null,
        .free_func = if (callbacks.free) |f| @ptrCast(&wrapFree(Userdata, f)) else null,
        .hash_func = if (callbacks.hash) |f| @ptrCast(&wrapHash(Userdata, f)) else null,
        .equal_func = if (callbacks.equal) |f| @ptrCast(&wrapEqual(Userdata, f)) else null,
        .less_than_func = if (callbacks.less_than) |f| @ptrCast(&wrapLessThan(Userdata, f)) else null,
        .to_string_func = if (callbacks.to_string) |f| @ptrCast(&wrapToString(Userdata, f)) else null,
        .get_argument_count_func = if (callbacks.get_argument_count) |f| @ptrCast(&wrapGetArgumentCount(Userdata, f)) else null,
    };

    raw.callableCustomCreate2(result.ptr(), &c_info);
    return result;
}

/// Retrieves the userdata pointer from a custom Callable.
///
/// If the Callable is not a custom Callable or the token does not match the one provided to callable_custom_create() via GDExtensionCallableCustomInfo then NULL will be returned.
///
/// @param p_callable A pointer to a Callable.
/// @param p_token A pointer to an address that uniquely identifies the GDExtension.
///
/// @since 4.2
pub inline fn callableCustomGetUserData(callable: *const Callable) ?*anyopaque {
    return raw.callableCustomGetUserData(callable.constPtr(), raw.library);
}

const std = @import("std");
const Child = std.meta.Child;

const c = @import("gdextension");

const api = @import("../api.zig");
const CallError = api.CallError;
const Error = api.Error;
const OptionalObjectID = api.object.OptionalObjectID;
const builtin = @import("../builtin.zig");
const Callable = builtin.Callable;
const String = builtin.String;
const Variant = builtin.Variant;
const Interface = @import("../Interface.zig");
const ClassLibrary = Interface.ClassLibrary;
