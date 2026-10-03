test "intentional assertion after large stderr" {
    var chunk: [16384]u8 = undefined;
    @memset(&chunk, 'x');
    // Exceed pipe capacity before the assertion. An undrained stderr pipe hangs.
    for (0..8) |_| std.debug.print("{s}\n", .{&chunk});
    try std.testing.expectEqual(@as(u32, 8675309), @as(u32, 42));
}

const std = @import("std");
