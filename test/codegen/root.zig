test "call builtin method with void return type" {
    var arr: Array = .init();
    // Resize array to have at least one element before setting
    _ = arr.resize(1);
    arr.set(0, .init(bool, true));
}

test "default values for basic and flag types" {
    // Verify the opt struct with Dictionary default compiles (don't execute - needs valid surface data)
    _ = &ArrayMesh.addSurfaceFromArrays;
}

const gdzig = @import("gdzig");
const Array = gdzig.builtin.Array;
const ArrayMesh = gdzig.class.ArrayMesh;
