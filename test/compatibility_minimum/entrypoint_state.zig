//! Isolated counters for the real normal and IPC entrypoints.
pub var actual: Version = .@"4.7";
pub var queries: usize = 0;
pub var interface_lookups: usize = 0;
pub var registrations: usize = 0;
pub var startups: usize = 0;

/// Observe registration without constructing Godot objects.
pub fn register(_: anytype) void {
    registrations += 1;
}

/// Return an isolated engine identity and count each actual query.
pub fn query(result: *gdzig.c.GDExtensionGodotVersion) callconv(.c) void {
    queries += 1;
    result.* = .{
        .major = actual.major,
        .minor = actual.minor,
        .patch = actual.patch,
        .string = "fixture",
    };
}

/// Resolve only the version function needed by the real initializer.
pub fn proc(_: [*c]const u8) callconv(.c) gdzig.c.GDExtensionInterfaceFunctionPtr {
    interface_lookups += 1;
    return @ptrCast(&query);
}

const gdzig = @import("runtime");
const Version = gdzig.Version;
