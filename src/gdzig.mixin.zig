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

test {
    std.testing.refAllDecls(@This());
}

const std = @import("std");

const compatibility_minimum = @import("common").compatibility_minimum;

// The generated root exports `pub const testing`, so a file-scope `testing`
// here would shadow the public test harness for the whole file. This namespace
// holds the fake engine used by the dispatch-table test: it records which
// interface names init requests for a given running version.
const dispatch_testing = struct {
    /// Fake engine for the measured interface gate test. Every interface resolves
    /// to an inert stub, and only the version probe is ever called.
    const FakeEngine = struct {
        var version: Version = .{ .major = 4, .minor = 7, .patch = 2 };
        var requests: std.StringHashMapUnmanaged(void) = .empty;
        var count: usize = 0;

        fn reset(requested: Version) void {
            version = requested;
            count = 0;
            freeKeys();
            requests.clearRetainingCapacity();
        }

        fn deinit() void {
            freeKeys();
            requests.deinit(std.testing.allocator);
        }

        fn freeKeys() void {
            var iterator = requests.iterator();
            while (iterator.next()) |entry| std.testing.allocator.free(entry.key_ptr.*);
        }

        fn getProcAddress(name: [*c]const u8) callconv(.c) c.GDExtensionInterfaceFunctionPtr {
            const text = std.mem.sliceTo(name, 0);
            count += 1;
            const entry = requests.getOrPut(std.testing.allocator, text) catch @panic("OOM");
            if (!entry.found_existing) {
                entry.key_ptr.* = std.testing.allocator.dupe(u8, text) catch @panic("OOM");
            }
            if (std.mem.eql(u8, text, "get_godot_version")) return @ptrCast(&writeVersion);
            return &inert;
        }

        fn writeVersion(out: [*c]c.GDExtensionGodotVersion) callconv(.c) void {
            out[0].major = version.major;
            out[0].minor = version.minor;
            out[0].patch = version.patch;
            out[0].string = "";
        }

        // The C interface type is an unspecified-argument function pointer.
        fn inert(...) callconv(.c) void {}
    };
};

test "measured interface gates follow the running engine version" {
    const Child = std.meta.Child;
    defer dispatch_testing.FakeEngine.deinit();
    const library: Child(c.GDExtensionClassLibraryPtr) = @ptrFromInt(0x1000);
    const late_interfaces = [_][]const u8{
        "classdb_construct_object3",
        "classdb_register_extension_class6",
        "variant_get_type_by_name",
    };

    dispatch_testing.FakeEngine.reset(.{ .major = 4, .minor = 6, .patch = 3 });
    const older = DispatchTable.init(&dispatch_testing.FakeEngine.getProcAddress, library);
    try std.testing.expect(older.version.eql(.{ .major = 4, .minor = 6, .patch = 3 }));
    try std.testing.expectEqual(@as(usize, 176), dispatch_testing.FakeEngine.count);
    for (late_interfaces) |name| try std.testing.expect(!dispatch_testing.FakeEngine.requests.contains(name));
    try std.testing.expect(older.classdbConstructObject3 == null);
    try std.testing.expect(older.classdbRegisterExtensionClass6 == null);
    try std.testing.expect(older.variantGetTypeByName == null);

    dispatch_testing.FakeEngine.reset(.{ .major = 4, .minor = 7, .patch = 2 });
    const newer = DispatchTable.init(&dispatch_testing.FakeEngine.getProcAddress, library);
    try std.testing.expectEqual(@as(usize, 179), dispatch_testing.FakeEngine.count);
    for (late_interfaces) |name| try std.testing.expect(dispatch_testing.FakeEngine.requests.contains(name));
    try std.testing.expect(newer.classdbConstructObject3 != null);
    try std.testing.expect(newer.classdbRegisterExtensionClass6 != null);
    try std.testing.expect(newer.variantGetTypeByName != null);
}
