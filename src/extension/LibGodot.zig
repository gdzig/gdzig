//! LibGodot functions for creating and destroying GodotInstances.
const std = @import("std");

const gdzig = @import("gdzig");
const extension_init = @import("extension_init.zig");

// TODO: Find a better way
// Ideally we'd get these from libgodot.h but that isn't shipped with Godot.
// Given using libgodot requires a local build perhaps they could be required to pass it in build.zig?
extern fn libgodot_create_godot_instance(p_argc: c_int, p_argv: [*c][*c]u8, p_init_func: gdzig.c.GDExtensionInitializationFunction) gdzig.c.GDExtensionObjectPtr;
extern fn libgodot_destroy_godot_instance(p_godot_instance: gdzig.c.GDExtensionObjectPtr) void;

pub fn createGodotInstance(
    args: []const [:0]const u8,
    level: gdzig.extension.InitializationLevel,
    reg_fn: *const fn (r: *gdzig.extension.Registry) void,
) *gdzig.class.GodotInstance {
    // This sets up the entry point like it's a normal extension
    extension_init.setupExtension(
        reg_fn,
        @intCast(@intFromEnum(level)),
    );

    // Arg wrangling, ew.
    // TODO: Clean this up
    var c_ptrs: [129][*c]const u8 = undefined;
    if (args.len > 128) @panic("Too many arguments");
    for (args, 0..) |arg, i| {
        c_ptrs[i] = arg.ptr;
    }
    c_ptrs[args.len] = null;

    // Actually create the instance
    const raw_instance = libgodot_create_godot_instance(@intCast(args.len), @ptrCast(&c_ptrs[0]), @ptrCast(&extension_init.initExtension));

    return @ptrCast(raw_instance);
}

pub fn destroyGodotInstance(instance: *gdzig.class.GodotInstance) void {
    libgodot_destroy_godot_instance(@ptrCast(instance));
}
