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
//! - `heap` - Work with Godot's allocator
//! - `meta` - Type introspection and class hierarchy
//! - `object` - Object lifecycle and class inheritance
//! - `register` - Class, method, plugin and signal registration
//! - `string` - String handling utilities and conversions
//! - `support` - Method binding and constructor utilities
//!

pub const InitializationLevel = enum(c_int) {
    core = 0,
    servers = 1,
    scene = 2,
    editor = 3,
};

pub var version: GodotVersion = undefined;

pub const GodotVersion = extern struct {
    major: u32,
    minor: u32,
    patch: u32,
    string: [*:0]const u8 = "",

    pub const @"4.0" = parse("4.0");
    pub const @"4.1" = parse("4.1");
    pub const @"4.2" = parse("4.2");
    pub const @"4.3" = parse("4.3");
    pub const @"4.4" = parse("4.4");
    pub const @"4.5" = parse("4.5");
    pub const @"4.6" = parse("4.6");

    /// Returns the currently running version of Godot
    pub fn current() GodotVersion {
        var self: GodotVersion = undefined;
        raw.getGodotVersion(@ptrCast(&self));
        return self;
    }

    pub fn gt(self: GodotVersion, other: GodotVersion) bool {
        if (self.major != other.major) return self.major > other.major;
        if (self.minor != other.minor) return self.minor > other.minor;
        return self.patch > other.patch;
    }

    pub fn gte(self: GodotVersion, other: GodotVersion) bool {
        if (self.major != other.major) return self.major > other.major;
        if (self.minor != other.minor) return self.minor > other.minor;
        return self.patch >= other.patch;
    }

    pub fn lt(self: GodotVersion, other: GodotVersion) bool {
        if (self.major != other.major) return self.major < other.major;
        if (self.minor != other.minor) return self.minor < other.minor;
        return self.patch < other.patch;
    }

    pub fn lte(self: GodotVersion, other: GodotVersion) bool {
        if (self.major != other.major) return self.major < other.major;
        if (self.minor != other.minor) return self.minor < other.minor;
        return self.patch <= other.patch;
    }

    pub fn range(self: GodotVersion, min_ver: GodotVersion, max_ver: GodotVersion) bool {
        return self.gte(min_ver) and self.lt(max_ver);
    }

    pub fn parse(comptime version_string: []const u8) GodotVersion {
        comptime {
            var parts: [3]u32 = .{ 0, 0, 0 };
            var part_idx: usize = 0;
            for (version_string) |ch| {
                if (ch == '.') {
                    part_idx += 1;
                } else {
                    parts[part_idx] = parts[part_idx] * 10 + (ch - '0');
                }
            }
            return .{ .major = parts[0], .minor = parts[1], .patch = parts[2] };
        }
    }
};

pub const CallError = error{
    InvalidMethod,
    InvalidArgument,
    TooManyArguments,
    TooFewArguments,
    InstanceIsNull,
    MethodNotConst,
};

pub const PropertyError = error{
    InvalidOperation,
    InvalidKey,
    IndexOutOfBounds,
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
            raw = .init(p_get_proc_address.?, p_library.?);
            interface = &raw;
            version = .current();
            r_initialization.*.userdata = if (Userdata != void) opt.userdata() else null;
            r_initialization.*.initialize = @ptrCast(&init);
            r_initialization.*.deinitialize = @ptrCast(&deinit);
            r_initialization.*.minimum_initialization_level = @intFromEnum(opt.minimum_initialization_level);
            return 1;
        }

        fn init(userdata: ?*anyopaque, p_level: c.GDExtensionInitializationLevel) callconv(.c) void {
            if (opt.init) |init_cb| {
                if (Userdata == void) {
                    init_cb(@enumFromInt(p_level));
                } else {
                    init_cb(@ptrCast(userdata.?), @enumFromInt(p_level));
                }
            }
        }

        fn deinit(userdata: ?*anyopaque, p_level: c.GDExtensionInitializationLevel) callconv(.c) void {
            if (opt.deinit) |deinit_cb| {
                if (Userdata == void) {
                    deinit_cb(@enumFromInt(p_level));
                } else {
                    deinit_cb(@ptrCast(userdata.?), @enumFromInt(p_level));
                }
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

/// TODO: make this private once API is ready
pub var interface: *Interface = &raw;
pub var raw: Interface = undefined;

pub fn typeName(comptime T: type) *builtin.StringName {
    const Static = &struct {
        const _ = meta.typeShortName(T);
        var name: builtin.StringName = undefined;
        var init: bool = false;
    };

    if (!Static.init) {
        Static.name = builtin.StringName.fromComptimeLatin1(Static._);
        Static.init = true;
    }

    return &Static.name;
}

pub fn signalName(comptime S: type) builtin.StringName {
    return .fromComptimeLatin1(meta.signalName(S));
}

pub fn create(comptime T: type) !*T {
    const class_name = meta.typeName(T);

    if (version.gte(.@"4.4")) {
        return if (raw.classdbConstructObject2(class_name)) |any|
            @ptrCast(@alignCast(any))
        else
            return error.OutOfMemory;
    } else {
        return if (raw.classdbConstructObject(class_name)) |any|
            @ptrCast(@alignCast(any))
        else
            return error.OutOfMemory;
    }
}

pub fn destroy(obj: anytype) void {
    raw.objectDestroy(@ptrCast(obj));
}

const std = @import("std");

pub const c = @import("gdextension");

pub const builtin = @import("builtin.zig");
pub const class = @import("class.zig");
pub const classdb = @import("classdb.zig");
pub const general = @import("general.zig");
pub const global = @import("global.zig");
pub const heap = @import("heap.zig");
pub const Interface = @import("Interface.zig");
pub const math = @import("math.zig");
pub const meta = @import("meta.zig");
pub const object = @import("object.zig");
pub const connect = object.connect;
pub const random = @import("random.zig");
pub const register = @import("register.zig");
pub const registerClass = register.registerClass;
pub const registerMethod = register.registerMethod;
pub const registerSignal = register.registerSignal;
pub const string = @import("string.zig");
pub const support = @import("support.zig");
