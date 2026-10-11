// Compile-only controls. Their undefined values must never be executed.
test "inherited Alloc accepts packed arrays" {
    const node: *gdzig.class.Node3d = undefined;
    const bytes: gdzig.builtin.PackedByteArray = undefined;
    _ = node.callAlloc(.fromComptimeLatin1("probe"), .{bytes});
}

test "inherited ordinary call accepts prewrapped Variant" {
    const node: *gdzig.class.Node3d = undefined;
    var value: gdzig.builtin.Variant = undefined;
    std.mem.doNotOptimizeAway(&value);
    _ = node.call(.fromComptimeLatin1("probe"), .{value});
}

const std = @import("std");

const gdzig = @import("gdzig");
