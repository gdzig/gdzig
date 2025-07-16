/// Global instance of the Godot allocator
pub var godot_allocator: GodotAllocator = .init;
pub var debug_allocator: std.heap.DebugAllocator(.{}) = .{
    .backing_allocator = godot_allocator.allocator(),
};
pub var general_allocator = debug_allocator.allocator();

/// Godot memory allocator that implements the Zig Allocator interface.
/// This allocator uses Godot's memory management functions internally.
pub const GodotAllocator = struct {
    pub const vtable = Allocator.VTable{
        .alloc = @ptrCast(&alloc_impl),
        .resize = @ptrCast(&resize_impl),
        .remap = @ptrCast(&remap_impl),
        .free = @ptrCast(&free_impl),
    };

    pub const Error = Allocator.Error;

    pub const init: GodotAllocator = .{};

    /// Allocates memory.
    ///
    /// - **size**: The amount of memory to allocate in bytes.
    ///
    /// @since 4.1
    pub inline fn alloc(_: GodotAllocator, size: usize) Error!*anyopaque {
        return raw.memAlloc(size) orelse error.OutOfMemory;
    }

    /// Reallocates memory.
    ///
    /// - **ptr**: A pointer to the previously allocated memory.
    /// - **size**: The number of bytes to resize the memory block to.
    ///
    /// @since 4.1
    pub inline fn realloc(_: GodotAllocator, ptr: *anyopaque, size: usize) Error!*anyopaque {
        return raw.memRealloc(ptr, size) orelse error.OutOfMemory;
    }

    /// Frees memory.
    ///
    /// - **ptr**: A pointer to the previously allocated memory.
    ///
    /// @since 4.1
    pub inline fn free(_: GodotAllocator, ptr: *anyopaque) void {
        raw.memFree(ptr);
    }

    fn alloc_impl(_: *GodotAllocator, len: usize, alignment: Alignment, ret_addr: usize) ?[*]u8 {
        _ = ret_addr;

        // Allocate extra space for alignment plus space to store the original pointer
        const ptr_size = @sizeOf(usize);
        const unaligned_size = len + alignment.toByteUnits() - 1 + ptr_size;
        const ptr = raw.memAlloc(unaligned_size) orelse return null;

        // Calculate aligned address, ensuring space for the original pointer
        const unaligned_addr = @intFromPtr(ptr);
        const aligned_addr = alignment.forward(unaligned_addr + ptr_size);

        // Store the original pointer just before the aligned address
        @as(*usize, @ptrFromInt(aligned_addr - ptr_size)).* = unaligned_addr;

        return @ptrFromInt(aligned_addr);
    }

    fn resize_impl(_: *GodotAllocator, memory: []u8, alignment: Alignment, new_len: usize, ret_addr: usize) bool {
        _ = memory;
        _ = new_len;
        _ = alignment;
        _ = ret_addr;

        return false;
    }

    fn remap_impl(_: *GodotAllocator, memory: []u8, alignment: Alignment, new_len: usize, ret_addr: usize) ?[*]u8 {
        _ = ret_addr;

        if (alignment.toByteUnits() > 1) {
            // Get the original pointer that was stored just before the aligned address
            const aligned_addr = @intFromPtr(memory.ptr);
            const ptr_size = @sizeOf(usize);
            const original_ptr_loc = @as(*usize, @ptrFromInt(aligned_addr - ptr_size));
            const original_addr = original_ptr_loc.*;
            const original_ptr = @as(*anyopaque, @ptrFromInt(original_addr));

            // Calculate new size with alignment and space for storing the original pointer
            const unaligned_size = new_len + alignment.toByteUnits() - 1 + ptr_size;

            // Reallocate using Godot's memory function
            const new_ptr = raw.memRealloc(original_ptr, unaligned_size) orelse return null;

            // Calculate new aligned address, ensuring space for the original pointer
            const new_unaligned_addr = @intFromPtr(new_ptr);
            const new_aligned_addr = alignment.forward(new_unaligned_addr + ptr_size);

            // Store the new original pointer just before the aligned address
            const new_original_ptr_loc = @as(*usize, @ptrFromInt(new_aligned_addr - ptr_size));
            new_original_ptr_loc.* = new_unaligned_addr;

            return @ptrFromInt(new_aligned_addr);
        } else {
            // No alignment needed, reallocate directly
            const new_ptr = raw.memRealloc(memory.ptr, new_len) orelse return null;
            return @ptrCast(new_ptr);
        }
    }

    fn free_impl(_: *GodotAllocator, memory: []u8, alignment: Alignment, ret_addr: usize) void {
        _ = ret_addr;

        if (alignment.toByteUnits() > 1) {
            // The original pointer was stored just before the aligned address
            const aligned_addr = @intFromPtr(memory.ptr);
            const ptr_size = @sizeOf(usize);
            const original_addr = @as(*usize, @ptrFromInt(aligned_addr - ptr_size)).*;
            const original_ptr = @as(*anyopaque, @ptrFromInt(original_addr));
            raw.memFree(original_ptr);
        } else {
            // No alignment was needed, free directly
            raw.memFree(memory.ptr);
        }
    }

    pub fn allocator(_: GodotAllocator) Allocator {
        return .{
            .ptr = undefined,
            .vtable = &vtable,
        };
    }
};

const raw: *Interface = &@import("./gdzig.zig").raw;

const std = @import("std");
const Alignment = std.mem.Alignment;
const Allocator = std.mem.Allocator;

const Interface = @import("./Interface.zig");
