//! Integration test for custom ClassDB names via `Class.CreateOptions.name`.
//!
//! A custom name must be used for the class and for every API that resolves
//! the owning class by name: methods, properties, signals, constants, base
//! classes, instance binding, downcasting, and unregistration.

var registry: ?*gdzig.extension.Registry = null;

pub fn register(r: *gdzig.extension.Registry) void {
    registry = r;

    const widget = r.createClass(Widget, {}, .{ .name = "CustomWidget" });
    widget.addMethod("get_value", .auto);
    widget.addMethod("set_value", .auto);
    widget.addProperty("value", .auto);
    widget.addSignal(ValueChanged);
    widget.addEnum(State);

    const derived = r.createClass(Derived, {}, .{ .name = "CustomDerived" });
    derived.addMethod("get_extra", .auto);

    _ = r.createClass(Removable, {}, .{ .name = "CustomRemovable" });
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

const State = enum(i32) {
    idle = 0,
    busy = 1,
};

const ValueChanged = struct {
    value: i64,
};

const Widget = struct {
    base: *Node,
    value: i64 = 7,

    pub fn create() !*Widget {
        const self = try allocator.create(Widget);
        self.* = .{ .base = Node.init() };
        self.base.setInstance(Widget, self);
        return self;
    }

    pub fn destroy(self: *Widget) void {
        allocator.destroy(self);
    }

    pub fn getValue(self: *const Widget) i64 {
        return self.value;
    }

    pub fn setValue(self: *Widget, value: i64) void {
        self.value = value;
    }
};

const Derived = struct {
    base: Widget,
    extra: i64 = 3,

    pub fn create() !*Derived {
        const self = try allocator.create(Derived);
        self.* = .{ .base = .{ .base = Node.init() } };
        self.base.base.setInstance(Derived, self);
        return self;
    }

    pub fn destroy(self: *Derived) void {
        allocator.destroy(self);
    }

    pub fn getExtra(self: *const Derived) i64 {
        return self.extra;
    }
};

const Removable = struct {
    base: *Node,

    pub fn create() !*Removable {
        const self = try allocator.create(Removable);
        self.* = .{ .base = Node.init() };
        self.base.setInstance(Removable, self);
        return self;
    }

    pub fn destroy(self: *Removable) void {
        allocator.destroy(self);
    }
};

test "custom class name is registered" {
    ensureRegistered();

    try testing.expect(ClassDb.classExists(.fromComptimeLatin1("CustomWidget")));
    try testing.expect(ClassDb.classExists(.fromComptimeLatin1("CustomDerived")));

    // The Zig type name must not leak into ClassDB.
    try testing.expect(!ClassDb.classExists(.fromComptimeLatin1("Widget")));
    try testing.expect(!ClassDb.classExists(.fromComptimeLatin1("Derived")));
}

test "methods are registered on the custom class name" {
    ensureRegistered();

    try testing.expect(ClassDb.classHasMethod(
        .fromComptimeLatin1("CustomWidget"),
        .fromComptimeLatin1("get_value"),
        .{},
    ));

    const widget = try Widget.create();
    defer widget.base.destroy();

    const result = Object.call(.upcast(widget), .fromComptimeLatin1("get_value"), .{});
    try testing.expectEqual(@as(i64, 7), result.as(i64).?);
}

test "properties are registered on the custom class name" {
    ensureRegistered();

    const widget = try Widget.create();
    defer widget.base.destroy();

    const value = widget.base.get(.fromComptimeLatin1("value"));
    try testing.expectEqual(@as(i64, 7), value.as(i64).?);
}

test "signals are registered on the custom class name" {
    ensureRegistered();

    const widget = try Widget.create();
    defer widget.base.destroy();

    try testing.expect(widget.base.hasSignal(.fromComptimeLatin1("value_changed")));
}

test "constants are registered on the custom class name" {
    ensureRegistered();

    // `busy` is 1, so a failed lookup cannot be confused with a zero constant.
    try testing.expectEqual(
        @as(i64, 1),
        ClassDb.classGetIntegerConstant(
            .fromComptimeLatin1("CustomWidget"),
            .fromComptimeLatin1("busy"),
        ),
    );
}

test "derived custom class resolves its custom base name" {
    ensureRegistered();

    const derived = try Derived.create();
    defer Object.upcast(derived).destroy();

    const result = Object.call(.upcast(derived), .fromComptimeLatin1("get_extra"), .{});
    try testing.expectEqual(@as(i64, 3), result.as(i64).?);

    const inherited = Object.call(.upcast(derived), .fromComptimeLatin1("get_value"), .{});
    try testing.expectEqual(@as(i64, 7), inherited.as(i64).?);
}

test "downcast resolves the custom class name" {
    ensureRegistered();

    const widget = try Widget.create();
    defer widget.base.destroy();

    const node: *Node = .upcast(widget);
    try testing.expectEqual(@as(?*Widget, widget), gdzig.class.downcast(*Widget, node));
}

test "removeClass unregisters the custom class name" {
    ensureRegistered();

    const r = registry orelse return error.MissingRegistry;
    try testing.expect(ClassDb.classExists(.fromComptimeLatin1("CustomRemovable")));
    r.removeClass(Removable);
    try testing.expect(!ClassDb.classExists(.fromComptimeLatin1("CustomRemovable")));
}

const std = @import("std");
const testing = std.testing;

const gdzig = @import("gdzig");
const allocator = gdzig.testing.allocator;
const ClassDb = gdzig.class.ClassDb;
const Node = gdzig.class.Node;
const Object = gdzig.class.Object;
