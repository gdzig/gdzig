pub fn register(r: *gdzig.extension.Registry) void {
    const emitter_class = r.createClass(SignalEmitter, {}, .auto);
    emitter_class.addSignal(TestSignal);

    const receiver_class = r.createClass(SignalReceiver, {}, .auto);
    receiver_class.addMethod("on_signal", .auto);
}

fn ensureRegistered() void {
    const S = struct {
        var done: bool = false;
    };
    if (!S.done) {
        S.done = true;
        gdzig.testing.loadModule(@This());
    }
}

test "signal connect and emit" {
    ensureRegistered();

    const emitter = try SignalEmitter.create();
    defer emitter.destroy();

    const receiver = try SignalReceiver.create();
    defer receiver.destroy();

    const callable: Callable = .fromClosure(receiver, &SignalReceiver.onSignal);

    try emitter.base.connect(TestSignal, callable);

    try testing.expectEqual(@as(i64, 0), receiver.count);
    try testing.expectEqual(@as(i64, 0), receiver.value);

    try emitter.base.emit(TestSignal, .{ .value = 42 });

    try testing.expectEqual(@as(i64, 1), receiver.count);
    try testing.expectEqual(@as(i64, 42), receiver.value);

    emitter.base.disconnect(TestSignal, callable);

    try emitter.base.emit(TestSignal, .{ .value = 99 });

    try testing.expectEqual(@as(i64, 1), receiver.count);
    try testing.expectEqual(@as(i64, 42), receiver.value);
}

const TestSignal = struct {
    value: i64,
};

const SignalEmitter = struct {
    base: *Object,

    pub fn create() !*SignalEmitter {
        const self = try allocator.create(SignalEmitter);
        self.* = .{ .base = Object.init() };
        self.base.setInstance(SignalEmitter, self);
        return self;
    }

    pub fn destroy(self: *SignalEmitter) void {
        self.base.destroy();
        allocator.destroy(self);
    }
};

const SignalReceiver = struct {
    base: *Object,
    count: i64 = 0,
    value: i64 = 0,

    pub fn create() !*SignalReceiver {
        const self = try allocator.create(SignalReceiver);
        self.* = .{ .base = Object.init() };
        self.base.setInstance(SignalReceiver, self);
        return self;
    }

    pub fn destroy(self: *SignalReceiver) void {
        self.base.destroy();
        allocator.destroy(self);
    }

    pub fn onSignal(self: *SignalReceiver, value: i64) void {
        self.value = value;
        self.count += 1;
    }
};

const std = @import("std");
const testing = std.testing;

const gdzig = @import("gdzig");
const allocator = gdzig.testing.allocator;
const Callable = gdzig.builtin.Callable;
const Object = gdzig.class.Object;
