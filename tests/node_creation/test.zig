pub fn run() !void {
    const node = godot.class.Node.init();
    defer node.destroy();

    var name = node.getName();
    defer name.deinit();

    try testing.expect(name.length() == 0);
}

const godot = @import("gdzig");
const testing = @import("gdzig_test");
