/// The identity [Transform2D](https://gdzig.github.io/gdzig/#gdzig.builtin.transform2_d.Transform2D). This is a transform with no translation, no rotation, and a scale of `Vector2.ONE`. This also means that:
///
/// - The `x` points right (`Vector2.RIGHT`);
///
/// - The `y` points down (`Vector2.DOWN`).
///
/// ```
/// var transform = Transform2D.IDENTITY
/// print("| X | Y | Origin")
/// print("| %.f | %.f | %.f" % [transform.x.x, transform.y.x, transform.origin.x])
/// print("| %.f | %.f | %.f" % [transform.x.y, transform.y.y, transform.origin.y])
/// # Prints:
/// # | X | Y | Origin
/// # | 1 | 0 | 0
/// # | 0 | 1 | 0
/// ```
///
/// If a [Vector2](https://gdzig.github.io/gdzig/#gdzig.builtin.vector2.Vector2), a [Rect2](https://gdzig.github.io/gdzig/#gdzig.builtin.rect2.Rect2), a [PackedVector2Array](https://gdzig.github.io/gdzig/#gdzig.builtin.packed_vector2_array.PackedVector2Array), or another [Transform2D](https://gdzig.github.io/gdzig/#gdzig.builtin.transform2_d.Transform2D) is transformed (multiplied) by this constant, no transformation occurs.
///
/// **Note:** In GDScript, this constant is equivalent to creating a [constructor Transform2D] without any arguments. It can be used to make your code clearer, and for consistency with C#.
pub const identity: Transform2d = .initXAxisYAxisOrigin(
    .initXY(1, 0),
    .initXY(0, 1),
    .initXY(0, 0),
);

/// When any transform is multiplied by `FLIP_X`, it negates all components of the `x` axis (the X column).
///
/// When `FLIP_X` is multiplied by any transform, it negates the `Vector2.x` component of all axes (the X row).
pub const flip_x: Transform2d = .initXAxisYAxisOrigin(
    .initXY(-1, 0),
    .initXY(0, 1),
    .initXY(0, 0),
);

/// When any transform is multiplied by `FLIP_Y`, it negates all components of the `y` axis (the Y column).
///
/// When `FLIP_Y` is multiplied by any transform, it negates the `Vector2.y` component of all axes (the Y row).
pub const flip_y: Transform2d = .initXAxisYAxisOrigin(
    .initXY(1, 0),
    .initXY(0, -1),
    .initXY(0, 0),
);

/// @comptime
pub fn initXAxisYAxisOriginComponents(xx: f32, xy: f32, yx: f32, yy: f32, ox: f32, oy: f32) Transform2d {
    return .initXAxisYAxisOrigin(
        .initXY(xx, xy),
        .initXY(yx, yy),
        .initXY(ox, oy),
    );
}

/// Constructs a [Transform2D](https://gdzig.github.io/gdzig/#gdzig.builtin.transform2_d.Transform2D) identical to `IDENTITY`.
///
/// **Note:** In C#, this constructs a [Transform2D](https://gdzig.github.io/gdzig/#gdzig.builtin.transform2_d.Transform2D) with all of its components set to `Vector2.ZERO`.
pub const init: Transform2d = .identity;

// @mixin stop

const Self = gdzig.builtin.Transform2d;

const gdzig = @import("gdzig");
const Transform2d = gdzig.builtin.Transform2d;
