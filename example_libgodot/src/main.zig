const std = @import("std");
const godot = @import("godot");
const builtin = @import("builtin");

const LibGodot = godot.extension.LibGodot;

const example = @import("example/example.zig");

const winhelpers = if (builtin.os.tag == .windows) struct {
    extern "user32" fn SetCursor(hCursor: ?*anyopaque) callconv(.c) ?*anyopaque;
    extern "user32" fn LoadCursorA(hInstance: ?*anyopaque, lpCursorName: [*:0]const u8) callconv(.c) ?*anyopaque;

    pub const IDC_ARROW = @as([*:0]const u8, @ptrFromInt(32512));
} else struct {};

pub fn main() !void {
    const hArrow = if (comptime builtin.os.tag == .windows) winhelpers.LoadCursorA(null, winhelpers.IDC_ARROW) else void;

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    std.debug.print("Starting Godot instance...\n", .{});

    // Create a GodotInstance with LibGodot
    const instance = LibGodot.createGodotInstance(
        args,
        .scene,
        &example.register,
    );
    // Destroy instance when we're done
    defer LibGodot.destroyGodotInstance(instance);

    std.debug.print("Godot instance created successfully\n", .{});

    // Start the instance
    if (!instance.start())
        return error.StartFailed;

    // Call iteration which ticks the engine
    while (!instance.iteration()) {
        if (comptime builtin.os.tag == .windows) {
            _ = winhelpers.SetCursor(hArrow); // Work around https://github.com/godotengine/godot/issues/113125
        }
    }
}
