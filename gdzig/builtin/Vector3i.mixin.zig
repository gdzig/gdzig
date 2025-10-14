/// Constructs a default-initialized [Vector3i](https://gdzig.github.io/gdzig/#gdzig.builtin.vector3i.Vector3i) with all components set to `0`.
///
/// @comptime
pub fn init() Vector3i {
    return .zero;
}

// @mixin stop

const Vector3i = @import("./vector3i.zig").Vector3i;
