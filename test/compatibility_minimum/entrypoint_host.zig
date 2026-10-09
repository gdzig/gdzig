//! Invoke the actual normal and IPC entrypoints with isolated dispatch counters.
comptime {
    _ = entrypoint;
    _ = harness;
}

extern fn gdextension_entry(
    gdzig.c.GDExtensionInterfaceGetProcAddress,
    gdzig.c.GDExtensionClassLibraryPtr,
    *gdzig.c.GDExtensionInitialization,
) callconv(.c) gdzig.c.GDExtensionBool;

extern fn gdzig_compatibility_minimum_harness_entry(
    gdzig.c.GDExtensionInterfaceGetProcAddress,
    gdzig.c.GDExtensionClassLibraryPtr,
    *gdzig.c.GDExtensionInitialization,
) callconv(.c) gdzig.c.GDExtensionBool;

const minimum: ?gdzig.Version = if (std.mem.eql(u8, fixture_options.compatibility_minimum, "none"))
    null
else
    gdzig.Version.parseStrict(fixture_options.compatibility_minimum) catch unreachable;

// Expected rejection logs are part of this fixture's assertions, not runner errors.
pub const std_options: std.Options = .{ .logFn = observeLog };
var rejection_logs: usize = 0;

fn observeLog(
    comptime level: std.log.Level,
    comptime scope: @EnumLiteral(),
    comptime format: []const u8,
    args: anytype,
) void {
    _ = scope;
    var actual_buffer: [256]u8 = undefined;
    const actual = std.fmt.bufPrint(&actual_buffer, format, args) catch unreachable;
    const floor = minimum orelse @panic("unexpected log in default entrypoint fixture");
    var expected_buffer: [256]u8 = undefined;
    const expected = std.fmt.bufPrint(
        &expected_buffer,
        "gdzig requires Godot {d}.{d}.{d} or newer; running {d}.{d}.{d}",
        .{
            floor.major,
            floor.minor,
            floor.patch,
            state.actual.major,
            state.actual.minor,
            state.actual.patch,
        },
    ) catch unreachable;
    if (level != .err or !std.mem.eql(u8, actual, expected)) {
        std.debug.panic("unexpected entrypoint log: {s}", .{actual});
    }
    rejection_logs += 1;
}

fn reset(actual: gdzig.Version) void {
    rejection_logs = 0;
    state.actual = actual;
    state.queries = 0;
    state.interface_lookups = 0;
    state.registrations = 0;
    state.startups = 0;
}

fn expectVersion(actual: gdzig.Version) !void {
    const effective = minimum orelse actual;
    try std.testing.expectEqual(effective.major, gdzig.version.major);
    try std.testing.expectEqual(effective.minor, gdzig.version.minor);
    try std.testing.expectEqual(effective.patch, gdzig.version.patch);
}

test "real normal entrypoint queries once and rejects before registration" {
    const cases = [_]gdzig.Version{
        minimum orelse .@"4.6",
        .{ .major = 4, .minor = 7, .patch = 2 },
        .{ .major = 4, .minor = 5, .patch = 0 },
    };
    for (cases) |actual| {
        reset(actual);
        var library: u8 = 0;
        // SAFETY: Accepted initialization writes this storage. Rejection leaves
        // it untouched, and this test never reads it in either case.
        var initialization: gdzig.c.GDExtensionInitialization = undefined;
        const result = gdextension_entry(&state.proc, &library, &initialization);
        const rejected = if (minimum) |floor| actual.lt(floor) else false;
        try std.testing.expectEqual(@as(usize, 1), state.interface_lookups);
        try std.testing.expectEqual(@as(usize, 1), state.queries);
        try std.testing.expectEqual(@as(usize, if (rejected) 1 else 0), rejection_logs);
        try std.testing.expectEqual(@as(usize, if (rejected) 0 else 1), state.registrations);
        try std.testing.expectEqual(@as(gdzig.c.GDExtensionBool, if (rejected) 0 else 1), result);
        if (!rejected) try expectVersion(actual);
    }
}

test "real IPC entrypoint queries once and rejects before startup" {
    // The real IPC server must not read host stdin in this isolated fixture.
    try std.testing.expect(std.c.getenv("GDZIG_TEST_MODE") == null);
    const cases = [_]gdzig.Version{
        minimum orelse .@"4.6",
        .{ .major = 4, .minor = 7, .patch = 2 },
        .{ .major = 4, .minor = 5, .patch = 0 },
    };
    for (cases) |actual| {
        reset(actual);
        var library: u8 = 0;
        var initialization = std.mem.zeroes(gdzig.c.GDExtensionInitialization);
        const result = gdzig_compatibility_minimum_harness_entry(&state.proc, &library, &initialization);
        const rejected = if (minimum) |floor| actual.lt(floor) else false;
        try std.testing.expectEqual(@as(usize, 1), state.interface_lookups);
        try std.testing.expectEqual(@as(usize, 1), state.queries);
        try std.testing.expectEqual(@as(usize, if (rejected) 1 else 0), rejection_logs);
        try std.testing.expectEqual(@as(gdzig.c.GDExtensionBool, if (rejected) 0 else 1), result);
        if (rejected) {
            try std.testing.expect(initialization.initialize == null);
            try std.testing.expect(initialization.deinitialize == null);
        } else {
            try expectVersion(actual);
            initialization.initialize.?(null, initialization.minimum_initialization_level);
        }
        try std.testing.expectEqual(@as(usize, if (rejected) 0 else 1), state.startups);
    }
}

const std = @import("std");

const gdzig = @import("runtime");
const fixture_options = @import("fixture_options");
const state = @import("state");
const entrypoint = @import("entrypoint");
const harness = @import("harness");
