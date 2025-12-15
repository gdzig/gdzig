pub fn init() void {
    TestNode.register();
}

pub fn run() !void {
    const node = TestNode.create() catch return error.CreateFailed;
    defer node.base.destroy();
    // Godot will call node.destroy via callback

    _ = Object.call(.upcast(node), .fromComptimeLatin1("increment"), .{});
    try testing.expectCall(node, "get_counter", .{}, @as(i64, 1));

    try testing.expectCall(node, "add_value", .{@as(i64, 10)}, @as(i64, 11));
    try testing.expectCall(node, "get_counter", .{}, @as(i64, 11));

    try testing.expectCall(node, "get_my_property", .{}, @as(i64, 42));
    _ = Object.call(.upcast(node), .fromComptimeLatin1("set_my_property"), .{@as(i64, 100)});
    try testing.expectCall(node, "get_my_property", .{}, @as(i64, 100));

    try testing.expectCall(node, "get_indexed_value", .{@as(i64, 1)}, @as(i64, 200));
    _ = Object.call(.upcast(node), .fromComptimeLatin1("set_indexed_value"), .{ @as(i64, 1), @as(i64, 999) });
    try testing.expectCall(node, "get_indexed_value", .{@as(i64, 1)}, @as(i64, 999));
}

const godot = @import("gdzig");
const Node = godot.class.Node;
const Object = godot.class.Object;
const StringName = godot.builtin.StringName;
const testing = @import("gdzig_test");

const TestNode = @import("TestNode.zig");
