pub fn run() !void {
    const node = godot.class.Node.init();
    defer godot.object.destroy(node);

    var name = node.getName();
    defer name.deinit();

    try testing.expect(name.length() == 0);
}

const godot = @import("gdzig");
const testing = @import("gdzig_test");
