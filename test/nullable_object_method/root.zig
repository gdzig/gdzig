pub fn register(r: *gdzig.extension.Registry) void {
    const class = r.createClass(NullableObjectNode, {}, .auto);
    class.addMethod("accept_node", .auto);
    class.addMethod("null_node", .auto);
}

fn ensureRegistered() void {
    const State = struct {
        var done = false;
    };
    if (!State.done) {
        State.done = true;
        gdzig.testing.loadModule(@This());
    }
}

test "bound methods accept and return nullable object pointers" {
    ensureRegistered();

    const receiver = try NullableObjectNode.create();
    defer receiver.base.destroy();

    const rejected = Object.call(.upcast(receiver), .fromComptimeLatin1("accept_node"), .{@as(?*Node, null)});
    defer rejected.deinit();
    try testing.expect(!rejected.as(bool).?);

    const node = Node.init();
    defer node.destroy();
    const accepted = Object.call(.upcast(receiver), .fromComptimeLatin1("accept_node"), .{@as(?*Node, node)});
    defer accepted.deinit();
    try testing.expect(accepted.as(bool).?);

    const returned = Object.call(.upcast(receiver), .fromComptimeLatin1("null_node"), .{});
    defer returned.deinit();
    try testing.expectEqual(Variant.Tag.nil, returned.tag);
    const nullable = returned.as(?*Node);
    try testing.expect(nullable != null);
    try testing.expect(nullable.? == null);
}

const NullableObjectNode = struct {
    base: *Node,

    pub fn create() !*NullableObjectNode {
        const self = try allocator.create(NullableObjectNode);
        self.* = .{ .base = .init() };
        self.base.setInstance(NullableObjectNode, self);
        return self;
    }

    pub fn destroy(self: *NullableObjectNode) void {
        allocator.destroy(self);
    }

    pub fn acceptNode(self: *NullableObjectNode, node: ?*Node) bool {
        _ = self;
        return node != null;
    }

    pub fn nullNode(self: *NullableObjectNode) ?*Node {
        _ = self;
        return null;
    }
};

const std = @import("std");
const testing = std.testing;

const gdzig = @import("gdzig");
const allocator = gdzig.testing.allocator;
const Node = gdzig.class.Node;
const Object = gdzig.class.Object;
const Variant = gdzig.builtin.Variant;
