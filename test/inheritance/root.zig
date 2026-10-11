/// Integration test for extending user-defined Zig classes.
///
/// Tests that ClassA extends Object, ClassB extends ClassA, and ClassC extends ClassB.
/// This validates multi-level inheritance of custom extension classes,
/// verifying through Godot's Object.call dispatch.
///
/// Derived user classes embed their parent (e.g. `base: ClassA` not `base: *ClassA`)
/// so that `*ClassB` can be safely cast to `*ClassA` — matching how Godot passes a
/// single extension instance pointer to all method callbacks.
pub fn register(r: *gdzig.extension.Registry) void {
    const class_a = r.createClass(ClassA, {}, .auto);
    class_a.addMethod("get_value_a", .auto);

    const class_b = r.createClass(ClassB, {}, .auto);
    class_b.addMethod("get_value_b", .auto);

    const class_c = r.createClass(ClassC, {}, .auto);
    class_c.addMethod("get_value_c", .auto);

    _ = r.createClass(CastNode, {}, .auto);
    _ = r.createClass(OtherCastNode, {}, .auto);
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

test "ClassA: call method through Godot dispatch" {
    ensureRegistered();

    const a = try ClassA.create();
    defer a.base.destroy();

    const result = Object.call(.upcast(a), .fromComptimeLatin1("get_value_a"), .{});
    try testing.expectEqual(@as(i64, 1), result.as(i64).?);
}

test "ClassB: call own method through Godot dispatch" {
    ensureRegistered();

    const b = try ClassB.create();
    defer Object.upcast(b).destroy();

    const result = Object.call(.upcast(b), .fromComptimeLatin1("get_value_b"), .{});
    try testing.expectEqual(@as(i64, 2), result.as(i64).?);
}

test "ClassB: call inherited ClassA method through Godot dispatch" {
    ensureRegistered();

    const b = try ClassB.create();
    defer Object.upcast(b).destroy();

    const result = Object.call(.upcast(b), .fromComptimeLatin1("get_value_a"), .{});
    try testing.expectEqual(@as(i64, 1), result.as(i64).?);
}

test "ClassC: call own method through Godot dispatch" {
    ensureRegistered();

    const c_ = try ClassC.create();
    defer Object.upcast(c_).destroy();

    const result = Object.call(.upcast(c_), .fromComptimeLatin1("get_value_c"), .{});
    try testing.expectEqual(@as(i64, 3), result.as(i64).?);
}

test "ClassC: call inherited ClassB method through Godot dispatch" {
    ensureRegistered();

    const c_ = try ClassC.create();
    defer Object.upcast(c_).destroy();

    const result = Object.call(.upcast(c_), .fromComptimeLatin1("get_value_b"), .{});
    try testing.expectEqual(@as(i64, 2), result.as(i64).?);
}

test "ClassC: call inherited ClassA method through Godot dispatch" {
    ensureRegistered();

    const c_ = try ClassC.create();
    defer Object.upcast(c_).destroy();

    const result = Object.call(.upcast(c_), .fromComptimeLatin1("get_value_a"), .{});
    try testing.expectEqual(@as(i64, 1), result.as(i64).?);
}

const ClassA = struct {
    base: *Object,
    value_a: i64 = 1,

    pub fn create() !*ClassA {
        const self: *ClassA = allocator.create(ClassA) catch @panic("out of memory");
        self.* = .{ .base = Object.init() };
        self.base.setInstance(ClassA, self);
        return self;
    }

    pub fn destroy(self: *ClassA) void {
        allocator.destroy(self);
    }

    pub fn getValueA(self: *ClassA) i64 {
        return self.value_a;
    }
};

const ClassB = struct {
    base: ClassA,
    value_b: i64 = 2,

    pub fn create() !*ClassB {
        const self: *ClassB = allocator.create(ClassB) catch @panic("out of memory");
        self.* = .{
            .base = .{ .base = Object.init() },
        };
        self.base.base.setInstance(ClassB, self);
        return self;
    }

    pub fn destroy(self: *ClassB) void {
        allocator.destroy(self);
    }

    pub fn getValueB(self: *ClassB) i64 {
        return self.value_b;
    }
};

const ClassC = struct {
    base: ClassB,
    value_c: i64 = 3,

    pub fn create() !*ClassC {
        const self: *ClassC = allocator.create(ClassC) catch @panic("out of memory");
        self.* = .{
            .base = .{ .base = .{ .base = Object.init() } },
        };
        self.base.base.base.setInstance(ClassC, self);
        return self;
    }

    pub fn destroy(self: *ClassC) void {
        allocator.destroy(self);
    }

    pub fn getValueC(self: *ClassC) i64 {
        return self.value_c;
    }
};

const CastNode = struct {
    base: *Control,
    value: i64 = 7,

    /// Allocates and binds a Control-backed test instance, or returns an allocation error.
    pub fn create() !*CastNode {
        const self: *CastNode = try allocator.create(CastNode);
        self.* = .{ .base = .init() };
        self.base.setInstance(CastNode, self);
        return self;
    }

    /// Releases the test instance when Godot destroys its engine object.
    pub fn destroy(self: *CastNode) void {
        allocator.destroy(self);
    }
};

const OtherCastNode = struct {
    base: *Control,

    /// Allocates and binds a sibling test instance, or returns an allocation error.
    pub fn create() !*OtherCastNode {
        const self: *OtherCastNode = try allocator.create(OtherCastNode);
        self.* = .{ .base = .init() };
        self.base.setInstance(OtherCastNode, self);
        return self;
    }

    /// Releases the test instance when Godot destroys its engine object.
    pub fn destroy(self: *OtherCastNode) void {
        allocator.destroy(self);
    }
};

test "downcast: engine match and mismatch" {
    const control: *Control = .init();
    defer control.destroy();
    const node: *Node = .upcast(control);
    try testing.expectEqual(@as(?*Control, control), gdzig.class.downcast(*Control, node));

    const plain: *Node = .init();
    defer plain.destroy();
    try testing.expect(gdzig.class.downcast(*Control, plain) == null);
}

test "downcast: optional engine source" {
    const control: *Control = .init();
    defer control.destroy();
    const present: ?*Node = .upcast(control);
    const absent: ?*Node = null;
    try testing.expectEqual(@as(?*Control, control), gdzig.class.downcast(*Control, present));
    try testing.expect(gdzig.class.downcast(*Control, absent) == null);
}

test "downcast: custom instance identity across engine wrappers" {
    ensureRegistered();
    const parent: *Node = .init();
    defer parent.destroy();
    const first: *CastNode = try .create();
    defer first.base.destroy();
    const second: *CastNode = try .create();
    defer second.base.destroy();
    first.base.setName(.fromComptimeLatin1("CastChild"));
    parent.addChild(Node.upcast(first), .{});
    defer parent.removeChild(Node.upcast(first));
    var child_name: gdzig.builtin.String = .fromLatin1("CastChild");
    defer child_name.deinit();
    var child_path: gdzig.builtin.NodePath = .fromString(child_name);
    defer child_path.deinit();
    const node: *Node = parent.getNode(child_path).?;
    const object: *Object = .upcast(first);

    try testing.expectEqual(@as(?*CastNode, first), first.base.asInstance(CastNode));
    try testing.expectEqual(@as(?*CastNode, first), node.asInstance(CastNode));
    try testing.expectEqual(@as(?*CastNode, first), object.asInstance(CastNode));
    try testing.expectEqual(@as(?*CastNode, first), gdzig.class.downcast(*CastNode, node));
    try testing.expectEqual(@as(?*CastNode, first), gdzig.class.downcast(*CastNode, object));
    try testing.expectEqual(node.asInstance(CastNode), gdzig.class.downcast(*CastNode, node));
    const second_node: *Node = .upcast(second);
    try testing.expectEqual(@as(?*CastNode, second), gdzig.class.downcast(*CastNode, second_node));
    gdzig.class.downcast(*CastNode, node).?.value = 42;
    try testing.expectEqual(@as(i64, 42), first.value);
    try testing.expectEqual(@as(i64, 7), second.value);
}

test "downcast: custom mismatch and plain engine objects" {
    ensureRegistered();
    const other: *OtherCastNode = try .create();
    defer other.base.destroy();
    const other_node: *Node = .upcast(other);
    try testing.expect(gdzig.class.downcast(*CastNode, other_node) == null);

    const plain_control: *Control = .init();
    defer plain_control.destroy();
    const plain_node: *Node = .upcast(plain_control);
    try testing.expect(gdzig.class.downcast(*CastNode, plain_node) == null);
    try testing.expect(plain_node.asInstance(CastNode) == null);

    const plain: *Node = .init();
    defer plain.destroy();
    try testing.expect(gdzig.class.downcast(*CastNode, plain) == null);
}

test "downcast: optional engine source for custom target" {
    ensureRegistered();
    const instance: *CastNode = try .create();
    defer instance.base.destroy();
    const present: ?*Node = .upcast(instance);
    const absent: ?*Node = null;
    try testing.expectEqual(@as(?*CastNode, instance), gdzig.class.downcast(*CastNode, present));
    try testing.expect(gdzig.class.downcast(*CastNode, absent) == null);
}

test "downcast: embedded custom source uses engine object" {
    ensureRegistered();
    const b: *ClassB = try .create();
    defer Object.upcast(b).destroy();
    const a: *ClassA = try .create();
    defer Object.upcast(a).destroy();
    const present: ?*ClassA = &b.base;
    const absent: ?*ClassA = null;
    try testing.expectEqual(@as(?*ClassB, b), gdzig.class.downcast(*ClassB, &b.base));
    try testing.expectEqual(@as(?*ClassB, b), gdzig.class.downcast(*ClassB, present));
    try testing.expect(gdzig.class.downcast(*ClassB, absent) == null);
    try testing.expect(gdzig.class.downcast(*ClassB, a) == null);
}

test "downcast: generated engine entry points" {
    const control: *Control = .init();
    defer control.destroy();
    const node: *Node = .upcast(control);
    const object: *Object = .upcast(control);
    const present: ?*Node = node;
    const absent: ?*Node = null;
    try testing.expectEqual(@as(?*Control, control), Control.downcast(node));
    try testing.expectEqual(@as(?*Control, control), Control.downcast(present));
    try testing.expect(Control.downcast(absent) == null);
    try testing.expectEqual(@as(?*Node, node), Node.downcast(object));
    try testing.expectEqual(@as(?*Object, object), Object.downcast(object));

    const plain: *Node = .init();
    defer plain.destroy();
    try testing.expect(Control.downcast(plain) == null);
}

const std = @import("std");
const testing = std.testing;

const gdzig = @import("gdzig");
const allocator = gdzig.testing.allocator;
const Object = gdzig.class.Object;
const Node = gdzig.class.Node;
const Control = gdzig.class.Control;
