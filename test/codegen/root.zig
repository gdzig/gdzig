test "call builtin method with void return type" {
    var arr: Array = .init();
    arr.set(0, .init(bool, true));
}

test "default values for basic and flag types" {
    // Verify the opt struct with Dictionary default compiles (don't execute - needs valid surface data)
    _ = &ArrayMesh.addSurfaceFromArrays;
}

test "forType handles optional class pointer types" {
    // Optional class pointers like ?*Curve should resolve to .object,
    // same as their non-optional counterparts.
    try std.testing.expectEqual(.object, Variant.Tag.forType(?*Curve));
    try std.testing.expectEqual(.object, Variant.Tag.forType(?*Noise));
    try std.testing.expectEqual(.object, Variant.Tag.forType(?*Material));
}

const std = @import("std");
const gdzig = @import("gdzig");
const Array = gdzig.builtin.Array;
const ArrayMesh = gdzig.class.ArrayMesh;
const Curve = gdzig.class.Curve;
const Material = gdzig.class.Material;
const Noise = gdzig.class.Noise;
const Variant = gdzig.builtin.Variant;
