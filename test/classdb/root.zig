pub fn register(r: *gdzig.extension.Registry) void {
    const class = r.createClass(TestNode, {}, .auto);
    class.addEnum(TestState);
    class.addMethod("increment", .auto);
    class.addMethod("get_counter", .auto);
    class.addMethod("add_value", .auto);
    class.addMethod("get_my_property", .auto);
    class.addMethod("set_my_property", .auto);
    class.addMethod("get_indexed_value", .auto);
    class.addMethod("set_indexed_value", .auto);
    class.addMethod("get_state", .auto);
    class.addMethod("get_state_negative", .auto);
    class.addMethod("echo_state", .auto);
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

test "create custom class and call methods" {
    ensureRegistered();

    const node = try TestNode.create();
    defer node.base.destroy();

    _ = Object.call(.upcast(node), .fromComptimeLatin1("increment"), .{});

    var result = Object.call(.upcast(node), .fromComptimeLatin1("get_counter"), .{});
    try testing.expectEqual(@as(i64, 1), result.as(i64).?);

    result = Object.call(.upcast(node), .fromComptimeLatin1("add_value"), .{@as(i64, 10)});
    try testing.expectEqual(@as(i64, 11), result.as(i64).?);

    result = Object.call(.upcast(node), .fromComptimeLatin1("get_counter"), .{});
    try testing.expectEqual(@as(i64, 11), result.as(i64).?);
}

test "custom class properties" {
    ensureRegistered();

    const node = try TestNode.create();
    defer node.base.destroy();

    var result = Object.call(.upcast(node), .fromComptimeLatin1("get_my_property"), .{});
    try testing.expectEqual(@as(i64, 42), result.as(i64).?);

    _ = Object.call(.upcast(node), .fromComptimeLatin1("set_my_property"), .{@as(i64, 100)});

    result = Object.call(.upcast(node), .fromComptimeLatin1("get_my_property"), .{});
    try testing.expectEqual(@as(i64, 100), result.as(i64).?);
}

test "indexed properties" {
    ensureRegistered();

    // Indexed properties require Godot 4.2+
    if (!gdzig.version.gte(.@"4.2")) return;

    const node = try TestNode.create();
    defer node.base.destroy();

    var result = Object.call(.upcast(node), .fromComptimeLatin1("get_indexed_value"), .{@as(i64, 1)});
    try testing.expectEqual(@as(i64, 200), result.as(i64).?);

    _ = Object.call(.upcast(node), .fromComptimeLatin1("set_indexed_value"), .{ @as(i64, 1), @as(i64, 999) });

    result = Object.call(.upcast(node), .fromComptimeLatin1("get_indexed_value"), .{@as(i64, 1)});
    try testing.expectEqual(@as(i64, 999), result.as(i64).?);
}

test "narrow enum return through varcall is widened to slot width" {
    ensureRegistered();

    const node = try TestNode.create();
    defer node.base.destroy();

    // Varcall boxes the enum(i32) return via Variant.init; the engine reads a
    // full int64 slot, so the high bytes must not be garbage.
    var result = Object.call(.upcast(node), .fromComptimeLatin1("get_state"), .{});
    try testing.expectEqual(@as(i64, 2), result.as(i64).?);

    // Negative values catch both garbage high bytes and bad sign extension.
    result = Object.call(.upcast(node), .fromComptimeLatin1("get_state_negative"), .{});
    try testing.expectEqual(@as(i64, -1), result.as(i64).?);
}

test "varcall and ptrcall return identical values for narrow enum" {
    ensureRegistered();

    const node = try TestNode.create();
    defer node.base.destroy();

    const var_result = Object.call(.upcast(node), .fromComptimeLatin1("get_state_negative"), .{});
    const var_value = var_result.as(i64).?;

    var slot: i64 = 0;
    gdzig.ptrcall.writeReturn(TestState, &slot, .err);

    try testing.expectEqual(@as(i64, -1), slot);
    try testing.expectEqual(slot, var_value);
}

test "narrow enum argument through varcall roundtrips" {
    ensureRegistered();

    const node = try TestNode.create();
    defer node.base.destroy();

    // Varcall extracts the enum(i32) argument via Variant.as; the engine writes
    // a full int64 slot, which must not overwrite past the narrow local.
    var result = Object.call(.upcast(node), .fromComptimeLatin1("echo_state"), .{@as(TestState, .data_loaded)});
    try testing.expectEqual(@as(i64, 2), result.as(i64).?);

    result = Object.call(.upcast(node), .fromComptimeLatin1("echo_state"), .{@as(TestState, .err)});
    try testing.expectEqual(@as(i64, -1), result.as(i64).?);
}

const TestState = enum(i32) {
    uninitialized = 0,
    data_loaded = 2,
    stepping = 3,
    err = -1,
};

const TestNode = struct {
    base: *Node,
    counter: i64 = 0,
    my_property: i64 = 42,
    indexed_values: [3]i64 = .{ 100, 200, 300 },

    pub fn create() !*TestNode {
        const self: *TestNode = allocator.create(TestNode) catch @panic("out of memory");
        self.* = .{ .base = Node.init() };
        self.base.setInstance(TestNode, self);
        return self;
    }

    pub fn destroy(self: *TestNode) void {
        allocator.destroy(self);
    }

    pub fn increment(self: *TestNode) void {
        self.counter += 1;
    }

    pub fn getCounter(self: *TestNode) i64 {
        return self.counter;
    }

    pub fn addValue(self: *TestNode, value: i64) i64 {
        self.counter += value;
        return self.counter;
    }

    pub fn getMyProperty(self: *TestNode) i64 {
        return self.my_property;
    }

    pub fn setMyProperty(self: *TestNode, value: i64) void {
        self.my_property = value;
    }

    pub fn getIndexedValue(self: *TestNode, index: i64) i64 {
        if (index >= 0 and index < 3) {
            return self.indexed_values[@intCast(index)];
        }
        return 0;
    }

    pub fn setIndexedValue(self: *TestNode, index: i64, value: i64) void {
        if (index >= 0 and index < 3) {
            self.indexed_values[@intCast(index)] = value;
        }
    }

    pub fn getState(self: *TestNode) TestState {
        _ = self;
        return .data_loaded;
    }

    pub fn getStateNegative(self: *TestNode) TestState {
        _ = self;
        return .err;
    }

    pub fn echoState(self: *TestNode, state: TestState) TestState {
        _ = self;
        return state;
    }
};

const std = @import("std");
const testing = std.testing;

const gdzig = @import("gdzig");
const allocator = gdzig.testing.allocator;
const Node = gdzig.class.Node;
const Object = gdzig.class.Object;
