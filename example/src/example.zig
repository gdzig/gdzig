var gpa: std.heap.DebugAllocator(.{}) = .init;

comptime {
    godot.entrypoint("my_extension_init", .{ .init = &init, .deinit = &deinit });
}

fn init(level: godot.InitializationLevel) void {
    std.debug.print("[{s}] init\n", .{@tagName(level)});

    if (level == .scene) {
        godot.registerClass(@import("ExampleNode.zig"), .{});
    }
}

fn deinit(level: godot.InitializationLevel) void {
    std.debug.print("[{s}] deinit\n", .{@tagName(level)});

    if (level == .core) {
        _ = gpa.deinit();
    }
}

const std = @import("std");
const Allocator = std.mem.Allocator;
const DebugAllocator = std.heap.DebugAllocator;

const godot = @import("gdzig");
