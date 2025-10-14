/// Constructs a default-initialized [Vector2](https://gdzig.github.io/gdzig/#gdzig.builtin.vector2.Vector2) with all components set to `0`.
///
/// @comptime
pub fn init() Vector2 {
    return .zero;
}

// @mixin stop

const Vector2 = @import("./vector2.zig").Vector2;
