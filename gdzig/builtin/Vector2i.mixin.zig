/// Constructs a default-initialized [Vector2i](https://gdzig.github.io/gdzig/#gdzig.builtin.vector2i.Vector2i) with all components set to `0`.
///
/// @comptime
pub fn init() Vector2i {
    return .zero;
}

// @mixin stop

const Vector2i = @import("./vector2i.zig").Vector2i;
