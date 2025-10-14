/// Constructs a default-initialized [Vector4i](https://gdzig.github.io/gdzig/#gdzig.builtin.vector4i.Vector4i) with all components set to `0`.
///
/// @comptime
pub fn init() Vector4i {
    return .zero;
}

// @mixin stop

const Vector4i = @import("./vector4i.zig").Vector4i;
