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

const std = @import("std");
const gdzig = @import("gdzig");
const Array = gdzig.builtin.Array;
const ArrayMesh = gdzig.class.ArrayMesh;
const RenderingDevice = gdzig.class.RenderingDevice;
