pub fn init() void {
    godot.registerClass(SignalEmitter, .{ .userdata = &testing.allocator });
    godot.registerSignal(SignalEmitter, TestSignal);
    godot.registerClass(SignalReceiver, .{ .userdata = &testing.allocator });
    godot.registerMethod(SignalReceiver, .onSignal);
}

pub fn run() !void {
    const emitter = try SignalEmitter.create(&testing.allocator);
    defer emitter.destroy(&testing.allocator);

    const receiver = try SignalReceiver.create(&testing.allocator);
    defer receiver.destroy(&testing.allocator);

    const callable: Callable = .fromClosure(receiver, &SignalReceiver.onSignal);

    try emitter.base.connect(TestSignal, callable);

    try testing.expectEqual(0, receiver.count);
    try testing.expectEqual(0, receiver.value);

    try emitter.base.emit(TestSignal{ .value = 42 });

    try testing.expectEqual(1, receiver.count);
    try testing.expectEqual(42, receiver.value);

    emitter.base.disconnect(TestSignal, callable);

    try emitter.base.emit(TestSignal{ .value = 99 });

    try testing.expectEqual(1, receiver.count);
    try testing.expectEqual(42, receiver.value);
}

const TestSignal = struct {
    value: i64,
};

const SignalEmitter = struct {
    base: *Object,

    pub fn create(allocator: *const Allocator) !*SignalEmitter {
        const self = try allocator.create(SignalEmitter);
        self.* = .{ .base = Object.init() };
        self.base.setInstance(SignalEmitter, self);
        return self;
    }

    pub fn destroy(self: *SignalEmitter, allocator: *const Allocator) void {
        self.base.destroy();
        allocator.destroy(self);
    }
};

const SignalReceiver = struct {
    base: *Object,
    count: i64 = 0,
    value: i64 = 0,

    pub fn create(allocator: *const Allocator) !*SignalReceiver {
        const self = try allocator.create(SignalReceiver);
        self.* = .{ .base = Object.init() };
        self.base.setInstance(SignalReceiver, self);
        return self;
    }

    pub fn destroy(self: *SignalReceiver, allocator: *const Allocator) void {
        self.base.destroy();
        allocator.destroy(self);
    }

    pub fn onSignal(self: *SignalReceiver, value: i64) void {
        self.value = value;
        self.count += 1;
    }
};

const std = @import("std");
const Allocator = std.mem.Allocator;

const godot = @import("gdzig");
const Callable = godot.builtin.Callable;
const Object = godot.class.Object;
const testing = @import("gdzig_test");
