const max_align_t = c_longdouble;
const SIZE_OFFSET: usize = 0;
const ELEMENT_OFFSET = if ((SIZE_OFFSET + @sizeOf(u64)) % @alignOf(u64) == 0) (SIZE_OFFSET + @sizeOf(u64)) else ((SIZE_OFFSET + @sizeOf(u64)) + @alignOf(u64) - ((SIZE_OFFSET + @sizeOf(u64)) % @alignOf(u64)));
const DATA_OFFSET = if ((ELEMENT_OFFSET + @sizeOf(u64)) % @alignOf(max_align_t) == 0) (ELEMENT_OFFSET + @sizeOf(u64)) else ((ELEMENT_OFFSET + @sizeOf(u64)) + @alignOf(max_align_t) - ((ELEMENT_OFFSET + @sizeOf(u64)) % @alignOf(max_align_t)));

pub fn alloc(size: u32) ?[*]u8 {
    if (@import("builtin").mode == .Debug) {
        const p: [*c]u8 = @ptrCast(core.memAlloc(size));
        return p;
    } else {
        const p: [*c]u8 = @ptrCast(core.memAlloc(size + DATA_OFFSET));
        return @ptrCast(&p[DATA_OFFSET]);
    }
}

pub fn free(ptr: ?*anyopaque) void {
    if (ptr) |p| {
        core.memFree(p);
    }
}

const std = @import("std");

const godot = @import("root.zig");
const core = godot.core;
const debug = godot.debug;
const meta = godot.meta;
const Object = godot.core.Object;
