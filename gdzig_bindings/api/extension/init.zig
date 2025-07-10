pub fn Entrypoint(comptime Userdata: type) type {
    return fn (getProcAddress: *const GetProcAddress, library: *ClassLibrary, initialization: *Initialization(Userdata)) callconv(.c) bool;
}

pub const GetProcAddress = fn (function_name: [*:0]const u8) callconv(.c) ?*const anyopaque;

pub fn Initialization(comptime Userdata: type) type {
    return opaque {
        pub fn init(self: *Initialization, info: *const InitializationInfo(Userdata), comptime callbacks: *const InitializationCallbacks(Userdata)) void {
            @as(*c.GDExtensionInitialization, self).* = .{
                .minimum_initialization_level = @intFromEnum(info.minimum_initialization_level),
                .userdata = if (Userdata != void) info.userdata else null,
                .initialize = if (callbacks.initialize) |f| wrapInitialize(f) else null,
                .deinitialize = if (callbacks.deinitialize) |f| wrapDeinitialize(f) else null,
            };
        }
    };
}

pub fn InitializationInfo(comptime Userdata: type) type {
    return if (Userdata != void)
        struct {
            userdata: *Userdata = null,
            minimum_initialization_level: Level = Level.core,
        }
    else
        struct {
            minimum_initialization_level: Level = Level.core,
        };
}

pub fn InitializationCallbacks(comptime Userdata: type) type {
    return struct {
        initialize: ?*const Initialize(Userdata) = null,
        deinitialize: ?*const Deinitialize(Userdata) = null,
    };
}

pub const Level = enum(c_uint) {
    core = c.GDEXTENSION_INITIALIZATION_CORE,
    servers = c.GDEXTENSION_INITIALIZATION_SERVERS,
    scene = c.GDEXTENSION_INITIALIZATION_SCENE,
    editor = c.GDEXTENSION_INITIALIZATION_EDITOR,
    // max = c.GDEXTENSION_MAX_INITIALIZATION_LEVEL,
};

pub fn Initialize(comptime Userdata: type) type {
    return if (Userdata != void)
        fn (?*Userdata, Level) void
    else
        fn (Level) void;
}

pub fn wrapInitialize(comptime Userdata: type, comptime callback: *const Initialize(Userdata)) *const fn (*anyopaque, c.GDExtensionInitializationLevel) callconv(.c) void {
    return &struct {
        fn wrapped(p_userdata: ?*anyopaque, p_level: c.GDExtensionInitializationLevel) callconv(.c) void {
            if (Userdata == void) {
                callback(p_level);
            } else {
                callback(@ptrCast(p_userdata.?), p_level);
            }
        }
    }.wrapped;
}

pub fn Deinitialize(comptime Userdata: type) type {
    return if (Userdata != void)
        fn (?*Userdata, Level) void
    else
        fn (Level) void;
}

pub fn wrapDeinitialize(comptime Userdata: type, comptime callback: *const Initialize(Userdata)) *const fn (*anyopaque, c.GDExtensionInitializationLevel) callconv(.c) void {
    return &struct {
        fn wrapped(p_userdata: ?*anyopaque, p_level: c.GDExtensionInitializationLevel) callconv(.c) void {
            if (Userdata == void) {
                callback(p_level);
            } else {
                callback(@ptrCast(p_userdata.?), p_level);
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
const Interface = @import("../../Interface.zig");
const ClassLibrary = Interface.ClassLibrary;
