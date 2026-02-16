test "call builtin method with void return type" {
    var arr: Array = .init();
    arr.set(0, .init(bool, true));
}

const gdzig = @import("gdzig");
const Array = gdzig.builtin.Array;
