const raw: *Interface = &@import("../../gdzig_bindings.zig").raw;

/// Returns writable pointer to internal Image buffer.
///
/// @param image A pointer to a Image object.
///
/// @return Pointer to internal Image buffer.
///
/// @see Image::ptrw()
///
/// @since 4.3
pub inline fn imagePtrw(image: *Image) []u8 {
    const len = image.getDataSize();
    return raw.imagePtrw(image.ptr())[0..len];
}

/// Returns read only pointer to internal Image buffer.
///
/// @param image A pointer to a Image object.
///
/// @return Pointer to internal Image buffer.
///
/// @see Image::ptr()
///
/// @since 4.3
pub inline fn imagePtr(image: *Image) []const u8 {
    const len = image.getDataSize();
    return raw.imagePtr(image.ptr())[0..len];
}

const class = @import("../class.zig");
const Image = class.Image;
const Interface = @import("../Interface.zig");
