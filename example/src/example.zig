comptime {
    godot.registerExtension(Extension, .{ .entry_symbol = "my_extension_init" });
}

var gpa: DebugAllocator(.{}) = .init;

pub const Extension = struct {
    class_userdata: Allocator,

    pub fn init() !Extension {
        return .{ .class_userdata = gpa.allocator() };
    }

    pub fn enter(self: *Extension, level: InitializationLevel) void {
        if (level == .scene) {
            godot.registerClass(ExampleNode, .{ .userdata = &self.class_userdata });
            godot.registerMethod(ExampleNode, .onTimeout);
            godot.registerMethod(ExampleNode, .onResized);
            godot.registerMethod(ExampleNode, .onItemFocused);

            godot.registerClass(GuiNode, .{ .userdata = &self.class_userdata });
            godot.registerMethod(GuiNode, .onPressed);
            godot.registerMethod(GuiNode, .onToggled);

            godot.registerClass(SignalNode, .{ .userdata = &self.class_userdata });
            godot.registerMethod(SignalNode, .onSignal1);
            godot.registerMethod(SignalNode, .onSignal2);
            godot.registerMethod(SignalNode, .onSignal3);
            godot.registerMethod(SignalNode, .emitSignal1);
            godot.registerMethod(SignalNode, .emitSignal2);
            godot.registerMethod(SignalNode, .emitSignal3);
            godot.registerSignal(SignalNode, SignalNode.Signal1);
            godot.registerSignal(SignalNode, SignalNode.Signal2);
            godot.registerSignal(SignalNode, SignalNode.Signal3);

            godot.registerClass(SpriteNode, .{ .userdata = &self.class_userdata });
        }
    }

    pub fn deinit(self: *Extension) void {
        _ = self;
        assert(gpa.deinit() == .ok);
    }
};

const std = @import("std");
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;
const DebugAllocator = std.heap.DebugAllocator;
const InitializationLevel = godot.global.InitializationLevel;

const godot = @import("gdzig");

const ExampleNode = @import("ExampleNode.zig");
const GuiNode = @import("GuiNode.zig");
const SignalNode = @import("SignalNode.zig");
const SpriteNode = @import("SpriteNode.zig");
