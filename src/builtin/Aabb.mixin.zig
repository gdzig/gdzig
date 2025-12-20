/// Constructs an [AABB](https://gdzig.github.io/gdzig/#gdzig.builtin.aabb.AABB) with its `position` and `size` set to `Vector3.ZERO`.
pub const init: Aabb = .initPositionSize(.zero, .zero);

// @mixin stop

const Self = gdzig.builtin.Aabb;

const gdzig = @import("gdzig");
const Aabb = gdzig.builtin.Aabb;
