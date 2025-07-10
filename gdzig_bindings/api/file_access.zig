const raw: *Interface = &@import("../../gdzig_bindings.zig").raw;

/// Stores the given buffer using an instance of FileAccess.
///
/// @param file A pointer to a FileAccess object.
/// @param buffer A slice containing the data to store.
///
/// @see FileAccess::store_buffer()
///
/// @since 4.1
pub inline fn fileAccessStoreBuffer(file: *FileAccess, buffer: []const u8) void {
    raw.fileAccessStoreBuffer(file.ptr(), buffer.ptr, buffer.len);
}

/// Reads the next bytes into the given buffer using an instance of FileAccess.
///
/// @param file A pointer to a FileAccess object.
/// @param buffer A slice to store the data.
///
/// @return The actual number of bytes read (may be less than requested).
///
/// @since 4.1
pub inline fn fileAccessGetBuffer(file: *const FileAccess, buffer: []u8) u64 {
    return raw.fileAccessGetBuffer(file.constPtr(), buffer.ptr, buffer.len);
}

const class = @import("../class.zig");
const FileAccess = class.FileAccess;
const Interface = @import("../Interface.zig");
