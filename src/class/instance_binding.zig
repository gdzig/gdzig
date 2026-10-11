/// Returns the shared instance-binding key for a Zig extension class type.
/// One token is used regardless of the generated engine wrapper at the call site.
pub fn typeToken(comptime T: type) *anyopaque {
    return @ptrCast(&struct {
        var token: u8 = 0;
        comptime {
            _ = T;
        }
    }.token);
}

test "binding token is stable per type and distinct between types" {
    const A = struct {};
    const B = struct {};
    try std.testing.expect(typeToken(A) == typeToken(A));
    try std.testing.expect(typeToken(A) != typeToken(B));
}

const std = @import("std");
