const std = @import("std");
const testing = std.testing;
const gdzig = @import("gdzig");

test "1 + 2 = 3" {
    try testing.expectEqual(3, 1 + 2);
}

test "2 + 2 = 4" {
    try testing.expectEqual(4, 2 + 2);
}

test "3 + 3 = 6" {
    try testing.expectEqual(6, 3 + 3);
}

test "godot version is 4.x" {
    try testing.expectEqual(4, gdzig.version.major);
}
