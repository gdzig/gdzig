/// Constructs a default [Color](https://gdzig.github.io/gdzig/#gdzig.builtin.color.Color) from opaque black. This is the same as `BLACK`.
///
/// **Note:** In C#, this constructs a [Color](https://gdzig.github.io/gdzig/#gdzig.builtin.color.Color) with all of its components set to `0.0` (transparent black).
pub const init: Color = .black;

// @mixin stop

const Self = gdzig.builtin.Color;

const gdzig = @import("gdzig");
const Color = gdzig.builtin.Color;
