/// The identity [Basis](https://gdzig.github.io/gdzig/#gdzig.builtin.basis.Basis). This is an orthonormal basis with no rotation, no shear, and a scale of `Vector3.ONE`. This also means that:
///
/// - The `x` points right (`Vector3.RIGHT`);
///
/// - The `y` points up (`Vector3.UP`);
///
/// - The `z` points back (`Vector3.BACK`).
///
/// ```
/// var basis = Basis.IDENTITY
/// print("| X | Y | Z")
/// print("| %.f | %.f | %.f" % [basis.x.x, basis.y.x, basis.z.x])
/// print("| %.f | %.f | %.f" % [basis.x.y, basis.y.y, basis.z.y])
/// print("| %.f | %.f | %.f" % [basis.x.z, basis.y.z, basis.z.z])
/// # Prints:
/// # | X | Y | Z
/// # | 1 | 0 | 0
/// # | 0 | 1 | 0
/// # | 0 | 0 | 1
/// ```
///
/// If a [Vector3](https://gdzig.github.io/gdzig/#gdzig.builtin.vector3.Vector3) or another [Basis](https://gdzig.github.io/gdzig/#gdzig.builtin.basis.Basis) is transformed (multiplied) by this constant, no transformation occurs.
///
/// **Note:** In GDScript, this constant is equivalent to creating a [constructor Basis] without any arguments. It can be used to make your code clearer, and for consistency with C#.
pub const identity: Basis = .initXAxisYAxisZAxis(
    .initXYZ(1, 0, 0),
    .initXYZ(0, 1, 0),
    .initXYZ(0, 0, 1),
);

/// When any basis is multiplied by `FLIP_X`, it negates all components of the `x` axis (the X column).
///
/// When `FLIP_X` is multiplied by any basis, it negates the `Vector3.x` component of all axes (the X row).
pub const flip_x: Basis = .initXAxisYAxisZAxis(
    .initXYZ(-1, 0, 0),
    .initXYZ(0, 1, 0),
    .initXYZ(0, 0, 1),
);

/// When any basis is multiplied by `FLIP_Y`, it negates all components of the `y` axis (the Y column).
///
/// When `FLIP_Y` is multiplied by any basis, it negates the `Vector3.y` component of all axes (the Y row).
pub const flip_y: Basis = .initXAxisYAxisZAxis(
    .initXYZ(1, 0, 0),
    .initXYZ(0, -1, 0),
    .initXYZ(0, 0, 1),
);

/// When any basis is multiplied by `FLIP_Z`, it negates all components of the `z` axis (the Z column).
///
/// When `FLIP_Z` is multiplied by any basis, it negates the `Vector3.z` component of all axes (the Z row).
pub const flip_z: Basis = .initXAxisYAxisZAxis(
    .initXYZ(1, 0, 0),
    .initXYZ(0, 1, 0),
    .initXYZ(0, 0, -1),
);

/// Constructs a [Basis](https://gdzig.github.io/gdzig/#gdzig.builtin.basis.Basis) identical to `IDENTITY`.
///
/// **Note:** In C#, this constructs a [Basis](https://gdzig.github.io/gdzig/#gdzig.builtin.basis.Basis) with all of its components set to `Vector3.ZERO`.
pub const init: Basis = .identity;

// @mixin stop

const Self = gdzig.builtin.Basis;

const gdzig = @import("gdzig");
const Basis = gdzig.builtin.Basis;
