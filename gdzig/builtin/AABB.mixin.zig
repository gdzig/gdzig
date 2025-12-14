/// Constructs an [AABB](https://gdzig.github.io/gdzig/#gdzig.builtin.aabb.AABB) with its `position` and `size` set to `Vector3.ZERO`.
pub const init: AABB = .initPositionSize(.zero, .zero);

// @mixin stop

const Self = gdzig.builtin.AABB;

const gdzig = @import("gdzig");
const AABB = gdzig.builtin.AABB;
