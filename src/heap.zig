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

pub fn create(comptime T: type) !*T {
    const self = try godot.general_allocator.create(T);
    self.base = .{ .godot_object = core.classdbConstructObject2(@ptrCast(godot.getParentClassName(T))) };
    core.objectSetInstance(self.base.godot_object, @ptrCast(godot.getClassName(T)), @ptrCast(self));
    core.objectSetInstanceBinding(self.base.godot_object, godot.p_library, @ptrCast(self), @ptrCast(&godot.dummy_callbacks));
    if (@hasDecl(T, "init")) {
        self.init();
    }
    return self;
}

pub fn recreate(comptime T: type, obj: *anyopaque) !*T {
    const self = try godot.general_allocator.create(T);
    self.* = std.mem.zeroInit(T, .{});
    self.base = @bitCast(Object{ .ptr = obj });
    core.objectSetInstance(self.base.godot_object, @ptrCast(godot.getClassName(T)), @ptrCast(self));
    core.objectSetInstanceBinding(self.base.godot_object, godot.p_library, @ptrCast(self), @ptrCast(&godot.dummy_callbacks));
    if (@hasDecl(T, "init")) {
        self.init();
    }
    return self;
}

pub fn destroy(object: anytype) void {
    core.objectFreeInstanceBinding(meta.asObjectPtr(object), godot.p_library);
    core.objectDestroy(meta.asObjectPtr(object));
}

const std = @import("std");

const godot = @import("root.zig");
const core = godot.core;
const meta = godot.meta;
const Object = godot.core.Object;
