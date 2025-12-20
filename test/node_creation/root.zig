test "create node and get name" {
    const node = gdzig.class.Node.init();
    defer node.destroy();

    var name = node.getName();
    defer name.deinit();

    try testing.expect(name.length() == 0);
}

const std = @import("std");
const testing = std.testing;

const gdzig = @import("gdzig");
