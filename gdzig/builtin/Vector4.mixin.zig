/// Constructs a default-initialized [Vector4](https://gdzig.github.io/gdzig/#gdzig.builtin.vector4.Vector4) with all components set to `0`.
///
/// @comptime
pub fn init() Vector4 {
    return .zero;
}

// @mixin stop

const Vector4 = @import("./vector4.zig").Vector4;
