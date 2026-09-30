pub fn register(r: *gdzig.extension.Registry) void {
    r.addClass(TrackedResource, {}, .auto);
    const class = r.createClass(OwnedReturnNode, {}, .auto);
    class.addMethod("make_resource", .{ .return_ownership = .transfer });
    class.addMethod("make_builtin_resource", .{ .return_ownership = .transfer });
    class.addMethod("maybe_resource", .{ .return_ownership = .transfer });
    class.addMethod("borrow_resource", .auto);
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

test "varcall transfers a fresh RefCounted return to the Variant" {
    ensureRegistered();
    destroyed_count = 0;

    const node = try OwnedReturnNode.create();
    defer node.base.destroy();

    const result = Object.call(.upcast(node), .fromComptimeLatin1("make_resource"), .{});
    const resource = result.as(*TrackedResource).?;
    try testing.expectEqual(@as(i32, 1), resource.base.getReferenceCount());
    try testing.expectEqual(@as(usize, 0), destroyed_count);

    result.deinit();
    try testing.expectEqual(@as(usize, 1), destroyed_count);
}

test "ptrcall transfers a fresh RefCounted return to the Ref slot" {
    ensureRegistered();
    destroyed_count = 0;

    const node = try OwnedReturnNode.create();
    defer node.base.destroy();

    const config = gdzig.extension.testing.MethodConfig(OwnedReturnNode).fromName(
        "make_resource",
        "makeResource",
        .{ .return_ownership = .transfer },
    );

    var returned_ref: ?*anyopaque = null;
    config.ptr_call.?(node, @ptrCast(&[_]?*const anyopaque{}), @ptrCast(&returned_ref));

    const returned_object = gdzig.raw.refGetObject(@ptrCast(&returned_ref)).?;
    const resource: *Resource = @ptrCast(@alignCast(returned_object));
    try testing.expectEqual(@as(i32, 1), resource.getReferenceCount());
    try testing.expectEqual(@as(usize, 0), destroyed_count);

    gdzig.raw.refSetObject(@ptrCast(&returned_ref), null);
    try testing.expectEqual(@as(usize, 1), destroyed_count);

    config.ptr_call.?(node, @ptrCast(&[_]?*const anyopaque{}), null);
    try testing.expectEqual(@as(usize, 2), destroyed_count);

    for (0..16) |i| {
        returned_ref = null;
        config.ptr_call.?(node, @ptrCast(&[_]?*const anyopaque{}), @ptrCast(&returned_ref));
        const repeated_object = gdzig.raw.refGetObject(@ptrCast(&returned_ref)).?;
        const repeated_resource: *Resource = @ptrCast(@alignCast(repeated_object));
        try testing.expectEqual(@as(i32, 1), repeated_resource.getReferenceCount());
        gdzig.raw.refSetObject(@ptrCast(&returned_ref), null);
        try testing.expectEqual(i + 3, destroyed_count);
    }
}

test "nullable transferred returns preserve null and release non-null values" {
    ensureRegistered();
    destroyed_count = 0;

    const node = try OwnedReturnNode.create();
    defer node.base.destroy();

    const nil_result = Object.call(.upcast(node), .fromComptimeLatin1("maybe_resource"), .{false});
    try testing.expectEqual(Variant.Tag.nil, nil_result.tag);
    nil_result.deinit();
    try testing.expectEqual(@as(usize, 0), destroyed_count);

    const value_result = Object.call(.upcast(node), .fromComptimeLatin1("maybe_resource"), .{true});
    const resource = value_result.as(*TrackedResource).?;
    try testing.expectEqual(@as(i32, 1), resource.base.getReferenceCount());
    value_result.deinit();
    try testing.expectEqual(@as(usize, 1), destroyed_count);

    const config = gdzig.extension.testing.MethodConfig(OwnedReturnNode).fromName(
        "maybe_resource",
        "maybeResource",
        .{ .return_ownership = .transfer },
    );
    var make_value: u8 = 0;
    const args = [_]?*const anyopaque{@ptrCast(&make_value)};
    var returned_ref: ?*anyopaque = null;
    config.ptr_call.?(node, @ptrCast(&args), @ptrCast(&returned_ref));
    try testing.expect(gdzig.raw.refGetObject(@ptrCast(&returned_ref)) == null);

    make_value = 1;
    config.ptr_call.?(node, @ptrCast(&args), @ptrCast(&returned_ref));
    const returned_object = gdzig.raw.refGetObject(@ptrCast(&returned_ref)).?;
    const returned_resource: *Resource = @ptrCast(@alignCast(returned_object));
    try testing.expectEqual(@as(i32, 1), returned_resource.getReferenceCount());
    gdzig.raw.refSetObject(@ptrCast(&returned_ref), null);
    try testing.expectEqual(@as(usize, 2), destroyed_count);
}

test "borrowed RefCounted returns continue to share ownership" {
    ensureRegistered();
    destroyed_count = 0;

    const node = try OwnedReturnNode.create();
    defer node.base.destroy();

    try testing.expectEqual(@as(i32, 1), node.borrowed.base.getReferenceCount());

    const result = Object.call(.upcast(node), .fromComptimeLatin1("borrow_resource"), .{});
    try testing.expectEqual(node.borrowed, result.as(*TrackedResource).?);
    try testing.expectEqual(@as(i32, 2), node.borrowed.base.getReferenceCount());
    result.deinit();
    try testing.expectEqual(@as(i32, 1), node.borrowed.base.getReferenceCount());
    try testing.expectEqual(@as(usize, 0), destroyed_count);

    const config = gdzig.extension.testing.MethodConfig(OwnedReturnNode).fromName(
        "borrow_resource",
        "borrowResource",
        .{},
    );
    var returned_ref: ?*anyopaque = null;
    config.ptr_call.?(node, @ptrCast(&[_]?*const anyopaque{}), @ptrCast(&returned_ref));
    try testing.expectEqual(@as(i32, 2), node.borrowed.base.getReferenceCount());
    gdzig.raw.refSetObject(@ptrCast(&returned_ref), null);
    try testing.expectEqual(@as(i32, 1), node.borrowed.base.getReferenceCount());
    try testing.expectEqual(@as(usize, 0), destroyed_count);
}

test "direct Zig calls retain ownership of fresh RefCounted returns" {
    ensureRegistered();
    destroyed_count = 0;

    const node = try OwnedReturnNode.create();
    defer node.base.destroy();

    const resource = node.makeBuiltinResource();
    try testing.expectEqual(@as(i32, 1), resource.getReferenceCount());
    try testing.expectEqual(@as(usize, 0), destroyed_count);

    try testing.expect(resource.unreference());
    resource.destroy();
}

test "repeated varcall caller scopes destroy every transferred return" {
    ensureRegistered();
    destroyed_count = 0;

    const node = try OwnedReturnNode.create();
    defer node.base.destroy();

    for (0..16) |i| {
        const result = Object.call(.upcast(node), .fromComptimeLatin1("make_resource"), .{});
        const resource = result.as(*TrackedResource).?;
        try testing.expectEqual(@as(i32, 1), resource.base.getReferenceCount());
        result.deinit();
        try testing.expectEqual(i + 1, destroyed_count);
    }
}

var destroyed_count: usize = 0;

const OwnedReturnNode = struct {
    base: *Node,
    borrowed: *TrackedResource,

    pub fn create() !*OwnedReturnNode {
        const self = try allocator.create(OwnedReturnNode);
        self.* = .{
            .base = .init(),
            .borrowed = try TrackedResource.create(),
        };
        self.base.setInstance(OwnedReturnNode, self);
        return self;
    }

    pub fn destroy(self: *OwnedReturnNode) void {
        if (!self.borrowed.base.unreference()) @panic("borrowed resource retained unexpectedly");
        self.borrowed.base.destroy();
        allocator.destroy(self);
    }

    pub fn makeResource(_: *OwnedReturnNode) *TrackedResource {
        return TrackedResource.create() catch @panic("out of memory");
    }

    pub fn makeBuiltinResource(_: *OwnedReturnNode) *Resource {
        return .init();
    }

    pub fn maybeResource(_: *OwnedReturnNode, make_value: bool) ?*TrackedResource {
        if (!make_value) return null;
        return TrackedResource.create() catch @panic("out of memory");
    }

    pub fn borrowResource(self: *OwnedReturnNode) *TrackedResource {
        return self.borrowed;
    }
};

const TrackedResource = struct {
    base: *Resource,

    pub fn create() !*TrackedResource {
        const self = try allocator.create(TrackedResource);
        self.* = .{ .base = .init() };
        self.base.setInstance(TrackedResource, self);
        return self;
    }

    pub fn destroy(self: *TrackedResource) void {
        destroyed_count += 1;
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
