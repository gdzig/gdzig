//! Parse a compatibility floor against measured manifest targets, not an allowlist.

/// Normalize major.minor[.patch] and require an exact measured manifest target.
pub fn parse(text: []const u8, comptime targets: anytype) !Version {
    const minimum = try Version.parseStrict(text);
    inline for (targets) |target| {
        const measured = try Version.parseStrict(target.source.version);
        if (minimum.major == measured.major and minimum.minor == measured.minor and
            minimum.patch == measured.patch) return minimum;
    }
    return error.UnsupportedCompatibilityMinimum;
}

/// Whether the actual engine meets an optional compile-time compatibility floor.
pub fn accepts(actual: Version, minimum: ?Version) bool {
    return if (minimum) |floor| actual.gte(floor) else true;
}

test "optional minimum rejects older engines but accepts equal and newer engines" {
    const minimum = Version.parse("4.7.0");
    try std.testing.expect(!accepts(Version.parse("4.6.3"), minimum));
    try std.testing.expect(accepts(minimum, minimum));
    try std.testing.expect(accepts(Version.parse("4.7.2"), minimum));
    try std.testing.expect(accepts(Version.parse("4.6.3"), null));
}

test "minimum support is derived from targets and rejects unmeasured versions" {
    const targets = [_]struct {
        source: struct { version: []const u8 },
    }{
        .{ .source = .{ .version = "4.6.0" } },
        .{ .source = .{ .version = "4.7.2" } },
    };
    const floor = try parse("4.6", &targets);
    try std.testing.expectEqual(@as(u32, 0), floor.patch);
    const exact = try parse("4.7.2", &targets);
    try std.testing.expectEqual(@as(u32, 2), exact.patch);
    try std.testing.expectError(error.UnsupportedCompatibilityMinimum, parse("4.6.1", &targets));
    try std.testing.expectError(error.InvalidVersion, parse("4.6.4294967296", &targets));
    try std.testing.expectError(error.InvalidVersion, parse("4.6-stable", &targets));
}

const std = @import("std");

const Version = @import("version.zig").Version;
