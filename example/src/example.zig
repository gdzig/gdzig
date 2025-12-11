comptime {
    godot.registerExtension(Extension, .{ .entry_symbol = "my_extension_init" });
}

pub const Extension = struct {
    gpa: DebugAllocator(.{}),
    allocator: Allocator,

    pub fn create() !*Extension {
        var gpa: DebugAllocator(.{}) = .init;
        const self = try gpa.allocator().create(Extension);
        self.gpa = gpa;
        self.allocator = self.gpa.allocator();
        return self;
    }

    pub fn init(self: *Extension, level: InitializationLevel) void {
        if (level == .scene) {
            godot.registerClass(ExampleNode, .{ .userdata = &self.allocator });
            godot.registerMethod(ExampleNode, .onTimeout);
            godot.registerMethod(ExampleNode, .onResized);
            godot.registerMethod(ExampleNode, .onItemFocused);

            godot.registerClass(GuiNode, .{ .userdata = &self.allocator });
            godot.registerMethod(GuiNode, .onPressed);
            godot.registerMethod(GuiNode, .onToggled);

            godot.registerClass(SignalNode, .{ .userdata = &self.allocator });
            godot.registerMethod(SignalNode, .onSignal1);
            godot.registerMethod(SignalNode, .onSignal2);
            godot.registerMethod(SignalNode, .onSignal3);
            godot.registerMethod(SignalNode, .emitSignal1);
            godot.registerMethod(SignalNode, .emitSignal2);
            godot.registerMethod(SignalNode, .emitSignal3);
            godot.registerSignal(SignalNode, SignalNode.Signal1);
            godot.registerSignal(SignalNode, SignalNode.Signal2);
            godot.registerSignal(SignalNode, SignalNode.Signal3);

            godot.registerClass(SpriteNode, .{ .userdata = &self.allocator });
        }
    }

    pub fn destroy(self: *Extension) void {
        _ = self.gpa.deinit();
    }
};

const std = @import("std");
const Allocator = std.mem.Allocator;
const DebugAllocator = std.heap.DebugAllocator;
const InitializationLevel = godot.InitializationLevel;

const godot = @import("gdzig");

const ExampleNode = @import("ExampleNode.zig");
const GuiNode = @import("GuiNode.zig");
const SignalNode = @import("SignalNode.zig");
const SpriteNode = @import("SpriteNode.zig");
