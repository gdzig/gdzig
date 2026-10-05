//! Owned command-line tokens with long named options and positional values.
//! Returned slices remain valid until deinit.
const Args = @This();

/// Owned tokens, with argv[0] first, backing every slice in the indexes.
tokens: []const []const u8,
/// Named arguments in command-line order. A bare flag stores null.
named: std.StringArrayHashMapUnmanaged(?[]const u8),
/// Positional arguments in command-line order, excluding argv[0].
positionals: std.ArrayList([]const u8),

pub const NamedArgument = struct {
    name: []const u8,
    value: ?[]const u8 = null,
};

pub const Token = union(enum) {
    named: NamedArgument,
    positional: []const u8,
    end_of_named,
};

pub const ParseError = Allocator.Error || std.process.Args.Iterator.InitError || error{
    MissingProgramName,
    EmptyName,
    DuplicateArgument,
};

/// Classify one token, splitting named values at the first equals sign.
pub fn classify(token: []const u8) error{EmptyName}!Token {
    if (std.mem.eql(u8, token, "--")) return .end_of_named;
    if (!std.mem.startsWith(u8, token, "--")) return .{ .positional = token };
    const body = token[2..];
    const equals = std.mem.indexOfScalar(u8, body, '=');
    const name = body[0 .. equals orelse body.len];
    if (name.len == 0) return error.EmptyName;
    return .{ .named = .{
        .name = name,
        .value = if (equals) |index| body[index + 1 ..] else null,
    } };
}

/// Copy and parse process arguments using the cross-platform iterator.
pub fn init(allocator: Allocator, process_args: std.process.Args) ParseError!Args {
    var iterator: std.process.Args.Iterator = try process_args.iterateAllocator(allocator);
    defer iterator.deinit();
    var tokens: std.ArrayList([]const u8) = .empty;
    errdefer freeTokens(allocator, &tokens);
    while (iterator.next()) |token| try copyToken(allocator, &tokens, token);
    return parseOwned(allocator, try tokens.toOwnedSlice(allocator));
}

/// Copy and parse explicit argv, including its program name.
pub fn initSlice(allocator: Allocator, argv: []const []const u8) ParseError!Args {
    var tokens: std.ArrayList([]const u8) = .empty;
    errdefer freeTokens(allocator, &tokens);
    for (argv) |token| try copyToken(allocator, &tokens, token);
    return parseOwned(allocator, try tokens.toOwnedSlice(allocator));
}

/// Free owned tokens and both indexes using the original allocator.
pub fn deinit(self: *Args, allocator: Allocator) void {
    for (self.tokens) |token| allocator.free(token);
    allocator.free(self.tokens);
    self.named.deinit(allocator);
    self.positionals.deinit(allocator);
    self.* = undefined;
}

/// Return argv[0], which is not included in positional values.
pub fn program(self: Args) []const u8 {
    return self.tokens[0];
}

/// Return a named value or null when absent, rejecting bare flags.
pub fn value(self: Args, name: []const u8) error{MissingValue}!?[]const u8 {
    const stored = self.named.get(name) orelse return null;
    return stored orelse error.MissingValue;
}

/// Return whether a bare flag is present, rejecting arguments with values.
pub fn flag(self: Args, name: []const u8) error{UnexpectedValue}!bool {
    const stored = self.named.get(name) orelse return false;
    if (stored != null) return error.UnexpectedValue;
    return true;
}

/// Reject the first unknown name in command-line order.
pub fn rejectUnknown(self: Args, known: []const []const u8) error{UnknownArgument}!void {
    for (self.named.keys()) |name| {
        for (known) |allowed| {
            if (std.mem.eql(u8, name, allowed)) break;
        } else {
            return error.UnknownArgument;
        }
    }
}

fn parseOwned(allocator: Allocator, tokens: []const []const u8) ParseError!Args {
    var args: Args = .{ .tokens = tokens, .named = .empty, .positionals = .empty };
    errdefer args.deinit(allocator);
    if (tokens.len == 0) return error.MissingProgramName;
    var positional_only = false;
    for (tokens[1..]) |token| {
        const classified = if (positional_only) Token{ .positional = token } else try classify(token);
        switch (classified) {
            .positional => |text| try args.positionals.append(allocator, text),
            .end_of_named => positional_only = true,
            .named => |named| {
                const entry = try args.named.getOrPut(allocator, named.name);
                if (entry.found_existing) {
                    return error.DuplicateArgument;
                }
                entry.value_ptr.* = named.value;
            },
        }
    }
    return args;
}

fn copyToken(allocator: Allocator, tokens: *std.ArrayList([]const u8), token: []const u8) !void {
    const copy = try allocator.dupe(u8, token);
    errdefer allocator.free(copy);
    try tokens.append(allocator, copy);
}

fn freeTokens(allocator: Allocator, tokens: *std.ArrayList([]const u8)) void {
    for (tokens.items) |token| allocator.free(token);
    tokens.deinit(allocator);
}

fn allocationPaths(allocator: Allocator) !void {
    var args: Args = try .initSlice(allocator, &.{ "tool", "one", "--x=value", "--flag", "--", "--literal" });
    defer args.deinit(allocator);
    try testing.expectEqualStrings("value", (try args.value("x")).?);
}

fn failedAllocationPath(allocator: Allocator, argv: []const []const u8, expected: anyerror) !void {
    var args = initSlice(allocator, argv) catch |err| {
        if (err == error.OutOfMemory) return err;
        try testing.expectEqual(expected, err);
        return;
    };
    defer args.deinit(allocator);
    return error.TestUnexpectedResult;
}

test "classify equals values flags terminator and positionals" {
    for ([_][]const u8{ "--a=b", "--a", "--a=", "--a=b=c" }, [_]?[]const u8{ "b", null, "", "b=c" }) |text, expected| {
        const token = try classify(text);
        try testing.expectEqualStrings("a", token.named.name);
        if (expected) |value_text| {
            try testing.expectEqualStrings(value_text, token.named.value.?);
        } else try testing.expectEqual(@as(?[]const u8, null), token.named.value);
    }
    try testing.expectEqual(Token.end_of_named, try classify("--"));
    for ([_][]const u8{ "-x", "-", "x" }) |text| {
        try testing.expectEqualStrings(text, (try classify(text)).positional);
    }
    try testing.expectError(error.EmptyName, classify("--=x"));
}

test "owned arguments preserve command order and query semantics" {
    var args: Args = try .initSlice(testing.allocator, &.{ "tool", "first", "--x=", "second", "--flag", "--", "--literal" });
    defer args.deinit(testing.allocator);
    try testing.expectEqualStrings("tool", args.program());
    for ([_][]const u8{ "x", "flag" }, args.named.keys()) |expected, actual| {
        try testing.expectEqualStrings(expected, actual);
    }
    try testing.expectEqual(@as(usize, 3), args.positionals.items.len);
    try testing.expectEqualStrings("first", args.positionals.items[0]);
    try testing.expectEqualStrings("second", args.positionals.items[1]);
    try testing.expectEqualStrings("--literal", args.positionals.items[2]);
    try testing.expectEqualStrings("", (try args.value("x")).?);
    try testing.expectEqual(@as(?[]const u8, null), try args.value("absent"));
    try testing.expectError(error.MissingValue, args.value("flag"));
    try testing.expect(try args.flag("flag"));
    try testing.expect(!try args.flag("absent"));
    try testing.expectError(error.UnexpectedValue, args.flag("x"));
    try args.rejectUnknown(&.{ "x", "flag" });
    try testing.expectError(error.UnknownArgument, args.rejectUnknown(&.{}));
}

test "duplicate empty names and missing program return errors" {
    try testing.expectError(error.DuplicateArgument, initSlice(testing.allocator, &.{ "tool", "--x=one", "--x=two" }));
    try testing.expectError(error.EmptyName, initSlice(testing.allocator, &.{ "tool", "--=x" }));
    try testing.expectError(error.MissingProgramName, initSlice(testing.allocator, &.{}));
}

test "argument copies outlive overwritten input and allocation failures leak nothing" {
    var text = "--x=value".*;
    var args: Args = try .initSlice(testing.allocator, &.{ "tool", &text });
    defer args.deinit(testing.allocator);
    @memset(&text, 'z');
    try testing.expectEqualStrings("value", (try args.value("x")).?);
    try testing.checkAllAllocationFailures(testing.allocator, allocationPaths, .{});
    try testing.checkAllAllocationFailures(testing.allocator, failedAllocationPath, .{
        &.{ "tool", "--x=one", "--x=two" }, error.DuplicateArgument,
    });
    try testing.checkAllAllocationFailures(testing.allocator, failedAllocationPath, .{
        &.{ "tool", "--=x" }, error.EmptyName,
    });
}

const std = @import("std");
const Allocator = std.mem.Allocator;
const testing = std.testing;
