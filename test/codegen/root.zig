test "call builtin method with void return type" {
    var arr: Array = .init();
    arr.set(0, .init(bool, true));
}

test "default values for basic and flag types" {
    // Verify the opt struct with Dictionary default compiles (don't execute - needs valid surface data)
    _ = &ArrayMesh.addSurfaceFromArrays;
}

test "flag bits are laid out by value, not declaration order" {
    // RenderingDevice.TextureUsageBits lists TEXTURE_USAGE_DEPTH_RESOLVE_ATTACHMENT_BIT
    // (bit 12) before TEXTURE_USAGE_STORAGE_BIT (bit 3) in extension_api.json. Each
    // field must still land at its own bit position regardless of that ordering.
    try std.testing.expectEqual(
        @as(u32, 1),
        @as(u32, @bitCast(RenderingDevice.TextureUsageBits{ .texture_usage_sampling_bit = true })),
    );
    try std.testing.expectEqual(
        @as(u32, 8),
        @as(u32, @bitCast(RenderingDevice.TextureUsageBits{ .texture_usage_storage_bit = true })),
    );
    try std.testing.expectEqual(
        @as(u32, 128),
        @as(u32, @bitCast(RenderingDevice.TextureUsageBits{ .texture_usage_can_copy_from_bit = true })),
    );
}

test "enums with duplicate values alias the first declared member" {
    // RenderingDevice.ShaderStage aliases bit-shifted values onto the plain stage
    // enumerators (e.g. SHADER_STAGE_VERTEX_BIT == SHADER_STAGE_FRAGMENT == 1); only
    // the first-declared name for each value may become an enum tag, later members
    // with the same value must be alias constants equal to it.
    try std.testing.expectEqual(@as(i32, 4), @intFromEnum(RenderingDevice.ShaderStage.shader_stage_compute));
    try std.testing.expectEqual(RenderingDevice.ShaderStage.shader_stage_fragment, RenderingDevice.ShaderStage.shader_stage_vertex_bit);
    try std.testing.expectEqual(RenderingDevice.ShaderStage.shader_stage_tesselation_control, RenderingDevice.ShaderStage.shader_stage_fragment_bit);

    // RenderingDevice.DriverResource has DRIVER_RESOURCE_VULKAN_PHYSICAL_DEVICE aliasing
    // the earlier-declared DRIVER_RESOURCE_PHYSICAL_DEVICE (both == 1).
    try std.testing.expectEqual(RenderingDevice.DriverResource.driver_resource_physical_device, RenderingDevice.DriverResource.driver_resource_vulkan_physical_device);
}

// Bug A: omitting an optional argument whose default is a nullable heap builtin
// (String/StringName/Array/Dictionary/...) must materialize a real empty value.
// Pre-fix the generated code passed `&opt.name` where the `?T` field was null, so
// Godot dereferenced a null Array/Dictionary internal pointer -> segfault.
test "Bug A: omitting nullable Array optional arg does not segfault" {
    const node = Node.init();
    defer node.destroy();

    // addUserSignal(signal, opt: { arguments: ?Array = null }); omit arguments.
    var name: String = .fromLatin1("my_signal");
    defer name.deinit();
    node.addUserSignal(name, .{});

    var sig: StringName = .fromLatin1("my_signal", false);
    defer sig.deinit();
    try testing.expect(node.hasUserSignal(sig));
}

test "Bug A: omitting nullable String optional arg materializes empty default" {
    var s: String = .fromLatin1("a,b,c");
    defer s.deinit();

    var parts = s.split(.{});
    defer parts.deinit();

    try testing.expect(parts.size() >= 1);
}

const std = @import("std");
const testing = std.testing;

const gdzig = @import("gdzig");
const Array = gdzig.builtin.Array;
const String = gdzig.builtin.String;
const StringName = gdzig.builtin.StringName;
const ArrayMesh = gdzig.class.ArrayMesh;
const RenderingDevice = gdzig.class.RenderingDevice;
const Node = gdzig.class.Node;
