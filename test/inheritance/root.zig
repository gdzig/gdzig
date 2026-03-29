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

const std = @import("std");
const testing = std.testing;

const gdzig = @import("gdzig");
const allocator = gdzig.testing.allocator;
const Object = gdzig.class.Object;
