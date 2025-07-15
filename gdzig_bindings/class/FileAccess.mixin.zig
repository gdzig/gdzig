/// Stores the given buffer using this FileAccess instance.
///
/// - **buffer**: A slice containing the data to store.
///
/// @see FileAccess::store_buffer()
///
/// **Since Godot 4.1**
pub inline fn storeBuffer(self: *FileAccess, buffer: []const u8) void {
    raw.fileAccessStoreBuffer(self.ptr(), buffer.ptr, buffer.len);
}

/// Reads the next bytes into the given buffer using this FileAccess instance.
///
/// - **buffer**: A slice to store the data.
///
/// @return The actual number of bytes read (may be less than requested).
///
/// **Since Godot 4.1**
pub inline fn getBuffer(self: *const FileAccess, buffer: []u8) u64 {
    return raw.fileAccessGetBuffer(self.constPtr(), buffer.ptr, buffer.len);
}

// @mixin stop

const raw: *Interface = &@import("../gdzig_bindings.zig").raw;

const Interface = @import("../Interface.zig");
const FileAccess = @import("./file_access.zig").FileAccess;
