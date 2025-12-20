pub fn register(r: *gdzig.extension.Registry) void {
    const class = r.createClass(PropertyNode, {}, .auto);

    // Field-based property with auto-detected getter/setter
    class.addProperty("field_value", .auto);

    // Read-only property (getter only, no setter)
    class.addProperty("read_only", .{ .setter = .none });

    // Property with explicit getter/setter methods
    const get_custom = class.createMethod("get_custom", .auto);
    const set_custom = class.createMethod("set_custom", .auto);
    class.addProperty("custom", .{
        .getter = .{ .method = get_custom },
        .setter = .{ .method = set_custom },
    });

    // Property groups
    const stats = class.createGroup("Stats");
    stats.addProperty("health", .auto);
    stats.addProperty("mana", .auto);

    // Property subgroups
    const combat = stats.createSubgroup("Combat");
    combat.addProperty("armor", .auto);
    combat.addProperty("damage", .auto);

    // Indexed properties - shared getter/setter with index parameter
    const get_slot = class.createMethod("get_inventory_slot", .auto);
    const set_slot = class.createMethod("set_inventory_slot", .auto);
    class.addProperty("slot_0", .{ .getter = .{ .method = get_slot }, .setter = .{ .method = set_slot }, .index = 0 });
    class.addProperty("slot_1", .{ .getter = .{ .method = get_slot }, .setter = .{ .method = set_slot }, .index = 1 });
    class.addProperty("slot_2", .{ .getter = .{ .method = get_slot }, .setter = .{ .method = set_slot }, .index = 2 });
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

test "field-based property" {
    ensureRegistered();

    const node = try PropertyNode.create();
    defer node.destroy();

    const obj = Object.upcast(node);

    var result = obj.get(.fromComptimeLatin1("field_value"));
    try testing.expectEqual(@as(i64, 42), result.as(i64).?);

    obj.set(.fromComptimeLatin1("field_value"), .init(i64, 100));
    result = obj.get(.fromComptimeLatin1("field_value"));
    try testing.expectEqual(@as(i64, 100), result.as(i64).?);
}

test "read-only property" {
    ensureRegistered();

    const node = try PropertyNode.create();
    defer node.destroy();

    const obj = Object.upcast(node);

    const result = obj.get(.fromComptimeLatin1("read_only"));
    try testing.expectEqual(@as(i64, 999), result.as(i64).?);
}

test "explicit getter/setter property" {
    ensureRegistered();

    const node = try PropertyNode.create();
    defer node.destroy();

    const obj = Object.upcast(node);

    var result = obj.get(.fromComptimeLatin1("custom"));
    try testing.expectEqual(@as(i64, 0), result.as(i64).?);

    obj.set(.fromComptimeLatin1("custom"), .init(i64, 555));
    result = obj.get(.fromComptimeLatin1("custom"));
    try testing.expectEqual(@as(i64, 555), result.as(i64).?);
}

test "grouped properties" {
    ensureRegistered();

    const node = try PropertyNode.create();
    defer node.destroy();

    const obj = Object.upcast(node);

    var result = obj.get(.fromComptimeLatin1("health"));
    try testing.expectEqual(@as(i64, 100), result.as(i64).?);

    result = obj.get(.fromComptimeLatin1("mana"));
    try testing.expectEqual(@as(i64, 50), result.as(i64).?);
}

test "subgrouped properties" {
    ensureRegistered();

    const node = try PropertyNode.create();
    defer node.destroy();

    const obj = Object.upcast(node);

    var result = obj.get(.fromComptimeLatin1("armor"));
    try testing.expectEqual(@as(i64, 10), result.as(i64).?);

    result = obj.get(.fromComptimeLatin1("damage"));
    try testing.expectEqual(@as(i64, 25), result.as(i64).?);
}

test "indexed properties" {
    ensureRegistered();

    // Indexed properties require Godot 4.2+
    if (!gdzig.version.gte(.@"4.2")) return error.SkipZigTest;

    const node = try PropertyNode.create();
    defer node.destroy();

    const obj = Object.upcast(node);

    // Check initial values
    var result = obj.get(.fromComptimeLatin1("slot_0"));
    try testing.expectEqual(@as(i64, 100), result.as(i64).?);

    result = obj.get(.fromComptimeLatin1("slot_1"));
    try testing.expectEqual(@as(i64, 200), result.as(i64).?);

    result = obj.get(.fromComptimeLatin1("slot_2"));
    try testing.expectEqual(@as(i64, 300), result.as(i64).?);

    // Modify via indexed property
    obj.set(.fromComptimeLatin1("slot_1"), .init(i64, 999));
    result = obj.get(.fromComptimeLatin1("slot_1"));
    try testing.expectEqual(@as(i64, 999), result.as(i64).?);

    // Verify other slots unchanged
    result = obj.get(.fromComptimeLatin1("slot_0"));
    try testing.expectEqual(@as(i64, 100), result.as(i64).?);

    result = obj.get(.fromComptimeLatin1("slot_2"));
    try testing.expectEqual(@as(i64, 300), result.as(i64).?);
}

const PropertyNode = struct {
    base: *Object,

    // Field-based property
    field_value: i64 = 42,

    // Read-only property
    read_only: i64 = 999,

    // Custom getter/setter backing storage
    custom_backing: i64 = 0,

    // Grouped properties
    health: i64 = 100,
    mana: i64 = 50,

    // Subgrouped properties
    armor: i64 = 10,
    damage: i64 = 25,

    // Indexed property backing storage
    inventory: [3]i64 = .{ 100, 200, 300 },

    pub fn create() !*PropertyNode {
        const self = try allocator.create(PropertyNode);
        self.* = .{ .base = Object.init() };
        self.base.setInstance(PropertyNode, self);
        return self;
    }

    pub fn destroy(self: *PropertyNode) void {
        self.base.destroy();
        allocator.destroy(self);
    }

    // Custom property getter/setter
    pub fn getCustom(self: *const PropertyNode) i64 {
        return self.custom_backing;
    }

    pub fn setCustom(self: *PropertyNode, value: i64) void {
        self.custom_backing = value;
    }

    // Indexed property getter/setter
    pub fn getInventorySlot(self: *const PropertyNode, index: i64) i64 {
        if (index >= 0 and index < 3) {
            return self.inventory[@intCast(index)];
        }
        return 0;
    }

    pub fn setInventorySlot(self: *PropertyNode, index: i64, value: i64) void {
        if (index >= 0 and index < 3) {
            self.inventory[@intCast(index)] = value;
        }
    }
};

const std = @import("std");
const testing = std.testing;

const gdzig = @import("gdzig");
const allocator = gdzig.testing.allocator;
const Object = gdzig.class.Object;
