/// Integration test for Zig <-> Godot interoperability.
///
/// This test validates cross-FFI calls between Zig and GDScript objects:
/// - ZigObject: A Zig class with methods, virtual methods, and signals
/// - GodotObject: A GDScript class with methods and signals (defined in test.gd)
/// - ZigObjectExtension: A GDScript class extending ZigObject (defined in test.gd)
///
/// The test verifies (from both Zig and GDScript sides):
/// 1. Zig methods callable from GDScript (zig_method)
/// 2. Passing Zig objects between Zig methods (receive_zig_object)
/// 3. Signals emitted from Zig received by GDScript (ZigSignal -> "zig")
/// 4. GDScript extending Zig classes with virtual method overrides (_ready)
/// 5. GDScript objects with methods (GodotObject.godot_method)
/// 6. Signals emitted from GDScript received by Zig (godot_signal -> on_godot_signal)
///
/// Note: This test requires Godot 4.2+ due to GDScript interop requirements.
pub fn init() void {
    // Skip on Godot 4.1 - GDScript calling extension class methods requires 4.2+
    if (!godot.version.gte(.@"4.2")) return;
    godot.registerClass(ZigObject, .{ .userdata = &testing.allocator });
    godot.registerMethod(ZigObject, .zigMethod);
    godot.registerMethod(ZigObject, .receiveZigObject);
    godot.registerMethod(ZigObject, .getCallCount);
    godot.registerMethod(ZigObject, .getLastReceivedValue);
    godot.registerMethod(ZigObject, .getSignalReceivedValue);
    godot.registerSignal(ZigObject, ZigSignal);
    godot.registerMethod(ZigObject, .emitZigSignal);
    godot.registerMethod(ZigObject, .onGodotSignal);
}

pub fn run() !void {
    // Basic test: Create a ZigObject and verify it works
    const zig_obj = try ZigObject.create(&testing.allocator);
    defer zig_obj.destroy(&testing.allocator);

    // Test that the Zig method works
    const result = zig_obj.zigMethod(10, 20);
    try testing.expectEqual(30, result);

    // Test passing a ZigObject to another ZigObject
    const zig_obj2 = try ZigObject.create(&testing.allocator);
    defer zig_obj2.destroy(&testing.allocator);

    // Increment call_count on zig_obj2 by calling zigMethod
    _ = zig_obj2.zigMethod(1, 2);

    // Pass zig_obj2 to zig_obj1 - this tests that Zig objects can be passed between each other
    zig_obj.receiveZigObject(zig_obj2);

    // Verify zig_obj received the call_count from zig_obj2
    try testing.expectEqual(1, zig_obj.last_received_value);

    // Note: Zig → GDScript method calls are tested from the GDScript side (test.gd)
    // where GDScript creates a GodotObject and passes it to ZigObject.
    // The comprehensive GDScript tests validate:
    // - GDScript calling Zig methods
    // - GDScript signals to Zig
    // - Zig signals to GDScript
    // - GDScript extending Zig classes
    // - Passing objects across FFI boundary
}

/// Signal emitted by ZigObject
pub const ZigSignal = struct {
    value: i64,
};

/// A Zig-implemented class that can be called from GDScript
pub const ZigObject = struct {
    base: *Node,
    call_count: i64 = 0,
    last_received_value: i64 = 0,
    signal_received_value: i64 = 0,
    virtual_called: bool = false,
    virtual_value: i64 = 0,

    pub fn create(allocator: *const Allocator) !*ZigObject {
        const self = try allocator.create(ZigObject);
        self.* = .{ .base = Node.init() };
        self.base.setInstance(ZigObject, self);
        return self;
    }

    pub fn destroy(self: *ZigObject, allocator: *const Allocator) void {
        self.base.destroy();
        allocator.destroy(self);
    }

    /// A regular method callable from GDScript
    pub fn zigMethod(self: *ZigObject, a: i64, b: i64) i64 {
        self.call_count += 1;
        return a + b;
    }

    /// Receives another ZigObject and reads its state
    /// This tests passing custom Zig objects across the FFI boundary
    pub fn receiveZigObject(self: *ZigObject, other: *ZigObject) void {
        // Copy the call_count from the other ZigObject to verify we can access its state
        // We use call_count since it can be set via zig_method() from GDScript
        self.last_received_value = other.call_count;
    }

    /// Get the call count for verification
    pub fn getCallCount(self: *ZigObject) i64 {
        return self.call_count;
    }

    /// Get last received value for verification
    pub fn getLastReceivedValue(self: *ZigObject) i64 {
        return self.last_received_value;
    }

    /// Get signal received value for verification
    pub fn getSignalReceivedValue(self: *ZigObject) i64 {
        return self.signal_received_value;
    }

    /// Signal handler for GDScript signals
    /// This method is called when a GDScript object emits godot_signal
    pub fn onGodotSignal(self: *ZigObject, value: i64) void {
        self.signal_received_value = value;
    }

    /// Virtual method that can be overridden in GDScript
    pub fn _ready(self: *ZigObject) void {
        self.virtual_called = true;
        self.virtual_value = 42;
    }

    /// Emit a signal for GDScript to receive
    pub fn emitZigSignal(self: *ZigObject, value: i64) void {
        self.base.emit(ZigSignal, .{ .value = value }) catch {};
    }
};

const std = @import("std");
const Allocator = std.mem.Allocator;

const godot = @import("gdzig");
const Node = godot.class.Node;
const testing = @import("gdzig_test");
