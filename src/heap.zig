pub const engine_allocator: Allocator = .{
    .ptr = undefined,
    .vtable = &.{
        .alloc = @ptrCast(&alloc),
        .resize = @ptrCast(&resize),
        .remap = @ptrCast(&remap),
        .free = @ptrCast(&free),
    },
};

fn alloc(_: *anyopaque, len: usize, alignment: Alignment, _: usize) ?[*]u8 {
    if (alignment == .@"1") {
        return @ptrCast(raw.memAlloc(len) orelse return null);
    }

    const padding = alignment.toByteUnits();
    const unaligned_ptr = raw.memAlloc(len + padding) orelse return null;
    const unaligned_addr = @intFromPtr(unaligned_ptr);
    const aligned_addr = alignment.forward(unaligned_addr + @sizeOf(u32));

    @as(*align(1) u32, @ptrFromInt(aligned_addr - @sizeOf(u32))).* = @intCast(aligned_addr - unaligned_addr);

    return @ptrFromInt(aligned_addr);
}

fn resize(_: *anyopaque, _: []u8, _: Alignment, _: usize, _: usize) bool {
    return false;
}

fn remap(_: *anyopaque, memory: []u8, alignment: Alignment, new_len: usize, _: usize) ?[*]u8 {
    if (alignment == .@"1") {
        return @ptrCast(raw.memRealloc(memory.ptr, new_len) orelse return null);
    }

    const padding = alignment.toByteUnits();
    const aligned_addr = @intFromPtr(memory.ptr);
    const offset = @as(*align(1) u32, @ptrFromInt(aligned_addr - @sizeOf(u32))).*;

    const new_unaligned_ptr = raw.memRealloc(@ptrFromInt(aligned_addr - offset), new_len + padding) orelse return null;
    const new_unaligned_addr = @intFromPtr(new_unaligned_ptr);
    const new_aligned_addr = alignment.forward(new_unaligned_addr + @sizeOf(u32));

    @as(*align(1) u32, @ptrFromInt(new_aligned_addr - @sizeOf(u32))).* = @intCast(new_aligned_addr - new_unaligned_addr);

    return @ptrFromInt(new_aligned_addr);
}

fn free(_: *anyopaque, memory: []u8, alignment: Alignment, _: usize) void {
    if (alignment == .@"1") {
        raw.memFree(memory.ptr);
        return;
    }

    const aligned_addr = @intFromPtr(memory.ptr);
    const offset = @as(*align(1) u32, @ptrFromInt(aligned_addr - @sizeOf(u32))).*;

    raw.memFree(@ptrFromInt(aligned_addr - offset));
}

const std = @import("std");
const Alignment = std.mem.Alignment;
const Allocator = std.mem.Allocator;

const gdzig = @import("gdzig");
const raw = &gdzig.raw;
