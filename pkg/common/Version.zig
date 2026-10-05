//! Shared numeric Godot version. The extern layout also accepts get_godot_version.
pub const Version = extern struct {
    major: u32,
    minor: u32,
    patch: u32,
    string: [*:0]const u8 = "",

    pub const @"4.1" = parse("4.1");
    pub const @"4.2" = parse("4.2");
    pub const @"4.3" = parse("4.3");
    pub const @"4.4" = parse("4.4");
    pub const @"4.5" = parse("4.5");
    pub const @"4.6" = parse("4.6");
    pub const @"4.7" = parse("4.7");

    var current: Version = undefined;

    /// Return whether this numeric version is newer than other.
    pub fn gt(self: Version, other: Version) bool {
        if (self.major != other.major) return self.major > other.major;
        if (self.minor != other.minor) return self.minor > other.minor;
        return self.patch > other.patch;
    }

    /// Return whether this numeric version is newer than or equal to other.
    pub fn gte(self: Version, other: Version) bool {
        if (self.major != other.major) return self.major > other.major;
        if (self.minor != other.minor) return self.minor > other.minor;
        return self.patch >= other.patch;
    }

    /// Return whether this numeric version is older than other.
    pub fn lt(self: Version, other: Version) bool {
        if (self.major != other.major) return self.major < other.major;
        if (self.minor != other.minor) return self.minor < other.minor;
        return self.patch < other.patch;
    }

    /// Return whether this numeric version is older than or equal to other.
    pub fn lte(self: Version, other: Version) bool {
        if (self.major != other.major) return self.major < other.major;
        if (self.minor != other.minor) return self.minor < other.minor;
        return self.patch <= other.patch;
    }

    /// Returns true if self is in the range [min_ver, max_ver).
    pub fn range(self: Version, min_ver: Version, max_ver: Version) bool {
        return self.gte(min_ver) and self.lt(max_ver);
    }

    /// Legacy parser, retained unchanged for existing callers and constants.
    pub fn parse(version_string: []const u8) Version {
        var parts: [3]u32 = .{ 0, 0, 0 };
        var part_idx: usize = 0;
        for (version_string) |ch| {
            if (ch == '.') {
                part_idx += 1;
            } else {
                parts[part_idx] = parts[part_idx] * 10 + (ch - '0');
            }
        }
        return .{ .major = parts[0], .minor = parts[1], .patch = parts[2] };
    }

    /// Strict major.minor[.patch] user-input parser. Support policy is separate.
    pub fn parseStrict(text: []const u8) error{InvalidVersion}!Version {
        var components = std.mem.splitScalar(u8, text, '.');
        var parts: [3]u32 = .{ 0, 0, 0 };
        var count: usize = 0;
        while (components.next()) |component| {
            if (count == parts.len or component.len == 0) return error.InvalidVersion;
            for (component) |ch| if (ch < '0' or ch > '9') return error.InvalidVersion;
            parts[count] = std.fmt.parseInt(u32, component, 10) catch return error.InvalidVersion;
            count += 1;
        }
        if (count < 2) return error.InvalidVersion;
        return .{ .major = parts[0], .minor = parts[1], .patch = parts[2] };
    }
};

test "legacy version parsing and comparisons" {
    const v14_2 = Version.parse("14.2.0");
    const v14_3 = Version.parse("14.3.0");
    try std.testing.expectEqual(v14_2.major, 14);
    try std.testing.expectEqual(v14_2.minor, 2);
    try std.testing.expectEqual(v14_2.patch, 0);
    try std.testing.expect(v14_3.gt(v14_2));
    try std.testing.expect(v14_3.gte(v14_2));
    try std.testing.expect(v14_2.lt(v14_3));
    try std.testing.expect(v14_2.lte(v14_3));
    try std.testing.expect(v14_3.range(v14_2, Version.parse("14.4.0")));
}

const std = @import("std");
