//! Minimal command-line arguments: long named options and positionals.
//! Args owns one copy of every token's bytes. Returned slices are valid until deinit.
const Args = @This();

/// Every token's bytes, copied once. All slices below point into it.
bytes: []u8,
/// argv[0].
program: []const u8,
/// Named arguments in command-line order. A bare flag stores null.
named: std.StringArrayHashMapUnmanaged(?[]const u8),
/// Positional arguments in command-line order, excluding argv[0].
positionals: std.ArrayList([]const u8),

pub const ParseError = Allocator.Error || std.process.Args.ToSliceError || error{
    MissingProgramName,
    EmptyName,
    DuplicateArgument,
};

/// Copy and parse the process arguments.
pub fn init(allocator: Allocator, process_args: std.process.Args) ParseError!Args {
    var scratch: std.heap.ArenaAllocator = .init(allocator);
    defer scratch.deinit();
    return initSlice(allocator, try process_args.toSlice(scratch.allocator()));
}

/// Copy and parse explicit argv, including its program name.
pub fn initSlice(allocator: Allocator, argv: []const []const u8) ParseError!Args {
    // Reserve one backing buffer before building either index.
    if (argv.len == 0) return error.MissingProgramName;
    var total: usize = 0;
    for (argv) |token| total = std.math.add(usize, total, token.len) catch return error.OutOfMemory;
    var args: Args = .{ .bytes = try allocator.alloc(u8, total), .program = undefined, .named = .empty, .positionals = .empty };
    errdefer args.deinit(allocator);

    // Copy each token once, then classify slices into the owned buffer.
    var rest = args.bytes;
    var positional_only = false;
    for (argv, 0..) |original, index| {
        const token = rest[0..original.len];
        @memcpy(token, original);
        rest = rest[original.len..];
        if (index == 0) {
            args.program = token;
            continue;
        }

        // Preserve positional order, including named-looking text after --.
        if (positional_only or !std.mem.startsWith(u8, token, "--")) {
            try args.positionals.append(allocator, token);
            continue;
        }
        if (std.mem.eql(u8, token, "--")) {
            positional_only = true;
            continue;
        }

        // Split named values at the first equals and reject duplicate names.
        const body = token[2..];
        const equals = std.mem.indexOfScalar(u8, body, '=');
        const name = body[0 .. equals orelse body.len];
        if (name.len == 0) return error.EmptyName;
        const entry = try args.named.getOrPut(allocator, name);
        if (entry.found_existing) return error.DuplicateArgument;
        entry.value_ptr.* = if (equals) |offset| body[offset + 1 ..] else null;
    }
    return args;
}

/// Free the byte buffer and both indexes using the original allocator.
pub fn deinit(self: *Args, allocator: Allocator) void {
    allocator.free(self.bytes);
    self.named.deinit(allocator);
    self.positionals.deinit(allocator);
    self.* = undefined;
}

/// Return a named value or null when absent, rejecting bare flags.
pub fn value(self: Args, name: []const u8) error{MissingValue}!?[]const u8 {
    const stored = self.named.get(name) orelse return null;
    return stored orelse error.MissingValue;
}

/// Value of a required --name=value; absent, bare and empty values are missing.
pub fn required(self: Args, name: []const u8) error{MissingArgument}![]const u8 {
    const text = self.value(name) catch return error.MissingArgument;
    const present = text orelse return error.MissingArgument;
    if (present.len == 0) return error.MissingArgument;
    return present;
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

fn expectInside(bytes: []const u8, text: []const u8) !void {
    try testing.expect(@intFromPtr(text.ptr) >= @intFromPtr(bytes.ptr));
    try testing.expect(@intFromPtr(text.ptr) + text.len <= @intFromPtr(bytes.ptr) + bytes.len);
}

test "equals values flags terminator and positionals parse inline" {
    for ([_][]const u8{ "--a=b", "--a", "--a=", "--a=b=c" }, [_]?[]const u8{ "b", null, "", "b=c" }) |text, expected| {
        var args: Args = try .initSlice(testing.allocator, &.{ "tool", text });
        defer args.deinit(testing.allocator);
        try testing.expectEqualStrings("a", args.named.keys()[0]);
        if (expected) |value_text| {
            try testing.expectEqualStrings(value_text, (try args.value("a")).?);
        } else try testing.expect(try args.flag("a"));
    }
    var args: Args = try .initSlice(testing.allocator, &.{ "tool", "-x", "-", "x", "--", "--a=b" });
    defer args.deinit(testing.allocator);
    for ([_][]const u8{ "-x", "-", "x", "--a=b" }, args.positionals.items) |expected, actual| {
        try testing.expectEqualStrings(expected, actual);
    }
    try testing.expectError(error.EmptyName, initSlice(testing.allocator, &.{ "tool", "--=x" }));
}

test "owned arguments preserve command order and query semantics" {
    var args: Args = try .initSlice(testing.allocator, &.{ "tool", "first", "--x=", "second", "--flag", "--", "--literal" });
    defer args.deinit(testing.allocator);
    try testing.expectEqualStrings("tool", args.program);
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

test "one exact byte buffer backs every returned slice" {
    const argv: []const []const u8 = &.{ "tool", "", "--x=value", "--empty=", "--flag", "--", "--literal" };
    var args: Args = try .initSlice(testing.allocator, argv);
    defer args.deinit(testing.allocator);
    var total: usize = 0;
    for (argv) |token| total += token.len;
    try testing.expectEqual(total, args.bytes.len);
    try expectInside(args.bytes, args.program);
    for (args.named.keys(), args.named.values()) |name, stored| {
        try expectInside(args.bytes, name);
        if (stored) |text| try expectInside(args.bytes, text);
    }
    for (args.positionals.items) |text| try expectInside(args.bytes, text);
}

test "required returns MissingArgument or a slice in the owned buffer" {
    for ([_][]const []const u8{ &.{"tool"}, &.{ "tool", "--output" }, &.{ "tool", "--output=" } }) |argv| {
        var args: Args = try .initSlice(testing.allocator, argv);
        defer args.deinit(testing.allocator);
        try testing.expectError(error.MissingArgument, args.required("output"));
    }
    var args: Args = try .initSlice(testing.allocator, &.{ "tool", "--output=bindings" });
    defer args.deinit(testing.allocator);
    const output = try args.required("output");
    try testing.expectEqualStrings("bindings", output);
    try expectInside(args.bytes, output);
}

const std = @import("std");
const Allocator = std.mem.Allocator;
const testing = std.testing;
