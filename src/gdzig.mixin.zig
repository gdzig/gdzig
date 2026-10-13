//! Higher level bindings generated from the Godot Engine's extension API:
//!
//! - `builtin` - Core Godot value types: String, Vector2/3/4, Array, Dictionary, Color
//! - `class` - Godot class hierarchy and OOP utilities for working with classes
//! - `global` - Global scope enumerations, flag structs, and constants
//! - `general` - General-purpose utility functions like logging
//! - `math` - Mathematical utilities and constants
//! - `random` - Random number generation utilities
//!
//! Lower level access to the GDExtension APIs:
//!
//! - `raw` - Runtime function pointers loaded from Godot
//! - `c` - C type definitions from `gdextension_interface.h`
//!

pub const c = @import("gdextension");
pub const builtin = @import("builtin.zig");
pub const class = @import("class.zig");
pub const heap = @import("heap.zig");
pub const engine_allocator = heap.engine_allocator;
pub const GeneralPurposeAllocator = heap.GeneralPurposeAllocator;
pub const general = @import("general.zig");
pub const global = @import("global.zig");
pub const math = @import("math.zig");
pub const random = @import("random.zig");
pub const extension = @import("extension.zig");
pub const ptrcall = @import("class/ptrcall.zig");
pub const testing = @import("testing.zig");

const DispatchTable = @import("DispatchTable.zig");

/// Godot function pointers, populated at load time.
pub var raw: DispatchTable = undefined;

const godot_compatibility_minimum: ?Version = if (@import("build_options").godot_compatibility_minimum) |parts|
    .{ .major = parts[0], .minor = parts[1], .patch = parts[2] }
else
    null;

// A const in minimum builds and a var set at startup otherwise.
const ApiVersion = if (godot_compatibility_minimum) |floor| struct {
    const value: Version = floor;
} else struct {
    var value: Version = undefined;
};

/// API layout targeted by these bindings. Points at the compile-time floor in
/// minimum builds, and at the running engine's version otherwise. It can be
/// older than `engine_version` when a minimum is selected.
pub const api_version = &ApiVersion.value;

/// Actual running engine version, populated during initialization in every build.
/// This can be newer than `api_version` when a compatibility minimum is selected.
pub var engine_version: Version = undefined;

/// Publish the discovered engine version, then reject an unmet floor before startup.
/// Default builds also set the API version. Minimum builds retain their constant floor.
pub fn initializeVersion() bool {
    const actual = raw.version;
    engine_version = actual;
    if (!compatibility_minimum.accepts(actual, godot_compatibility_minimum)) {
        const minimum = godot_compatibility_minimum.?;
        std.log.err("gdzig requires Godot {d}.{d}.{d} or newer; running {d}.{d}.{d}", .{
            minimum.major,
            minimum.minor,
            minimum.patch,
            actual.major,
            actual.minor,
            actual.patch,
        });
        return false;
    }
    if (comptime godot_compatibility_minimum == null) api_version.* = actual;
    return true;
}

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

pub const Version = @import("common").Version;

// Keep test helpers private without shadowing the public testing module.
const dispatch_testing = struct {
    const FakeEngine = struct {
        var running_version: c.GDExtensionGodotVersion = undefined;
        var requested_version = false;
        var requested_variant_get_type_by_name = false;
        var requested_classdb_construct_object3 = false;
        var requested_classdb_register_extension_class6 = false;

        fn reset(new_version: c.GDExtensionGodotVersion) void {
            running_version = new_version;
            requested_version = false;
            requested_variant_get_type_by_name = false;
            requested_classdb_construct_object3 = false;
            requested_classdb_register_extension_class6 = false;
        }

        fn getProcAddress(name_ptr: [*c]const u8) callconv(.c) c.GDExtensionInterfaceFunctionPtr {
            const name = std.mem.span(@as([*:0]const u8, @ptrCast(name_ptr)));
            if (std.mem.eql(u8, name, "get_godot_version")) {
                requested_version = true;
                return @ptrCast(&getGodotVersion);
            }
            if (std.mem.eql(u8, name, "variant_get_type_by_name")) {
                requested_variant_get_type_by_name = true;
            }
            if (std.mem.eql(u8, name, "classdb_construct_object3")) {
                requested_classdb_construct_object3 = true;
            }
            if (std.mem.eql(u8, name, "classdb_register_extension_class6")) {
                requested_classdb_register_extension_class6 = true;
            }
            return @ptrCast(&stub);
        }

        fn getGodotVersion(godot_version: *c.GDExtensionGodotVersion) callconv(.c) void {
            godot_version.* = running_version;
        }

        fn stub() callconv(.c) void {}
    };
};

test "dispatch table skips 4.7 interfaces for a 4.6 engine" {
    dispatch_testing.FakeEngine.reset(.{ .major = 4, .minor = 6, .patch = 0, .string = "4.6" });

    const table = DispatchTable.init(&dispatch_testing.FakeEngine.getProcAddress, @ptrFromInt(1));

    try std.testing.expect(dispatch_testing.FakeEngine.requested_version);
    try std.testing.expect(!dispatch_testing.FakeEngine.requested_variant_get_type_by_name);
    try std.testing.expect(!dispatch_testing.FakeEngine.requested_classdb_construct_object3);
    try std.testing.expect(!dispatch_testing.FakeEngine.requested_classdb_register_extension_class6);
    try std.testing.expectEqual(null, table.variantGetTypeByName);
    try std.testing.expectEqual(null, table.classdbConstructObject3);
    try std.testing.expectEqual(null, table.classdbRegisterExtensionClass6);
}

test "dispatch table loads 4.7 interfaces for a 4.7.2 engine" {
    dispatch_testing.FakeEngine.reset(.{ .major = 4, .minor = 7, .patch = 2, .string = "4.7.2" });

    const table = DispatchTable.init(&dispatch_testing.FakeEngine.getProcAddress, @ptrFromInt(1));

    try std.testing.expect(dispatch_testing.FakeEngine.requested_version);
    try std.testing.expect(dispatch_testing.FakeEngine.requested_variant_get_type_by_name);
    try std.testing.expect(dispatch_testing.FakeEngine.requested_classdb_construct_object3);
    try std.testing.expect(dispatch_testing.FakeEngine.requested_classdb_register_extension_class6);
    try std.testing.expect(table.variantGetTypeByName != null);
    try std.testing.expect(table.classdbConstructObject3 != null);
    try std.testing.expect(table.classdbRegisterExtensionClass6 != null);
}

test {
    std.testing.refAllDecls(@This());
}

const std = @import("std");

const compatibility_minimum = @import("common").compatibility_minimum;
