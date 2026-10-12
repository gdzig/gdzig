const GuardedRawAllocator = struct {
    const canary: u8 = 0xa5;

    // This raw-base shift forces a different payload offset at 256-byte alignment.
    const remap_raw_offset = 64;

    var allocation_buffer: [1024]u8 align(256) = undefined;
    var remap_buffer: [1024]u8 align(256) = undefined;
    var current_raw: [*]u8 = undefined;
    var requested_len: usize = 0;

    fn allocationRaw() [*]u8 {
        return @ptrCast(&allocation_buffer);
    }

    fn remapRaw() [*]u8 {
        return @ptrFromInt(@intFromPtr(&remap_buffer) + remap_raw_offset);
    }

    fn memAlloc(len: usize) callconv(.c) ?*anyopaque {
        std.debug.assert(len < allocation_buffer.len);

        requested_len = len;
        current_raw = allocationRaw();
        @memset(&allocation_buffer, 0);
        current_raw[len] = canary;
        return @ptrCast(current_raw);
    }

    fn memRealloc(ptr: ?*anyopaque, new_len: usize) callconv(.c) ?*anyopaque {
        std.debug.assert(new_len < remap_buffer.len - remap_raw_offset);

        const source: [*]const u8 = @ptrCast(ptr orelse return null);
        const preserved_len = @min(requested_len, new_len);
        const destination = remapRaw();
        if (@intFromPtr(source) != @intFromPtr(destination)) {
            @memset(&remap_buffer, 0);
            @memcpy(destination[0..preserved_len], source[0..preserved_len]);
        }

        requested_len = new_len;
        current_raw = destination;
        current_raw[new_len] = canary;
        return @ptrCast(current_raw);
    }

    fn memFree(ptr: ?*anyopaque) callconv(.c) void {
        const raw: [*]u8 = @ptrCast(ptr orelse unreachable);
        std.debug.assert(raw == current_raw);
    }

    fn observedCanary() u8 {
        return current_raw[requested_len];
    }
};

const SavedRawCallbacks = struct {
    mem_alloc: @TypeOf(gdzig.raw.memAlloc),
    mem_realloc: @TypeOf(gdzig.raw.memRealloc),
    mem_free: @TypeOf(gdzig.raw.memFree),

    fn replace() SavedRawCallbacks {
        const saved: SavedRawCallbacks = .{
            .mem_alloc = gdzig.raw.memAlloc,
            .mem_realloc = gdzig.raw.memRealloc,
            .mem_free = gdzig.raw.memFree,
        };
        gdzig.raw.memAlloc = &GuardedRawAllocator.memAlloc;
        gdzig.raw.memRealloc = &GuardedRawAllocator.memRealloc;
        gdzig.raw.memFree = &GuardedRawAllocator.memFree;
        return saved;
    }

    fn restore(saved: SavedRawCallbacks) void {
        gdzig.raw.memAlloc = saved.mem_alloc;
        gdzig.raw.memRealloc = saved.mem_realloc;
        gdzig.raw.memFree = saved.mem_free;
    }
};

test "alignment-2 allocation stays within the requested raw extent" {
    const saved_callbacks = SavedRawCallbacks.replace();
    defer saved_callbacks.restore();

    const value = try gdzig.engine_allocator.create(u16);
    defer gdzig.engine_allocator.destroy(value);

    value.* = 0xabcd;

    try testing.expectEqual(GuardedRawAllocator.canary, GuardedRawAllocator.observedCanary());
}

test "alignment-2 remap stays within the requested raw extent" {
    const saved_callbacks = SavedRawCallbacks.replace();
    defer saved_callbacks.restore();

    var values = try gdzig.engine_allocator.alloc(u16, 1);
    values[0] = 0x1234;
    values = try gdzig.engine_allocator.realloc(values, 4);
    defer gdzig.engine_allocator.free(values);

    @memset(values, 0xabcd);

    try testing.expectEqual(GuardedRawAllocator.canary, GuardedRawAllocator.observedCanary());
}

test "moving aligned remap preserves the original payload prefix" {
    const saved_callbacks = SavedRawCallbacks.replace();
    defer saved_callbacks.restore();

    const pattern = [_]u8{ 0x10, 0x23, 0x45, 0x67, 0x89, 0xab, 0xcd, 0xef };
    var values = try gdzig.engine_allocator.alignedAlloc(u8, .fromByteUnits(256), pattern.len);
    @memcpy(values, &pattern);
    values = try gdzig.engine_allocator.realloc(values, pattern.len * 2);
    defer gdzig.engine_allocator.free(values);

    try testing.expectEqualSlices(u8, &pattern, values[0..pattern.len]);
}

test "alloc and free with alignment 1" {
    const mem = try allocator.alignedAlloc(u8, .@"1", 64);
    defer allocator.free(mem);

    try testing.expect(Alignment.@"1".check(@intFromPtr(mem.ptr)));
    @memset(mem, 0xAB);
}

test "alloc and free with alignment 16" {
    const mem = try allocator.alignedAlloc(u8, .@"16", 64);
    defer allocator.free(mem);

    try testing.expect(Alignment.@"16".check(@intFromPtr(mem.ptr)));
    @memset(mem, 0xAB);
}

test "realloc with alignment 1" {
    var mem = try allocator.alignedAlloc(u8, .@"1", 32);

    for (mem, 0..) |*byte, i| {
        byte.* = @truncate(i);
    }

    mem = try allocator.realloc(mem, 128);

    try testing.expect(Alignment.@"1".check(@intFromPtr(mem.ptr)));
    for (mem[0..32], 0..) |byte, i| {
        try testing.expectEqual(@as(u8, @truncate(i)), byte);
    }

    allocator.free(mem);
}

test "realloc with alignment 16" {
    var mem = try allocator.alignedAlloc(u8, .@"16", 32);

    for (mem, 0..) |*byte, i| {
        byte.* = @truncate(i);
    }

    mem = try allocator.realloc(mem, 128);

    try testing.expect(Alignment.@"16".check(@intFromPtr(mem.ptr)));
    for (mem[0..32], 0..) |byte, i| {
        try testing.expectEqual(@as(u8, @truncate(i)), byte);
    }

    allocator.free(mem);
}

test "repeated realloc preserves data" {
    var mem = try allocator.alignedAlloc(u8, .@"16", 16);
    @memset(mem, 0x42);

    mem = try allocator.realloc(mem, 64);
    mem = try allocator.realloc(mem, 256);
    mem = try allocator.realloc(mem, 32);

    for (mem[0..16]) |byte| {
        try testing.expectEqual(@as(u8, 0x42), byte);
    }

    allocator.free(mem);
}

const std = @import("std");
const testing = std.testing;
const Alignment = std.mem.Alignment;

const gdzig = @import("gdzig");
const allocator = gdzig.testing.allocator;
