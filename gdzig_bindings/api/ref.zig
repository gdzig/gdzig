const raw: *Interface = &@import("../../gdzig_bindings.zig").raw;

/// Gets the Object from a reference.
///
/// @param ref A pointer to the reference.
///
/// @return A pointer to the Object from the reference.
///
/// @since 4.1
pub inline fn refGetObject(ref: *const anyopaque) ?*Object {
    return @ptrCast(raw.refGetObject(ref));
}

/// Sets the Object referred to by a reference.
///
/// @param ref A pointer to the reference.
/// @param object A pointer to the Object to refer to (can be null).
///
/// @since 4.1
pub inline fn refSetObject(ref: *anyopaque, object: ?*Object) void {
    raw.refSetObject(ref, if (object) |o| o.ptr() else null);
}

const class = @import("../class.zig");
const Object = class.Object;
const Interface = @import("../Interface.zig");
