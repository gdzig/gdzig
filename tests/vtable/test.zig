pub fn init() void {
    godot.registerClass(VTableNode, .{});
}

pub fn deinit() !void {
    const node = VTableNode.last_instance orelse return error.NoInstance;
    try testing.expect(node.enter_tree_called);
    try testing.expect(node.ready_called);
    try testing.expect(node.exit_tree_called);
}

const godot = @import("gdzig");
const testing = @import("gdzig_test");
const VTableNode = @import("VTableNode.zig");
