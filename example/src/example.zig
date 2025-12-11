comptime {
    godot.entrypoint("my_extension_init", .{ .init = &init, .deinit = &deinit });
}

var gpa: std.heap.DebugAllocator(.{}) = .{
    .backing_allocator = godot.heap.godot_allocator.allocator(),
};

fn init(level: godot.InitializationLevel) void {
    std.debug.print("[{s}] init\n", .{@tagName(level)});

    if (level == .scene) {
        godot.registerClass(gpa.allocator(), @import("ExampleNode.zig"), .{});
        godot.registerClass(gpa.allocator(), @import("SpriteNode.zig"), .{});
        godot.registerClass(gpa.allocator(), @import("GuiNode.zig"), .{});
        godot.registerClass(gpa.allocator(), @import("SignalNode.zig"), .{});
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
