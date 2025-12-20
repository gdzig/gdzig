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
