const std = @import("std");
const gdzig = @import("gdzig");
const c = gdzig.c;

pub var get_godot_version_calls: usize = 0;

pub fn reset() void {
    get_godot_version_calls = 0;
}

pub fn getProcAddress(name_ptr: [*c]const u8) callconv(.c) c.GDExtensionInterfaceFunctionPtr {
    const name = std.mem.span(@as([*:0]const u8, @ptrCast(name_ptr)));
    if (std.mem.eql(u8, name, "get_godot_version")) return @ptrCast(&getGodotVersion);
    return @ptrCast(&stub);
}

pub fn expectVersion(version: gdzig.Version) !void {
    try std.testing.expectEqual(@as(u32, 4), version.major);
    try std.testing.expectEqual(@as(u32, 6), version.minor);
    try std.testing.expectEqual(@as(u32, 7), version.patch);
}

fn getGodotVersion(version: *c.GDExtensionGodotVersion) callconv(.c) void {
    get_godot_version_calls += 1;
    version.* = .{
        .major = 4,
        .minor = 6,
        .patch = 7,
        .string = "4.6.7-test",
    };
}

fn stub() callconv(.c) void {}
