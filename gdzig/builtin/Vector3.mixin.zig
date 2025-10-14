/// Constructs a default-initialized [Vector3](https://gdzig.github.io/gdzig/#gdzig.builtin.vector3.Vector3) with all components set to `0`.
///
/// @comptime
pub fn init() Vector3 {
    return .zero;
}

// @mixin stop

const Vector3 = @import("./vector3.zig").Vector3;
