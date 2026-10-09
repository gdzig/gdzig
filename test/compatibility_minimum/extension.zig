//! A real normal-entrypoint fixture, separate from the IPC test harness.
/// Observe registration and the actual raw engine identity after initialization.
pub fn register(_: *gdzig.extension.Registry) void {
    var actual: gdzig.Version = undefined;
    gdzig.raw.getGodotVersion(@ptrCast(&actual));
    const effective = gdzig.version;
    std.debug.print("GDZIG_COMPATIBILITY_MINIMUM_REGISTERED actual={d}.{d}.{d} effective={d}.{d}.{d}\n", .{
        actual.major,    actual.minor,    actual.patch,
        effective.major, effective.minor, effective.patch,
    });
}

/// Retain a binary identity even when the normal entrypoint rejects registration.
pub export fn gdzig_compatibility_minimum_identity() callconv(.c) [*:0]const u8 {
    return "GDZIG_COMPATIBILITY_MINIMUM_BINARY=" ++ fixture_options.compatibility_minimum;
}

const std = @import("std");

const gdzig = @import("gdzig");
const fixture_options = @import("fixture_options");
