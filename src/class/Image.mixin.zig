/// Returns a mutable slice of the internal Image buffer.
///
/// **Since Godot 4.3**
pub inline fn slice(self: *Self) []u8 {
    const len = @as(usize, @intCast(self.getDataSize()));
    const p = @as([*]u8, @ptrCast(raw.imagePtr(self.ptr())));
    return p[0..len];
}

/// Returns a const slice of the internal Image buffer.
///
/// **Since Godot 4.3**
pub inline fn constSlice(self: *const Self) []const u8 {
    const len = @as(usize, @intCast(self.getDataSize()));
    const p = @as([*]const u8, @ptrCast(raw.imagePtr(@constCast(self.constPtr()))));
    return p[0..len];
}

// @mixin stop

const Self = gdzig.class.Image;

const gdzig = @import("gdzig");
const raw = &gdzig.raw;
