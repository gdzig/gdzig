/// Constructs a [Rect2](https://gdzig.github.io/gdzig/#gdzig.builtin.rect2.Rect2) with its `position` and `size` set to `Vector2i.ZERO`.
pub const init: Rect2 = .initPositionSize(
    .initXY(0, 0),
    .initXY(0, 0),
);

/// Constructs a [Rect2](https://gdzig.github.io/gdzig/#gdzig.builtin.rect2.Rect2) by setting its `position` to (`x`, `y`), and its `size` to (`width`, `height`).
///
/// @comptime
pub fn initXYWidthHeight(p_x: i64, p_y: i64, p_width: i64, p_height: i64) Rect2 {
    return .initPositionSize(
        .initXY(p_x, p_y),
        .initXY(p_width, p_height),
    );
}

// @mixin stop

const Self = gdzig.builtin.Rect2;

const gdzig = @import("gdzig");
const Rect2 = gdzig.builtin.Rect2;
