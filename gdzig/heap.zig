/// An allocator backed by the Godot Engine's internal allocator.
pub const engine_allocator: Allocator = .{
    .ptr = undefined,
    .vtable = &.{
        .alloc = @ptrCast(&alloc),
        .resize = @ptrCast(&resize),
        .remap = @ptrCast(&remap),
        .free = @ptrCast(&free),
    },
};

fn alloc(_: *anyopaque, len: usize, alignment: Alignment, ret_addr: usize) ?[*]u8 {
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

fn resize(_: *anyopaque, memory: []u8, alignment: Alignment, new_len: usize, ret_addr: usize) bool {
    _ = memory;
    _ = new_len;
    _ = alignment;
    _ = ret_addr;

    return false;
}

fn remap(_: *anyopaque, memory: []u8, alignment: Alignment, new_len: usize, ret_addr: usize) ?[*]u8 {
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

fn free(_: *anyopaque, memory: []u8, alignment: Alignment, ret_addr: usize) void {
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

const std = @import("std");
const Alignment = std.mem.Alignment;
const Allocator = std.mem.Allocator;

const gdzig = @import("gdzig");
const raw = &gdzig.raw;
