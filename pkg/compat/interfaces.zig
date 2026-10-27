//! Measured GDExtension interface availability.
//!
//! Evidence is the set of `@name` entries in a release's own
//! `gdextension_interface.h`. Names are canonicalized in byte-wise order so the
//! same rules produce manifest deltas, digests and bindgen lookups.

/// A canonical set of measured interface names.
pub const Names = struct {
    /// Sorted, unique, valid interface names.
    items: []const []const u8,

    /// Extract every `@name` entry from one engine header.
    /// Malformed or duplicate names are rejected instead of being repaired.
    pub fn parse(allocator: Allocator, header_bytes: []const u8) !Names {
        var names: std.ArrayList([]const u8) = .empty;
        defer names.deinit(allocator);
        var lines = std.mem.splitScalar(u8, header_bytes, '\n');
        while (lines.next()) |raw_line| {
            const line = std.mem.trimEnd(u8, raw_line, "\r");
            const tag = "@name ";
            const tag_index = std.mem.indexOf(u8, line, tag) orelse continue;
            const name = std.mem.trim(u8, line[tag_index + tag.len ..], " \t\r");
            try names.append(allocator, name);
        }
        return init(allocator, names.items);
    }

    /// Own a canonical copy of `names`, rejecting invalid evidence.
    pub fn init(allocator: Allocator, names: []const []const u8) !Names {
        const sorted = try allocator.dupe([]const u8, names);
        errdefer allocator.free(sorted);
        std.mem.sort([]const u8, sorted, {}, lessName);
        const result: Names = .{ .items = sorted };
        try result.validate();
        return result;
    }

    /// Require a non-empty, strictly sorted, unique list of valid names.
    pub fn validate(self: Names) !void {
        if (self.items.len == 0) return error.InvalidInterfaceEvidence;
        for (self.items, 0..) |name, i| {
            if (!isValidName(name)) return error.InvalidInterfaceEvidence;
            if (i > 0 and !std.mem.lessThan(u8, self.items[i - 1], name)) {
                return error.InvalidInterfaceEvidence;
            }
        }
    }

    /// SHA-256 over canonical names joined by `\n` with a trailing `\n`.
    pub fn digest(self: Names, allocator: Allocator) ![]const u8 {
        var hash = std.crypto.hash.sha2.Sha256.init(.{});
        for (self.items) |name| {
            hash.update(name);
            hash.update("\n");
        }
        var result: [32]u8 = undefined;
        hash.final(&result);
        return std.fmt.allocPrint(allocator, "{x}", .{result});
    }

    /// Return the names present here but absent from `old`, preserving order.
    /// An old name missing from this set means the evidence is not monotonic.
    pub fn delta(self: Names, allocator: Allocator, old: Names) ![]const []const u8 {
        var removed = false;
        var result: std.ArrayList([]const u8) = .empty;
        var old_index: usize = 0;
        for (self.items) |name| {
            while (old_index < old.items.len and
                std.mem.lessThan(u8, old.items[old_index], name)) : (old_index += 1)
            {
                removed = true;
            }
            if (old_index < old.items.len and std.mem.eql(u8, old.items[old_index], name)) {
                old_index += 1;
                continue;
            }
            try result.append(allocator, name);
        }
        if (old_index < old.items.len) removed = true;
        if (removed) return error.NonMonotonicInterfaceEvidence;
        return result.toOwnedSlice(allocator);
    }

    /// Content membership in the canonical set.
    pub fn contains(self: Names, name: []const u8) bool {
        var low: usize = 0;
        var high: usize = self.items.len;
        while (low < high) {
            const middle = low + (high - low) / 2;
            switch (std.mem.order(u8, self.items[middle], name)) {
                .lt => low = middle + 1,
                .gt => high = middle,
                .eq => return true,
            }
        }
        return false;
    }

    /// Compare two canonical sets by contents, never by slice addresses.
    pub fn eql(self: Names, other: Names) bool {
        if (self.items.len != other.items.len) return false;
        for (self.items, other.items) |left, right| {
            if (!std.mem.eql(u8, left, right)) return false;
        }
        return true;
    }
};

/// A C identifier: ASCII letters or underscore first, then alphanumerics.
fn isValidName(name: []const u8) bool {
    if (name.len == 0) return false;
    if (!(std.ascii.isAlphabetic(name[0]) or name[0] == '_')) return false;
    for (name[1..]) |byte| {
        if (!(std.ascii.isAlphanumeric(byte) or byte == '_')) return false;
    }
    return true;
}

fn lessName(_: void, a: []const u8, b: []const u8) bool {
    return std.mem.lessThan(u8, a, b);
}

const testing = struct {
    const fixture =
        \\/**
        \\ * @name get_godot_version
        \\ * @since 4.1
        \\ */
        \\/**
        \\ * @name variant_get_type_by_name
        \\ * @since 4.7
        \\ */
        \\/**
        \\ * @name mem_alloc
        \\ * @since 4.1
        \\ */
    ;
};

test "parse extracts sorted names from header comments" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const names = try Names.parse(arena.allocator(), testing.fixture);
    try std.testing.expectEqual(@as(usize, 3), names.items.len);
    try std.testing.expectEqualStrings("get_godot_version", names.items[0]);
    try std.testing.expectEqualStrings("mem_alloc", names.items[1]);
    try std.testing.expectEqualStrings("variant_get_type_by_name", names.items[2]);
}

test "parse rejects duplicate and malformed names and empty headers" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    try std.testing.expectError(
        error.InvalidInterfaceEvidence,
        Names.parse(a, " * @name twice\n * @name twice\n"),
    );
    try std.testing.expectError(error.InvalidInterfaceEvidence, Names.parse(a, " * @name 1invalid\n"));
    try std.testing.expectError(error.InvalidInterfaceEvidence, Names.parse(a, " * @name bad-name\n"));
    try std.testing.expectError(error.InvalidInterfaceEvidence, Names.parse(a, " * @name\n"));
    try std.testing.expectError(error.InvalidInterfaceEvidence, Names.parse(a, "no tags here\n"));
    // A bare `@name` without a separator is not a tag.
    const names = try Names.parse(a, " * @name valid_name\n * @namefoo ignored\n");
    try std.testing.expectEqual(@as(usize, 1), names.items.len);
    try std.testing.expectEqualStrings("valid_name", names.items[0]);
}

test "init sorts by bytes and rejects duplicates and invalid names" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const sorted = try Names.init(a, &.{ "z_name", "Alpha", "_under" });
    try std.testing.expectEqualStrings("Alpha", sorted.items[0]);
    try std.testing.expectEqualStrings("_under", sorted.items[1]);
    try std.testing.expectEqualStrings("z_name", sorted.items[2]);
    try std.testing.expectError(error.InvalidInterfaceEvidence, Names.init(a, &.{ "same", "same" }));
    try std.testing.expectError(error.InvalidInterfaceEvidence, Names.init(a, &.{""}));
    try std.testing.expectError(error.InvalidInterfaceEvidence, Names.init(a, &.{}));
    try std.testing.expectError(
        error.InvalidInterfaceEvidence,
        (Names{ .items = &.{ "b", "a" } }).validate(),
    );
    try std.testing.expectError(
        error.InvalidInterfaceEvidence,
        (Names{ .items = &.{ "a", "a" } }).validate(),
    );
}

test "delta is sorted and removed names fail as non-monotonic" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const current = try Names.init(a, &.{ "alpha", "charlie", "delta" });
    const old = try Names.init(a, &.{"alpha"});
    const added = try current.delta(a, old);
    try std.testing.expectEqual(@as(usize, 2), added.len);
    try std.testing.expectEqualStrings("charlie", added[0]);
    try std.testing.expectEqualStrings("delta", added[1]);
    const partial = try Names.init(a, &.{ "alpha", "charlie" });
    try std.testing.expectEqual(@as(usize, 1), (try current.delta(a, partial)).len);
    try std.testing.expectError(
        error.NonMonotonicInterfaceEvidence,
        current.delta(a, try Names.init(a, &.{ "alpha", "zulu" })),
    );
}

test "digest is order independent and pins the joined name bytes" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const first = try (try Names.init(a, &.{ "beta", "alpha" })).digest(a);
    const second = try (try Names.init(a, &.{ "alpha", "beta" })).digest(a);
    try std.testing.expectEqualStrings(first, second);
    // sha256("alpha\nbeta\n")
    try std.testing.expectEqualStrings(
        "e49c81e2d2f84e259d40e2fb8192f3bcd198b355184845d76d8f58807d0d78ee",
        first,
    );
}

test "contains and eql compare contents rather than slice addresses" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const sorted = try Names.init(a, &.{ "alpha", "charlie" });
    const probe = try a.dupe(u8, "charlie");
    try std.testing.expect(sorted.contains(probe));
    try std.testing.expect(!sorted.contains("bravo"));
    try std.testing.expect(sorted.eql(try Names.init(a, &.{ "charlie", "alpha" })));
    try std.testing.expect(!sorted.eql(try Names.init(a, &.{"alpha"})));
}

const std = @import("std");
const Allocator = std.mem.Allocator;
