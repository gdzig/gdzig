// Compile-only fixture. Its undefined values must never be executed.
test "inherited ordinary call rejects packed arrays" {
    const node: *gdzig.class.Node3d = undefined;
    const bytes: gdzig.builtin.PackedByteArray = undefined;
    _ = node.call(.fromComptimeLatin1("probe"), .{bytes});
}

const gdzig = @import("gdzig");
