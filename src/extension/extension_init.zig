//! Generic extension initialization code. Can be used both by LibGodot and GDExtension.

const std = @import("std");
const gdzig = @import("gdzig");

var registry: gdzig.extension.Registry = .init(gdzig.engine_allocator);
var register: ?(*const fn (r: *gdzig.extension.Registry) void) = null;
var extension_level: gdzig.c.GDExtensionInitializationLevel = undefined;

pub fn setupExtension(
    reg_fn: ?(*const fn (r: *gdzig.extension.Registry) void),
    level: gdzig.c.GDExtensionInitializationLevel,
) void {
    register = reg_fn;
    extension_level = level;
}

pub fn initExtension(
    get_proc_address: gdzig.c.GDExtensionInterfaceGetProcAddress,
    library: gdzig.c.GDExtensionClassLibraryPtr,
    r_initialization: *gdzig.c.GDExtensionInitialization,
) callconv(.c) gdzig.c.GDExtensionBool {
    gdzig.raw = .init(get_proc_address.?, library.?);
    gdzig.raw.getGodotVersion(@ptrCast(&gdzig.version));

    r_initialization.* = .{
        .minimum_initialization_level = extension_level,
        .initialize = &enter,
        .deinitialize = &exit,
        .userdata = null,
    };

    // Register classes and modules
    if (register) |reg_fn| {
        reg_fn(&registry);
    }

    return 1;
}

fn enter(_: ?*anyopaque, level: gdzig.c.GDExtensionInitializationLevel) callconv(.c) void {
    registry.enter(@enumFromInt(level));
}

fn exit(_: ?*anyopaque, level: gdzig.c.GDExtensionInitializationLevel) callconv(.c) void {
    if (level < extension_level) return;

    registry.exit(@enumFromInt(level));

    if (level == extension_level) {
        gdzig.extension.PropertyListInstanceBinding.cleanup();
        gdzig.extension.DestroyInstanceBinding.cleanup();
        registry.deinit();
    }
}
