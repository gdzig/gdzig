test "Object.isClass uses the selected API signature and method hash" {
    // The expected signature comes from the requested binding target, not from
    // the generated API or running engine. A wrong JSON selection fails at compile time.
    const ClassName = switch (gdzig.godot_version) {
        .@"4.6" => String, // Method hash 3927539163.
        .@"4.7" => StringName, // Method hash 2619796661.
    };
    comptime {
        const Expected = fn (*const Object, ClassName) bool;
        if (@TypeOf(Object.isClass) != Expected)
            @compileError("Object.isClass signature does not match the selected Godot binding target");
    }

    const node = Node.init();
    defer node.destroy();
    const object: *Object = .upcast(node);

    if (ClassName == String) {
        var node_name: String = .fromLatin1("Node");
        defer node_name.deinit();
        var object_name: String = .fromLatin1("Object");
        defer object_name.deinit();
        var resource_name: String = .fromLatin1("Resource");
        defer resource_name.deinit();

        try testing.expect(object.isClass(node_name));
        try testing.expect(object.isClass(object_name));
        try testing.expect(!object.isClass(resource_name));
    } else {
        try testing.expect(object.isClass(.fromComptimeLatin1("Node")));
        try testing.expect(object.isClass(.fromComptimeLatin1("Object")));
        try testing.expect(!object.isClass(.fromComptimeLatin1("Resource")));
    }
}

const std = @import("std");
const testing = std.testing;

const gdzig = @import("gdzig");
const Node = gdzig.class.Node;
const Object = gdzig.class.Object;
const String = gdzig.builtin.String;
const StringName = gdzig.builtin.StringName;
