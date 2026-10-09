//! Exercise the selected public bindings inside the existing IPC harness.
const minimum: ?gdzig.Version = if (std.mem.eql(u8, fixture_options.compatibility_minimum, "none"))
    null
else
    gdzig.Version.parseStrict(fixture_options.compatibility_minimum) catch unreachable;

comptime {
    if (minimum) |floor| {
        if (gdzig.version.major != floor.major or
            gdzig.version.minor != floor.minor or
            gdzig.version.patch != floor.patch)
        {
            @compileError("selected version must be comptime-known and equal to the minimum");
        }
    }
}

/// Retain the selected identity in the installed IPC extension binary.
pub export fn gdzig_compatibility_minimum_identity() callconv(.c) [*:0]const u8 {
    return "GDZIG_COMPATIBILITY_MINIMUM_BINARY=" ++ fixture_options.compatibility_minimum;
}

test "actual runtime identity is independent of effective compatibility target" {
    var actual: gdzig.Version = undefined;
    gdzig.raw.getGodotVersion(@ptrCast(&actual));
    var reported = gdzig.class.Engine.getVersionInfo();
    defer reported.deinit();
    const keys = [_][]const u8{ "major", "minor", "patch" };
    const values = [_]u32{ actual.major, actual.minor, actual.patch };
    for (keys, values) |key, value| {
        var name: gdzig.builtin.String = .fromLatin1(key);
        defer name.deinit();
        var component = reported.get(gdzig.builtin.Variant.wrap(gdzig.builtin.String, &name), .{});
        defer component.deinit();
        try std.testing.expectEqual(value, @as(u32, @intCast(component.as(i64).?)));
    }
    const effective = minimum orelse actual;
    try std.testing.expectEqual(effective.major, gdzig.version.major);
    try std.testing.expectEqual(effective.minor, gdzig.version.minor);
    try std.testing.expectEqual(effective.patch, gdzig.version.patch);
}

test "fixed vararg and Alloc binds preserve deterministic Object results and caches" {
    const node: *gdzig.class.Node = .init();
    defer node.destroy();
    const object = gdzig.class.Object.upcast(node);
    for (0..2) |_| {
        var result = object.call(.fromComptimeLatin1("get_instance_id"), .{});
        defer result.deinit();
        var allocated = object.callAlloc(.fromComptimeLatin1("get_instance_id"), .{});
        defer allocated.deinit();
        try std.testing.expectEqual(@as(i64, @intCast(object.getInstanceId())), result.as(i64).?);
        try std.testing.expectEqual(result.as(i64).?, allocated.as(i64).?);
    }
}

test "builtin historical sole compatibility entries keep primary and cached behavior" {
    var bytes: gdzig.builtin.PackedByteArray = .init();
    defer bytes.deinit();
    for ([_]i64{ 2, 4, 8 }) |value| {
        _ = bytes.append(value);
    }
    try std.testing.expectEqual(@as(i64, 3), bytes.size());
    try std.testing.expectEqual(@as(i64, 2), bytes.get(0));
    try std.testing.expectEqual(@as(i64, 4), bytes.get(1));
    for (0..2) |_| {
        try std.testing.expectEqual(@as(i64, 1), bytes.bsearch(4, .{}));
        var copy = bytes.duplicate();
        defer copy.deinit();
        try std.testing.expectEqual(@as(i64, 3), copy.size());
        try std.testing.expectEqual(@as(i64, 8), copy.get(2));
        try std.testing.expectEqual(@as(i64, 1), copy.bsearch(4, .{}));
    }
}

const std = @import("std");

const gdzig = @import("gdzig");
const fixture_options = @import("fixture_options");
