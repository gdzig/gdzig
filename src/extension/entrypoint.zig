//! Root module for GDExtension libraries built with `gdzig.addExtension()`.

const std = @import("std");
const gdzig = @import("gdzig");
const extension = @import("extension");
const options = @import("options");

const extension_init = @import("extension_init.zig");

pub const std_options: std.Options = if (@hasDecl(extension, "std_options")) extension.std_options else .{};

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
    extension_init.setupExtension(&extension.register, @intFromEnum(options.minimum_initialization_level));
    return extension_init.initExtension(get_proc_address, library, r_initialization);
}
