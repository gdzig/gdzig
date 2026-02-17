test "call builtin method with void return type" {
    var arr: Array = .init();
    arr.set(0, .init(bool, true));
}

test "default values for basic and flag types" {
    // Verify the opt struct with Dictionary default compiles (don't execute - needs valid surface data)
    _ = &ArrayMesh.addSurfaceFromArrays;
}

const gdzig = @import("gdzig");
const Array = gdzig.builtin.Array;
const ArrayMesh = gdzig.class.ArrayMesh;
