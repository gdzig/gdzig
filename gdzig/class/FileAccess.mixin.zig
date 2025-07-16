/// Stores the given buffer slice using this FileAccess instance.
///
/// - **buf**: A slice containing the data to store.
///
/// @see FileAccess::store_buffer()
///
/// **Since Godot 4.1**
pub inline fn writeBuf(self: *FileAccess, buf: []const u8) void {
    raw.fileAccessStoreBuffer(
        self.ptr(),
        @ptrCast(buf.ptr),
        @intCast(buf.len),
    );
}

/// Reads the next bytes into the given buffer slice using this FileAccess instance.
///
/// - **buf**: A slice to store the data.
///
/// Returns a sub-slice of the buffer containing the read data.
///
/// **Since Godot 4.1**
pub inline fn readBuf(self: *const FileAccess, buf: []u8) []u8 {
    const len = @as(usize, @intCast(raw.fileAccessGetBuffer(
        self.constPtr(),
        @ptrCast(buf.ptr),
        @intCast(buf.len),
    )));
    return buf[0..len];
}

// @mixin stop

const raw: *Interface = &@import("../gdzig.zig").raw;

const Interface = @import("../Interface.zig");
const FileAccess = @import("./file_access.zig").FileAccess;
