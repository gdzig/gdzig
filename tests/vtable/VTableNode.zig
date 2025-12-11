const VTableNode = @This();

pub var last_instance: ?*VTableNode = null;

base: *Node,
ready_called: bool = false,
enter_tree_called: bool = false,
exit_tree_called: bool = false,

pub fn init(base: *Node) VTableNode {
    return VTableNode{ .base = base };
}

pub fn _ready(self: *VTableNode) void {
    last_instance = self;
    self.ready_called = true;
}

pub fn _enterTree(self: *VTableNode) void {
    self.enter_tree_called = true;
}

pub fn _exitTree(self: *VTableNode) void {
    self.exit_tree_called = true;
}

const godot = @import("gdzig");
const Node = godot.class.Node;
