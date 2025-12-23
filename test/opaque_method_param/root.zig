/// Test: Methods with opaque class pointer parameters should compile and work
///
/// BUG: Currently fails with isStructClass assertion because Variant.as()
/// doesn't properly handle opaque class pointers (like *Node) as method parameters.
///
/// Expected: This should compile and allow calling methods with Node parameters
/// Actual: Compilation fails at isStructClass(T) assertion in asInstance()
///
/// Related: https://github.com/gdzig/gdzig/issues/XXX (fill in when issue created)
pub fn register(r: *gdzig.extension.Registry) void {
    const class = r.createClass(TestNode, {}, .auto);
    // BUG: This line causes compilation failure with isStructClass assertion
    // because *Node is an opaque class pointer, not a struct class pointer.
    // Variant.as(*Node) incorrectly enters the else branch in variant.zig:151-157
    class.addMethod("process_node", .auto);
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

test "method with opaque class pointer parameter can be registered and called" {
    ensureRegistered();

    const node = try TestNode.create();
    defer node.base.destroy();

    // Create another node to pass as parameter
    const other_node = Node.init();
    defer other_node.destroy();

    // This should work: call processNode with a Node parameter
    _ = Object.call(.upcast(node), .fromComptimeLatin1("process_node"), .{other_node});
}

const TestNode = struct {
    base: *Node,

    pub fn create() !*TestNode {
        const self: *TestNode = allocator.create(TestNode) catch @panic("out of memory");
        self.* = .{ .base = Node.init() };
        self.base.setInstance(TestNode, self);
        return self;
    }

    pub fn destroy(self: *TestNode) void {
        allocator.destroy(self);
    }

    /// This method takes an opaque class pointer (Node) as a parameter.
    /// It should be valid to register this as a method and call it with
    /// a Node instance passed from Godot.
    pub fn processNode(self: *TestNode, node: *Node) void {
        _ = self;
        _ = node;
    }
};

const gdzig = @import("gdzig");
const allocator = gdzig.testing.allocator;
const Node = gdzig.class.Node;
const Object = gdzig.class.Object;
