pub fn run() !void {
    const object = RefCounted.init();
    try testing.expectEqual(@as(i32, 1), object.getReferenceCount());
    const variant = Variant.init(*RefCounted, object);
    try testing.expectEqual(@as(i32, 2), object.getReferenceCount());

    for (0..10) |_| {
        general.print(variant, .{ object, variant });
    }

    try testing.expectEqual(@as(i32, 2), object.getReferenceCount());
    variant.deinit();
    try testing.expectEqual(@as(i32, 1), object.getReferenceCount());
    try testing.expect(object.unreference());
    object.destroy();
}

const std = @import("std");
const assert = std.debug.assert;

const godot = @import("gdzig");
const general = godot.general;
const RefCounted = godot.class.RefCounted;
const StringName = godot.builtin.StringName;
const Variant = godot.builtin.Variant;
const testing = @import("gdzig_test");
