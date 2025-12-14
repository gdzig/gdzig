/// Constructs a [Quaternion](https://gdzig.github.io/gdzig/#gdzig.builtin.quaternion.Quaternion) identical to `IDENTITY`.
///
/// **Note:** In C#, this constructs a [Quaternion](https://gdzig.github.io/gdzig/#gdzig.builtin.quaternion.Quaternion) with all of its components set to `0.0`.
pub const init: Quaternion = .identity;

// @mixin stop

const Self = gdzig.builtin.Quaternion;

const gdzig = @import("gdzig");
const Quaternion = gdzig.builtin.Quaternion;
