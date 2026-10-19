//! Measured GDExtension interface availability.
//!
//! Evidence is the set of `@name` entries in a release's own
//! `gdextension_interface.h`. Names are canonicalized in byte-wise order so the
//! same rules produce manifest deltas, digests and bindgen lookups.

/// Extract every `@name` entry from one engine header, sorted byte-wise.
/// Malformed or duplicate names are rejected instead of being repaired.
pub fn parse(allocator: Allocator, header_bytes: []const u8) ![]const []const u8 {
    var names: std.ArrayList([]const u8) = .empty;
    var lines = std.mem.splitScalar(u8, header_bytes, '\n');
    while (lines.next()) |raw_line| {
        const line = std.mem.trimEnd(u8, raw_line, "\r");
        const tag_index = std.mem.indexOf(u8, line, "@name") orelse continue;
        const rest = line[tag_index + "@name".len ..];
        const name = std.mem.trim(u8, rest, " \t\r");
        if (!isValidName(name)) return error.InvalidInterfaceEvidence;
        try names.append(allocator, name);
    }
    if (names.items.len == 0) return error.InvalidInterfaceEvidence;
    return canonicalize(allocator, names.items);
}

/// Validate and sort interface names, rejecting duplicates.
pub fn canonicalize(allocator: Allocator, names: []const []const u8) ![]const []const u8 {
    const result = try allocator.dupe([]const u8, names);
    std.mem.sort([]const u8, result, {}, lessName);
    try validate(result);
    return result;
}

/// Require a strictly sorted, unique list of valid interface names.
pub fn validate(sorted: []const []const u8) !void {
    if (sorted.len == 0) return error.InvalidInterfaceEvidence;
    for (sorted, 0..) |name, i| {
        if (!isValidName(name)) return error.InvalidInterfaceEvidence;
        if (i > 0 and !std.mem.lessThan(u8, sorted[i - 1], name)) {
            return error.InvalidInterfaceEvidence;
        }
    }
}

/// Return the names present in `current` but absent from `old`, preserving order.
/// An old name missing from the current header means the evidence is not monotonic.
pub fn delta(
    allocator: Allocator,
    current_sorted: []const []const u8,
    old_sorted: []const []const u8,
) ![]const []const u8 {
    try validate(current_sorted);
    try validate(old_sorted);
    var removed = false;
    var result: std.ArrayList([]const u8) = .empty;
    var old_index: usize = 0;
    for (current_sorted) |name| {
        while (old_index < old_sorted.len and
            std.mem.lessThan(u8, old_sorted[old_index], name)) : (old_index += 1)
        {
            removed = true;
        }
        if (old_index < old_sorted.len and std.mem.eql(u8, old_sorted[old_index], name)) {
            old_index += 1;
            continue;
        }
        try result.append(allocator, name);
    }
    if (old_index < old_sorted.len) removed = true;
    if (removed) return error.NonMonotonicInterfaceEvidence;
    return result.toOwnedSlice(allocator);
}

/// SHA-256 over sorted names joined by `\n` with a trailing `\n`, lowercase hex.
pub fn digest(allocator: Allocator, names: []const []const u8) ![]const u8 {
    const sorted = try canonicalize(allocator, names);
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    for (sorted) |name| {
        hash.update(name);
        hash.update("\n");
    }
    var result: [32]u8 = undefined;
    hash.final(&result);
    return std.fmt.allocPrint(allocator, "{x}", .{result});
}

/// Content membership in a sorted list. Slices are compared by contents.
pub fn contains(sorted: []const []const u8, name: []const u8) bool {
    var low: usize = 0;
    var high: usize = sorted.len;
    while (low < high) {
        const middle = low + (high - low) / 2;
        switch (std.mem.order(u8, sorted[middle], name)) {
            .lt => low = middle + 1,
            .gt => high = middle,
            .eq => return true,
        }
    }
    return false;
}

/// Compare two sorted name lists by contents, never by slice addresses.
pub fn same(left: []const []const u8, right: []const []const u8) bool {
    if (left.len != right.len) return false;
    for (left, right) |a, b| {
        if (!std.mem.eql(u8, a, b)) return false;
    }
    return true;
}

/// A C identifier: ASCII letters or underscore first, then alphanumerics.
pub fn isValidName(name: []const u8) bool {
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

test "parse extracts sorted names from header comments" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const names = try parse(arena.allocator(), fixture);
    try std.testing.expectEqual(@as(usize, 3), names.len);
    try std.testing.expectEqualStrings("get_godot_version", names[0]);
    try std.testing.expectEqualStrings("mem_alloc", names[1]);
    try std.testing.expectEqualStrings("variant_get_type_by_name", names[2]);
}

test "parse rejects duplicate and malformed names and empty headers" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    try std.testing.expectError(
        error.InvalidInterfaceEvidence,
        parse(a, " * @name twice\n * @name twice\n"),
    );
    try std.testing.expectError(error.InvalidInterfaceEvidence, parse(a, " * @name 1invalid\n"));
    try std.testing.expectError(error.InvalidInterfaceEvidence, parse(a, " * @name bad-name\n"));
    try std.testing.expectError(error.InvalidInterfaceEvidence, parse(a, " * @name\n"));
    try std.testing.expectError(error.InvalidInterfaceEvidence, parse(a, "no tags here\n"));
}

test "canonicalize sorts by bytes and rejects duplicates and invalid names" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const sorted = try canonicalize(a, &.{ "z_name", "Alpha", "_under" });
    try std.testing.expectEqualStrings("Alpha", sorted[0]);
    try std.testing.expectEqualStrings("_under", sorted[1]);
    try std.testing.expectEqualStrings("z_name", sorted[2]);
    try std.testing.expectError(error.InvalidInterfaceEvidence, canonicalize(a, &.{ "same", "same" }));
    try std.testing.expectError(error.InvalidInterfaceEvidence, canonicalize(a, &.{""}));
    try std.testing.expectError(error.InvalidInterfaceEvidence, canonicalize(a, &.{}));
    try std.testing.expectError(error.InvalidInterfaceEvidence, validate(&.{ "b", "a" }));
    try std.testing.expectError(error.InvalidInterfaceEvidence, validate(&.{ "a", "a" }));
}

test "delta is sorted and removed names fail as non-monotonic" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const current = try canonicalize(a, &.{ "alpha", "charlie", "delta" });
    const old = try canonicalize(a, &.{ "alpha" });
    const added = try delta(a, current, old);
    try std.testing.expectEqual(@as(usize, 2), added.len);
    try std.testing.expectEqualStrings("charlie", added[0]);
    try std.testing.expectEqualStrings("delta", added[1]);
    try std.testing.expectEqual(@as(usize, 1), (try delta(a, current, try canonicalize(a, &.{ "alpha", "charlie" }))).len);
    try std.testing.expectError(
        error.NonMonotonicInterfaceEvidence,
        delta(a, try canonicalize(a, &.{"alpha"}), try canonicalize(a, &.{ "alpha", "zulu" })),
    );
}

test "digest is order independent and pins the joined name bytes" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const first = try digest(a, &.{ "beta", "alpha" });
    const second = try digest(a, &.{ "alpha", "beta" });
    try std.testing.expectEqualStrings(first, second);
    // sha256("alpha\nbeta\n")
    try std.testing.expectEqualStrings(
        "e49c81e2d2f84e259d40e2fb8192f3bcd198b355184845d76d8f58807d0d78ee",
        first,
    );
}

test "contains compares contents rather than slice addresses" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const sorted = try canonicalize(a, &.{ "alpha", "charlie" });
    const probe = try a.dupe(u8, "charlie");
    try std.testing.expect(contains(sorted, probe));
    try std.testing.expect(!contains(sorted, "bravo"));
    try std.testing.expect(same(sorted, try canonicalize(a, &.{ "charlie", "alpha" })));
    try std.testing.expect(!same(sorted, try canonicalize(a, &.{"alpha"})));
}

const std = @import("std");
const Allocator = std.mem.Allocator;
