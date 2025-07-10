const raw: *Interface = &@import("../../gdzig_bindings.zig").raw;

/// Allocates memory.
///
/// @param size The amount of memory to allocate in bytes.
///
/// @return A pointer to the allocated memory, or NULL if unsuccessful.
///
/// @since 4.1
pub inline fn alloc(size: usize) *anyopaque {
    return raw.memAlloc(size).?;
}

/// Reallocates memory.
///
/// @param ptr A pointer to the previously allocated memory.
/// @param size The number of bytes to resize the memory block to.
///
/// @return A pointer to the allocated memory, or NULL if unsuccessful.
///
/// @since 4.1
pub inline fn realloc(ptr: *anyopaque, size: usize) *anyopaque {
    return raw.memRealloc(ptr, size).?;
}

/// Frees memory.
///
/// @param ptr A pointer to the previously allocated memory.
///
/// @since 4.1
pub inline fn free(ptr: *anyopaque) void {
    raw.memFree(ptr);
}

const Interface = @import("../Interface.zig");
