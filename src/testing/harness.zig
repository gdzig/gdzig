//! Test harness for GDExtension tests.
//!
//! This is the Zig test runner that runs inside Godot. It:
//! 1. Has access to builtin.test_functions (because it's a Zig test runner)
//! 2. Exports the GDExtension entrypoint (so Godot can load it)
//! 3. Runs the test server to communicate with the coordinator

const std = @import("std");
const builtin = @import("builtin");
const gdzig = @import("gdzig");
const options = @import("options");
const server = @import("server.zig");

const log = std.log.scoped(.gdzig_testing);

pub const std_options: std.Options = .{
    // Set gdzig_testing scope to .warn by default (silent)
    // To enable debug logging, users can set log_scope_levels in their test.zig
    .log_scope_levels = &.{
        .{ .scope = .gdzig_testing, .level = .warn },
    },
};

// Export the GDExtension entrypoint
comptime {
    @export(&entrypoint, .{
        .name = options.entry_symbol,
        .linkage = .strong,
    });
}

fn entrypoint(
    get_proc_address: gdzig.c.GDExtensionInterfaceGetProcAddress,
    library: gdzig.c.GDExtensionClassLibraryPtr,
    r_initialization: *gdzig.c.GDExtensionInitialization,
) callconv(.c) gdzig.c.GDExtensionBool {
    log.debug("extension entrypoint called", .{});

    gdzig.raw = .init(get_proc_address.?, library.?);
    gdzig.raw.getGodotVersion(@ptrCast(&gdzig.version));

    log.debug("godot version: {d}.{d}.{d}", .{
        gdzig.version.major,
        gdzig.version.minor,
        gdzig.version.patch,
    });

    r_initialization.* = .{
        .minimum_initialization_level = @intFromEnum(options.minimum_initialization_level),
        .initialize = &enter,
        .deinitialize = &exit,
        .userdata = null,
    };

    return 1;
}

fn enter(_: ?*anyopaque, level: gdzig.c.GDExtensionInitializationLevel) callconv(.c) void {
    if (level != @intFromEnum(options.minimum_initialization_level)) {
        return;
    }

    log.debug("starting test server, {d} tests available", .{builtin.test_functions.len});
    server.run(gdzig.engine_allocator);
    log.debug("test server finished, quitting godot", .{});
    server.quit();
}

fn exit(_: ?*anyopaque, _: gdzig.c.GDExtensionInitializationLevel) callconv(.c) void {}
