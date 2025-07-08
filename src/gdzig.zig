//! These modules are generated directly from the Godot Engine's API documentation:
//!
//! - `builtin` - Core Godot value types: String, Vector2/3/4, Array, Dictionary, Color
//! - `class` - Godot class hierarchy: Object, Node, RefCounted, and all the related engine classes
//! - `global` - Global scope enumerations, flag structs, and constants
//!
//! Godot also exposes a suite of utility functions that we generate bindings for:
//!
//! - `general` - General-purpose utility functions like logging and more
//! - `math` - Mathematical utilities and constants from Godot's Math class
//! - `random` - Random number generation utilities
//!
//! For lower level access to the GDExtension APIs:
//!
//! - `interface` - A static instance of an `Interface`, populated at startup with pointers to the GDExtension header functions
//! - `c` - Raw C bindings to gdextension headers and types
//!
//! We also provide a framework around the generated code that helps you write your extension:
//!
//! - `debug` - Debug assertions and validation
//! - `heap` - Work with Godot's allocator
//! - `meta` - Type introspection and class hierarchy
//! - `object` - Object creation, destruction, and lifecycle management
//! - `register` - Class, method, plugin and signal registration
//! - `string` - String handling utilities and conversions
//! - `support` - Method binding and constructor utilities
//!

pub var interface: Interface = undefined;

pub const InitializationLevel = enum(c_int) {
    core = 0,
    servers = 1,
    scene = 2,
    editor = 3,
};

pub fn entrypoint(
    comptime name: []const u8,
    comptime opt: struct {
        init: ?*const fn (level: InitializationLevel) void = null,
        deinit: ?*const fn (level: InitializationLevel) void = null,
        minimum_initialization_level: InitializationLevel = InitializationLevel.core,
    },
) void {
    comptime entrypointWithUserdata(name, void, .{
        .userdata = {},
        .init = opt.init,
        .deinit = opt.deinit,
        .minimum_initialization_level = opt.minimum_initialization_level,
    });
}

pub fn entrypointWithUserdata(
    comptime name: []const u8,
    comptime Userdata: type,
    comptime opt: struct {
        userdata: if (Userdata == void) void else *const fn () Userdata,
        init: if (Userdata == void) ?*const fn (level: InitializationLevel) void else ?*const fn (userdata: Userdata, level: InitializationLevel) void = null,
        deinit: if (Userdata == void) ?*const fn (level: InitializationLevel) void else ?*const fn (userdata: Userdata, level: InitializationLevel) void = null,
        minimum_initialization_level: InitializationLevel = InitializationLevel.core,
    },
) void {
    @export(&struct {
        fn entrypoint(
            p_get_proc_address: c.GDExtensionInterfaceGetProcAddress,
            p_library: c.GDExtensionClassLibraryPtr,
            r_initialization: [*c]c.GDExtensionInitialization,
        ) callconv(.c) c.GDExtensionBool {
            interface = .init(p_get_proc_address.?, p_library.?);
            r_initialization.*.userdata = if (Userdata != void) opt.userdata() else null;
            r_initialization.*.initialize = @ptrCast(&init);
            r_initialization.*.deinitialize = @ptrCast(&deinit);
            r_initialization.*.minimum_initialization_level = @intFromEnum(opt.minimum_initialization_level);
            // TODO: remove
            heap.general_allocator = std.heap.page_allocator;
            return 1;
        }

        fn init(userdata: ?*anyopaque, p_level: c.GDExtensionInitializationLevel) callconv(.C) void {
            if (opt.init) |init_cb| {
                // TODO: remove
                register.init();
                if (Userdata == void) {
                    init_cb(@enumFromInt(p_level));
                } else {
                    init_cb(@ptrCast(userdata.?), @enumFromInt(p_level));
                }
            }
        }

        fn deinit(userdata: ?*anyopaque, p_level: c.GDExtensionInitializationLevel) callconv(.C) void {
            if (opt.deinit) |deinit_cb| {
                if (Userdata == void) {
                    deinit_cb(@enumFromInt(p_level));
                } else {
                    deinit_cb(@ptrCast(userdata.?), @enumFromInt(p_level));
                }
                // TODO: remove
                register.deinit();
            }
        }
    }.entrypoint, .{
        .name = name,
        .linkage = .strong,
    });
}

test {
    std.testing.refAllDecls(@This());
}

const std = @import("std");

// Bindgen modules
pub const builtin = @import("builtin.zig");
pub const class = @import("class.zig");
pub const general = @import("general.zig");
pub const global = @import("global.zig");
pub const Interface = @import("Interface.zig");
pub const math = @import("math.zig");
pub const random = @import("random.zig");

// Local modules
pub const api = @import("api.zig");
pub const c = @import("gdextension");
pub const debug = @import("debug.zig");
pub const heap = @import("heap.zig");
pub const meta = @import("meta.zig");
pub const object = @import("object.zig");
pub const register = @import("register.zig");
pub const string = @import("string.zig");
pub const support = @import("support.zig");

// Re-exports
pub const connect = object.connect;
pub const registerClass = register.registerClass;
pub const registerMethod = register.registerMethod;
pub const registerPlugin = register.registerPlugin;
pub const registerSignal = register.registerSignal;
