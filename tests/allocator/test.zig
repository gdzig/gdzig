pub const level: godot.InitializationLevel = .core;

pub fn run() !void {
    try testAllocFree(.@"1");
    try testAllocFree(.@"16");

    try testRemap(.@"1");
    try testRemap(.@"16");

    try testRepeatedRemap();
}

fn testAllocFree(comptime alignment: Alignment) !void {
    const mem = try testing.allocator.alignedAlloc(u8, alignment, 64);
    defer testing.allocator.free(mem);

    try testing.expect(alignment.check(@intFromPtr(mem.ptr)));
    @memset(mem, 0xAB);
}

fn testRemap(comptime alignment: Alignment) !void {
    var mem = try testing.allocator.alignedAlloc(u8, alignment, 32);

    for (mem, 0..) |*byte, i| {
        byte.* = @truncate(i);
    }

    mem = try testing.allocator.realloc(mem, 128);

    try testing.expect(alignment.check(@intFromPtr(mem.ptr)));
    for (mem[0..32], 0..) |byte, i| {
        try testing.expectEqual(@as(u8, @truncate(i)), byte);
    }

    testing.allocator.free(mem);
}

fn testRepeatedRemap() !void {
    var mem = try testing.allocator.alignedAlloc(u8, .@"16", 16);
    @memset(mem, 0x42);

    mem = try testing.allocator.realloc(mem, 64);
    mem = try testing.allocator.realloc(mem, 256);
    mem = try testing.allocator.realloc(mem, 32);

    for (mem[0..16]) |byte| {
        try testing.expectEqual(@as(u8, 0x42), byte);
    }

    testing.allocator.free(mem);
}

const std = @import("std");
const Alignment = std.mem.Alignment;

const godot = @import("gdzig");
const testing = @import("gdzig_test");
