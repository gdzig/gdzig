/// A [Projection](https://gdzig.github.io/gdzig/#gdzig.builtin.projection.Projection) with no transformation defined. When applied to other data structures, no transformation is performed.
pub const identity: Projection = .initXAxisYAxisZAxisWAxis(
    .initXYZW(1, 0, 0, 0),
    .initXYZW(0, 1, 0, 0),
    .initXYZW(0, 0, 1, 0),
    .initXYZW(0, 0, 0, 1),
);
/// A [Projection](https://gdzig.github.io/gdzig/#gdzig.builtin.projection.Projection) with all values initialized to 0. When applied to other data structures, they will be zeroed.
pub const zero: Projection = .initXAxisYAxisZAxisWAxis(
    .initXYZW(0, 0, 0, 0),
    .initXYZW(0, 0, 0, 0),
    .initXYZW(0, 0, 0, 0),
    .initXYZW(0, 0, 0, 0),
);

/// Constructs a default-initialized [Projection](https://gdzig.github.io/gdzig/#gdzig.builtin.projection.Projection) identical to `IDENTITY`.
///
/// **Note:** In C#, this constructs a [Projection](https://gdzig.github.io/gdzig/#gdzig.builtin.projection.Projection) identical to `ZERO`.
pub const init: Projection = .identity;

// @mixin stop

const Self = gdzig.builtin.Projection;

const gdzig = @import("gdzig");
const Projection = gdzig.builtin.Projection;
