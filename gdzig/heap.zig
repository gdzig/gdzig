const max_align_t = c_longdouble;
const SIZE_OFFSET: usize = 0;
const ELEMENT_OFFSET = if ((SIZE_OFFSET + @sizeOf(u64)) % @alignOf(u64) == 0) (SIZE_OFFSET + @sizeOf(u64)) else ((SIZE_OFFSET + @sizeOf(u64)) + @alignOf(u64) - ((SIZE_OFFSET + @sizeOf(u64)) % @alignOf(u64)));
const DATA_OFFSET = if ((ELEMENT_OFFSET + @sizeOf(u64)) % @alignOf(max_align_t) == 0) (ELEMENT_OFFSET + @sizeOf(u64)) else ((ELEMENT_OFFSET + @sizeOf(u64)) + @alignOf(max_align_t) - ((ELEMENT_OFFSET + @sizeOf(u64)) % @alignOf(max_align_t)));

pub var general_allocator: std.mem.Allocator = undefined;

pub fn alloc(size: u32) ?[*]u8 {
    if (@import("builtin").mode == .Debug) {
        const p: [*c]u8 = @ptrCast(godot.interface.memAlloc(size));
        return p;
    } else {
        const p: [*c]u8 = @ptrCast(godot.interface.memAlloc(size + DATA_OFFSET));
        return @ptrCast(&p[DATA_OFFSET]);
    }
}

pub fn free(ptr: ?*anyopaque) void {
    if (ptr) |p| {
        godot.interface.memFree(p);
    }
}

const std = @import("std");

const godot = @import("gdzig.zig");
const debug = godot.debug;
const meta = godot.meta;
const Object = godot.class.Object;
