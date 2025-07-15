/// Returns a mutable slice of the internal Image buffer.
///
/// **Since Godot 4.3**
pub inline fn slice(self: *Image) []u8 {
    const len = self.getDataSize();
    const ptr = @as([*]u8, @ptrCast(raw.imagePtr(self.ptr())));
    return ptr[0..len];
}

/// Returns a const slice of the internal Image buffer.
///
/// **Since Godot 4.3**
pub inline fn constSlice(self: *const Image) []const u8 {
    const len = self.getDataSize();
    const ptr = @as([*]const u8, @ptrCast(raw.imagePtr(@constCast(self.constPtr()))));
    return ptr[0..len];
}

// @mixin stop

const raw: *Interface = &@import("../gdzig_bindings.zig").raw;

const Interface = @import("../Interface.zig");
const Image = @import("./image.zig").Image;
