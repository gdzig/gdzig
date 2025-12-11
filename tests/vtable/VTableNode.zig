const VTableNode = @This();

pub var last_instance: ?*VTableNode = null;

base: *Node,
ready_called: bool = false,
enter_tree_called: bool = false,
exit_tree_called: bool = false,

pub fn create(allocator: *const Allocator) !*VTableNode {
    const self = try allocator.create(VTableNode);
    self.* = .{ .base = Node.init() };
    self.base.setInstance(VTableNode, self);
    return self;
}

pub fn destroy(self: *VTableNode, allocator: *const Allocator) void {
    allocator.destroy(self);
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

const std = @import("std");
const Allocator = std.mem.Allocator;

const godot = @import("gdzig");
const Node = godot.class.Node;
