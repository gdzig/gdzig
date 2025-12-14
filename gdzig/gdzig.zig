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
//! - `raw` - Function pointers to the raw C GDExtension API, loaded at runtime from Godot
//! - `c` - Raw C bindings to gdextension headers and types
//!
//! We also provide a framework around the generated code that helps you write your extension:
//!
//! - `heap` - Work with Godot's allocator
//! - `meta` - Type introspection and class hierarchy
//! - `object` - Object lifecycle and class inheritance
//! - `support` - Method binding and constructor utilities
//!

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
pub const random = @import("random.zig");

pub const register = @import("register.zig");
pub const registerClass = register.registerClass;
pub const registerExtension = register.registerExtension;
pub const registerMethod = register.registerMethod;
pub const registerSignal = register.registerSignal;
pub const InitializationLevel = register.InitializationLevel;

pub const support = @import("support.zig");

/// The C FFI GDExtension API, initialized during extension initialization.
pub var raw: Interface = undefined;

/// The current running version of Godot, initialized during extension initialization.
pub var version: Version = undefined;

pub const CallError = error{
    InvalidMethod,
    InvalidArgument,
    TooManyArguments,
    TooFewArguments,
    InstanceIsNull,
    MethodNotConst,
};

pub const ConnectError = error{
    AlreadyConnected,
};

pub const EmitError = error{
    InvalidSignal,
    SignalsBlocked,
    MethodNotFound,
};

pub const PropertyError = error{
    InvalidOperation,
    InvalidKey,
    IndexOutOfBounds,
};

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

test {
    std.testing.refAllDecls(@This());
}

const std = @import("std");
