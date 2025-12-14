/// Constructs a [Rect2i](https://gdzig.github.io/gdzig/#gdzig.builtin.rect2i.Rect2i) with its `position` and `size` set to `Vector2i.ZERO`.
pub const init: Rect2i = .initPositionSize(
    .initXY(0, 0),
    .initXY(0, 0),
);

/// Constructs a [Rect2i](https://gdzig.github.io/gdzig/#gdzig.builtin.rect2i.Rect2i) by setting its `position` to (`x`, `y`), and its `size` to (`width`, `height`).
///
/// @comptime
pub fn initXYWidthHeight(p_x: i64, p_y: i64, p_width: i64, p_height: i64) Rect2i {
    return .initPositionSize(
        .initXY(p_x, p_y),
        .initXY(p_width, p_height),
    );
}

// @mixin stop

const Self = gdzig.builtin.Rect2i;

const gdzig = @import("gdzig");
const Rect2i = gdzig.builtin.Rect2i;
