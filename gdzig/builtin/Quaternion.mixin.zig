/// Constructs a [Quaternion](https://gdzig.github.io/gdzig/#gdzig.builtin.quaternion.Quaternion) identical to `IDENTITY`.
///
/// **Note:** In C#, this constructs a [Quaternion](https://gdzig.github.io/gdzig/#gdzig.builtin.quaternion.Quaternion) with all of its components set to `0.0`.
///
/// @comptime
pub fn init() Quaternion {
    return .identity;
}

// @mixin stop

const Quaternion = @import("./quaternion.zig").Quaternion;
