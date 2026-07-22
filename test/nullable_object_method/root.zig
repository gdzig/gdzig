pub fn register(r: *gdzig.extension.Registry) void {
    r.addClass(NullableResource, {}, .auto);
    const class = r.createClass(NullableObjectNode, {}, .auto);
    class.addMethod("accept_node", .auto);
    class.addMethod("null_node", .auto);
    class.addMethod("accept_resource", .auto);
    class.addMethod("echo_resource", .auto);
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

test "ptrcall accepts and returns nullable extension RefCounted pointers" {
    ensureRegistered();

    const receiver = try NullableObjectNode.create();
    defer receiver.base.destroy();
    const resource = try NullableResource.create();
    defer resource.base.destroy();

    const accept_config = gdzig.extension.testing.MethodConfig(NullableObjectNode).fromName(
        "accept_resource",
        "acceptResource",
        .{},
    );

    var resource_ref: ?*anyopaque = null;
    gdzig.raw.refSetObject(@ptrCast(&resource_ref), @ptrCast(resource.base));
    defer gdzig.raw.refSetObject(@ptrCast(&resource_ref), null);

    const resource_args = [_]?*const anyopaque{@ptrCast(&resource_ref)};
    var accepted: u8 = 0;
    accept_config.ptr_call.?(receiver, @ptrCast(&resource_args), @ptrCast(&accepted));
    try testing.expectEqual(@as(u8, 1), accepted);

    var null_ref: ?*anyopaque = null;
    const null_args = [_]?*const anyopaque{@ptrCast(&null_ref)};
    accepted = 1;
    accept_config.ptr_call.?(receiver, @ptrCast(&null_args), @ptrCast(&accepted));
    try testing.expectEqual(@as(u8, 0), accepted);

    const echo_config = gdzig.extension.testing.MethodConfig(NullableObjectNode).fromName(
        "echo_resource",
        "echoResource",
        .{},
    );

    var returned_ref: ?*anyopaque = null;
    echo_config.ptr_call.?(receiver, @ptrCast(&resource_args), @ptrCast(&returned_ref));
    defer gdzig.raw.refSetObject(@ptrCast(&returned_ref), null);
    try testing.expectEqual(@as(?*anyopaque, @ptrCast(resource.base)), gdzig.raw.refGetObject(@ptrCast(&returned_ref)));

    gdzig.raw.refSetObject(@ptrCast(&returned_ref), null);
    echo_config.ptr_call.?(receiver, @ptrCast(&null_args), @ptrCast(&returned_ref));
    try testing.expect(gdzig.raw.refGetObject(@ptrCast(&returned_ref)) == null);
}

test "ptrcall accepts and returns nullable non-RefCounted object pointers" {
    ensureRegistered();

    const receiver = try NullableObjectNode.create();
    defer receiver.base.destroy();
    const node = Node.init();
    defer node.destroy();

    const accept_config = gdzig.extension.testing.MethodConfig(NullableObjectNode).fromName(
        "accept_node",
        "acceptNode",
        .{},
    );

    const node_args = [_]?*const anyopaque{@ptrCast(node)};
    var accepted: u8 = 0;
    accept_config.ptr_call.?(receiver, @ptrCast(&node_args), @ptrCast(&accepted));
    try testing.expectEqual(@as(u8, 1), accepted);

    const null_args = [_]?*const anyopaque{null};
    accepted = 1;
    accept_config.ptr_call.?(receiver, @ptrCast(&null_args), @ptrCast(&accepted));
    try testing.expectEqual(@as(u8, 0), accepted);

    const null_config = gdzig.extension.testing.MethodConfig(NullableObjectNode).fromName(
        "null_node",
        "nullNode",
        .{},
    );

    var returned_ptr: ?*Node = node;
    null_config.ptr_call.?(receiver, @ptrCast(&[_]?*const anyopaque{}), @ptrCast(&returned_ptr));
    try testing.expect(returned_ptr == null);
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

    pub fn acceptResource(self: *NullableObjectNode, resource: ?*NullableResource) bool {
        _ = self;
        return resource != null;
    }

    pub fn echoResource(self: *NullableObjectNode, resource: ?*NullableResource) ?*NullableResource {
        _ = self;
        return resource;
    }
};

const NullableResource = struct {
    base: *Resource,

    pub fn create() !*NullableResource {
        const self = try allocator.create(NullableResource);
        self.* = .{ .base = .init() };
        self.base.setInstance(NullableResource, self);
        return self;
    }

    pub fn destroy(self: *NullableResource) void {
        allocator.destroy(self);
    }
};

const std = @import("std");
const testing = std.testing;

const gdzig = @import("gdzig");
const allocator = gdzig.testing.allocator;
const Node = gdzig.class.Node;
const Object = gdzig.class.Object;
const Resource = gdzig.class.Resource;
const Variant = gdzig.builtin.Variant;
