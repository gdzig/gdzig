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

/// The current running version of Godot, initialized during extension initialization.
pub var version: Version = undefined;

pub const Version = extern struct {
    major: u32,
    minor: u32,
    patch: u32,
    string: [*:0]const u8 = "",

    pub const @"4.1" = parse("4.1");
    pub const @"4.2" = parse("4.2");
    pub const @"4.3" = parse("4.3");
    pub const @"4.4" = parse("4.4");

    var current: Version = undefined;

    pub fn gt(self: Version, other: Version) bool {
        if (self.major != other.major) return self.major > other.major;
        if (self.minor != other.minor) return self.minor > other.minor;
        return self.patch > other.patch;
    }

    pub fn gte(self: Version, other: Version) bool {
        if (self.major != other.major) return self.major > other.major;
        if (self.minor != other.minor) return self.minor > other.minor;
        return self.patch >= other.patch;
    }

    pub fn lt(self: Version, other: Version) bool {
        if (self.major != other.major) return self.major < other.major;
        if (self.minor != other.minor) return self.minor < other.minor;
        return self.patch < other.patch;
    }

    pub fn lte(self: Version, other: Version) bool {
        if (self.major != other.major) return self.major < other.major;
        if (self.minor != other.minor) return self.minor < other.minor;
        return self.patch <= other.patch;
    }

    /// Returns true if self is in the range [min_ver, max_ver).
    pub fn range(self: Version, min_ver: Version, max_ver: Version) bool {
        return self.gte(min_ver) and self.lt(max_ver);
    }

    pub fn parse(version_string: []const u8) Version {
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

    test {
        const v14_2 = parse("14.2.0");
        const v14_3 = parse("14.3.0");

        try std.testing.expectEqual(v14_2.major, 14);
        try std.testing.expectEqual(v14_2.minor, 2);
        try std.testing.expectEqual(v14_2.patch, 0);

        try std.testing.expect(v14_3.gt(v14_2));
        try std.testing.expect(v14_3.gte(v14_2));
        try std.testing.expect(v14_2.lt(v14_3));
        try std.testing.expect(v14_2.lte(v14_3));
        try std.testing.expect(v14_3.range(v14_2, parse("14.4.0")));
    }
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
            raw.getGodotVersion(@ptrCast(&version));
            interface = &raw;
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
                if (p_level == c.GDEXTENSION_INITIALIZATION_CORE) {
                    // TODO: remove
                    register.deinit();
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

const std = @import("std");

pub const c = @import("gdextension");

pub const builtin = @import("builtin.zig");
pub const class = @import("class.zig");
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
