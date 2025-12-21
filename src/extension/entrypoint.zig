//! Root module for GDExtension libraries built with `gdzig.addExtension()`.

const std = @import("std");
const gdzig = @import("gdzig");
const extension = @import("extension");
const options = @import("options");

pub const std_options: std.Options = if (@hasDecl(extension, "std_options")) extension.std_options else .{};

var registry: gdzig.extension.Registry = .init(gdzig.engine_allocator);

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
    gdzig.raw = .init(get_proc_address.?, library.?);
    gdzig.raw.getGodotVersion(@ptrCast(&gdzig.version));
    extension.register(&registry);

    r_initialization.* = .{
        .minimum_initialization_level = @intFromEnum(options.minimum_initialization_level),
        .initialize = &enter,
        .deinitialize = &exit,
        .userdata = null,
    };
    return 1;
}

fn enter(_: ?*anyopaque, level: gdzig.c.GDExtensionInitializationLevel) callconv(.c) void {
    registry.enter(@enumFromInt(level));
}

fn exit(_: ?*anyopaque, level: gdzig.c.GDExtensionInitializationLevel) callconv(.c) void {
    if (level < @intFromEnum(options.minimum_initialization_level)) return;

    registry.exit(@enumFromInt(level));
    if (level == @intFromEnum(options.minimum_initialization_level)) {
        gdzig.extension.PropertyListInstanceBinding.cleanup();
        gdzig.extension.DestroyInstanceBinding.cleanup();
        registry.deinit();
    }
}
