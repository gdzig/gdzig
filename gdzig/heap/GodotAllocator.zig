pub var general_allocator: Allocator = .{
    .ptr = undefined,
    .vtable = &uninitialized_vtable,
};

const uninitialized_vtable: Allocator.VTable = .{
    .alloc = &uninitializedAlloc,
    .resize = &uninitializedResize,
    .remap = &uninitializedRemap,
    .free = &uninitializedFree,
};

fn uninitializedAlloc(_: *anyopaque, _: usize, _: Alignment, _: usize) ?[*]u8 {
    @panic("gdzig: general_allocator used before setAllocator() was called.");
}

fn uninitializedResize(_: *anyopaque, _: []u8, _: Alignment, _: usize, _: usize) bool {
    @panic("gdzig: general_allocator used before setAllocator() was called.");
}

fn uninitializedRemap(_: *anyopaque, _: []u8, _: Alignment, _: usize, _: usize) ?[*]u8 {
    @panic("gdzig: general_allocator used before setAllocator() was called.");
}

fn uninitializedFree(_: *anyopaque, _: []u8, _: Alignment, _: usize) void {
    @panic("gdzig: general_allocator used before setAllocator() was called.");
}

pub fn setAllocator(a: Allocator) void {
    general_allocator = a;
}

pub fn allocator(_: *GodotAllocator) Allocator {
    return .{
        .ptr = undefined,
        .vtable = &.{
            .alloc = &alloc,
            .resize = &resize,
            .remap = &remap,
            .free = &free,
        },
    };
}

const header_size = @sizeOf(usize);

fn alloc(_: *anyopaque, len: usize, alignment: Alignment, _: usize) ?[*]u8 {
    const align_bytes = alignment.toByteUnits();
    const total_size = header_size + align_bytes - 1 + len;

    const base_ptr = raw.memAlloc(total_size) orelse return null;
    const base_addr = @intFromPtr(base_ptr);

    const aligned_addr = alignment.forward(base_addr + header_size);

    const header: *usize = @ptrFromInt(aligned_addr - header_size);
    header.* = base_addr;

    return @ptrFromInt(aligned_addr);
}

fn resize(_: *anyopaque, _: []u8, _: Alignment, _: usize, _: usize) bool {
    return false;
}

fn remap(_: *anyopaque, memory: []u8, alignment: Alignment, new_len: usize, _: usize) ?[*]u8 {
    const align_bytes = alignment.toByteUnits();
    const old_aligned_addr = @intFromPtr(memory.ptr);

    const old_header: *usize = @ptrFromInt(old_aligned_addr - header_size);
    const old_base_addr = old_header.*;
    const old_offset = old_aligned_addr - old_base_addr;

    const total_size = header_size + align_bytes - 1 + new_len;

    const new_base_ptr = raw.memRealloc(@ptrFromInt(old_base_addr), total_size) orelse return null;
    const new_base_addr = @intFromPtr(new_base_ptr);

    const new_aligned_addr = alignment.forward(new_base_addr + header_size);
    const new_offset = new_aligned_addr - new_base_addr;

    if (old_offset != new_offset) {
        const src: [*]u8 = @ptrFromInt(new_base_addr + old_offset);
        const dst: [*]u8 = @ptrFromInt(new_aligned_addr);
        const copy_len = @min(memory.len, new_len);
        std.mem.copyBackwards(u8, dst[0..copy_len], src[0..copy_len]);
    }

    const new_header: *usize = @ptrFromInt(new_aligned_addr - header_size);
    new_header.* = new_base_addr;

    return @ptrFromInt(new_aligned_addr);
}

fn free(_: *anyopaque, memory: []u8, _: Alignment, _: usize) void {
    const aligned_addr = @intFromPtr(memory.ptr);

    const header: *usize = @ptrFromInt(aligned_addr - header_size);
    const base_addr = header.*;

    raw.memFree(@ptrFromInt(base_addr));
}

const std = @import("std");
const Allocator = std.mem.Allocator;
const Alignment = std.mem.Alignment;
const Interface = @import("../Interface.zig");

const GodotAllocator = @This();

const raw: *Interface = &@import("../gdzig.zig").raw;
