/// Constructs a default [Color](https://gdzig.github.io/gdzig/#gdzig.builtin.color.Color) from opaque black. This is the same as `BLACK`.
///
/// **Note:** In C#, this constructs a [Color](https://gdzig.github.io/gdzig/#gdzig.builtin.color.Color) with all of its components set to `0.0` (transparent black).
///
/// @comptime
pub fn init() Color {
    return .black;
}

// @mixin stop

const Color = @import("./color.zig").Color;
