var godot_allocator: godot.godot_allocator = .{};

comptime {
    godot.entrypoint("my_extension_init", .{
        .allocator = godot_allocator.allocator(),
        .init = &init,
        .deinit = &deinit,
    });
}

fn init(level: godot.InitializationLevel) void {
    std.debug.print("[{s}] init\n", .{@tagName(level)});

    if (level == .scene) {
        godot.registerClass(@import("ExampleNode.zig"), .{});
    }
}

fn deinit(level: godot.InitializationLevel) void {
    std.debug.print("[{s}] deinit\n", .{@tagName(level)});
}

const std = @import("std");
const godot = @import("gdzig");
