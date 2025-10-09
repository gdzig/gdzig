/// The identity [Transform3D](https://gdzig.github.io/gdzig/#gdzig.builtin.transform3_d.Transform3D). This is a transform with no translation, no rotation, and a scale of `Vector3.ONE`. Its `basis` is equal to `Basis.IDENTITY`. This also means that:
///
/// - Its `Basis.x` points right (`Vector3.RIGHT`);
///
/// - Its `Basis.y` points up (`Vector3.UP`);
///
/// - Its `Basis.z` points back (`Vector3.BACK`).
///
/// ```
/// var transform = Transform3D.IDENTITY
/// var basis = transform.basis
/// print("| X | Y | Z | Origin")
/// print("| %.f | %.f | %.f | %.f" % [basis.x.x, basis.y.x, basis.z.x, transform.origin.x])
/// print("| %.f | %.f | %.f | %.f" % [basis.x.y, basis.y.y, basis.z.y, transform.origin.y])
/// print("| %.f | %.f | %.f | %.f" % [basis.x.z, basis.y.z, basis.z.z, transform.origin.z])
/// # Prints:
/// # | X | Y | Z | Origin
/// # | 1 | 0 | 0 | 0
/// # | 0 | 1 | 0 | 0
/// # | 0 | 0 | 1 | 0
/// ```
///
/// If a [Vector3](https://gdzig.github.io/gdzig/#gdzig.builtin.vector3.Vector3), an [AABB](https://gdzig.github.io/gdzig/#gdzig.builtin.aabb.AABB), a [Plane](https://gdzig.github.io/gdzig/#gdzig.builtin.plane.Plane), a [PackedVector3Array](https://gdzig.github.io/gdzig/#gdzig.builtin.packed_vector3_array.PackedVector3Array), or another [Transform3D](https://gdzig.github.io/gdzig/#gdzig.builtin.transform3_d.Transform3D) is transformed (multiplied) by this constant, no transformation occurs.
///
/// **Note:** In GDScript, this constant is equivalent to creating a [constructor Transform3D] without any arguments. It can be used to make your code clearer, and for consistency with C#.
pub const identity: Transform3D = .initXAxisYAxisZAxisOrigin(.initXYZ(1, 0, 0), .initXYZ(0, 1, 0), .initXYZ(0, 0, 1), .initXYZ(0, 0, 0));
/// [Transform3D](https://gdzig.github.io/gdzig/#gdzig.builtin.transform3_d.Transform3D) with mirroring applied perpendicular to the YZ plane. Its `basis` is equal to `Basis.FLIP_X`.
pub const flip_x: Transform3D = .initXAxisYAxisZAxisOrigin(.initXYZ(-1, 0, 0), .initXYZ(0, 1, 0), .initXYZ(0, 0, 1), .initXYZ(0, 0, 0));
/// [Transform3D](https://gdzig.github.io/gdzig/#gdzig.builtin.transform3_d.Transform3D) with mirroring applied perpendicular to the XZ plane. Its `basis` is equal to `Basis.FLIP_Y`.
pub const flip_y: Transform3D = .initXAxisYAxisZAxisOrigin(.initXYZ(1, 0, 0), .initXYZ(0, -1, 0), .initXYZ(0, 0, 1), .initXYZ(0, 0, 0));
/// [Transform3D](https://gdzig.github.io/gdzig/#gdzig.builtin.transform3_d.Transform3D) with mirroring applied perpendicular to the XY plane. Its `basis` is equal to `Basis.FLIP_Z`.
pub const flip_z: Transform3D = .initXAxisYAxisZAxisOrigin(.initXYZ(1, 0, 0), .initXYZ(0, 1, 0), .initXYZ(0, 0, -1), .initXYZ(0, 0, 0));

// @mixin stop

const Transform3D = @import("./transform3_d.zig").Transform3D;
