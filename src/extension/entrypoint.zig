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
    gdzig.version = gdzig.raw.version;
    extension.register(&registry);

    r_initialization.* = .{
        .minimum_initialization_level = @backingInt(options.minimum_initialization_level),
        .initialize = &enter,
        .deinitialize = &exit,
        .userdata = null,
    };
    return 1;
}

fn enter(_: ?*anyopaque, level: gdzig.c.GDExtensionInitializationLevel) callconv(.c) void {
    registry.enter(@fromBackingInt(@intCast(level)));
}

fn exit(_: ?*anyopaque, level: gdzig.c.GDExtensionInitializationLevel) callconv(.c) void {
    if (level < @backingInt(options.minimum_initialization_level)) return;

    registry.exit(@fromBackingInt(@intCast(level)));
    if (level == @backingInt(options.minimum_initialization_level)) {
        if (@hasDecl(extension, "unregister")) extension.unregister(&registry);
        gdzig.extension.PropertyListInstanceBinding.cleanup();
        gdzig.extension.DestroyInstanceBinding.cleanup();
        registry.deinit();
    }
}

test "extension entrypoint consumes the version read during dispatch initialization" {
    const FakeEngine = @import("fake_engine");
    FakeEngine.reset();

    var initialization: gdzig.c.GDExtensionInitialization = undefined;
    _ = entrypoint(&FakeEngine.getProcAddress, @ptrFromInt(1), &initialization);

    try FakeEngine.expectVersion(gdzig.version);
    try std.testing.expectEqual(@as(usize, 1), FakeEngine.get_godot_version_calls);
}
