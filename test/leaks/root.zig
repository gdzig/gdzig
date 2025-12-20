test "variant reference counting" {
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
const testing = std.testing;

const gdzig = @import("gdzig");
const general = gdzig.general;
const RefCounted = gdzig.class.RefCounted;
const Variant = gdzig.builtin.Variant;
