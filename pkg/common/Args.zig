//! Minimal command-line arguments: long named options and positionals.
//! Args owns one copy of every token's bytes. Returned slices are valid until deinit.
const Args = @This();

/// Every token's bytes, copied once. All slices below point into it.
bytes: []u8,
/// argv[0].
program: []const u8,
/// Named arguments keyed by name, in command-line order.
named: std.StringArrayHashMapUnmanaged(Named),
/// Positional values in order. Reading this directly does not count as consuming.
positionals: std.ArrayList([]const u8),
/// Number of positionals consumed by positional.
positional_cursor: usize = 0,

const Named = struct {
    value: ?[]const u8,
    used: bool = false,
};

pub const ParseError = Allocator.Error || std.process.Args.ToSliceError || error{
    MissingProgramName,
    EmptyName,
    DuplicateArgument,
};

pub const ValueError = error{ MissingValue, InvalidValue };

pub const Reject = struct {
    /// Fail if any named argument was never read by a query.
    unused_named: bool = false,
    /// Fail if any positional was never read by positional.
    unused_positionals: bool = false,

    pub const named: Reject = .{ .unused_named = true };
    pub const positionals: Reject = .{ .unused_positionals = true };
    pub const strict: Reject = .{ .unused_named = true, .unused_positionals = true };
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
    var args: Args = .{
        .bytes = try allocator.alloc(u8, total),
        .program = undefined,
        .named = .empty,
        .positionals = .empty,
    };
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
        entry.value_ptr.* = .{ .value = if (equals) |offset| body[offset + 1 ..] else null };
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

/// Parse --name=value as T, or null when absent. Marks the argument as used.
pub fn optional(self: *Args, comptime T: type, name: []const u8) ValueError!?T {
    const entry = self.named.getPtr(name) orelse return null;
    entry.used = true;
    const text = entry.value orelse {
        if (T == bool) return true;
        return error.MissingValue;
    };
    return try parseValue(T, text);
}

/// Parse a required named argument. Absent or an empty string is MissingArgument.
pub fn required(self: *Args, comptime T: type, name: []const u8) (ValueError || error{MissingArgument})!T {
    const value = (try self.optional(T, name)) orelse return error.MissingArgument;
    if (T == []const u8) {
        if (value.len == 0) return error.MissingArgument;
    }
    return value;
}

/// Parse the next unread positional as T, or null when none remain. Advances the cursor.
pub fn positional(self: *Args, comptime T: type) error{InvalidValue}!?T {
    if (self.positional_cursor == self.positionals.items.len) return null;
    const text = self.positionals.items[self.positional_cursor];
    self.positional_cursor += 1;
    return try parseValue(T, text);
}

/// Check the command line after the last query.
pub fn reject(self: Args, options: Reject) error{ UnusedArgument, UnusedPositional }!void {
    if (options.unused_named) {
        for (self.named.values()) |entry| {
            if (!entry.used) return error.UnusedArgument;
        }
    }
    if (options.unused_positionals and self.positional_cursor < self.positionals.items.len) return error.UnusedPositional;
}

fn parseValue(comptime T: type, text: []const u8) error{InvalidValue}!T {
    if (T == []const u8) return text;
    return switch (@typeInfo(T)) {
        .@"enum" => std.meta.stringToEnum(T, text) orelse error.InvalidValue,
        .int => std.fmt.parseInt(T, text, 10) catch error.InvalidValue,
        .float => std.fmt.parseFloat(T, text) catch error.InvalidValue,
        .bool => if (std.mem.eql(u8, text, "true")) true else if (std.mem.eql(u8, text, "false")) false else error.InvalidValue,
        else => @compileError("Args queries support strings, enums, integers, floats and bools"),
    };
}

fn allocationPaths(allocator: Allocator) !void {
    var args: Args = try .initSlice(allocator, &.{ "tool", "one", "--x=value", "--flag", "--", "--literal" });
    defer args.deinit(allocator);
    try testing.expectEqualStrings("value", (try args.optional([]const u8, "x")).?);
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

fn expectConversion(comptime T: type, text: []const u8, expected: ?T) !void {
    var args: Args = try .initSlice(testing.allocator, &.{ "tool", text });
    defer args.deinit(testing.allocator);
    if (expected) |value| {
        try testing.expectEqual(value, try args.required(T, "x"));
    } else try testing.expectError(error.InvalidValue, args.required(T, "x"));
    try args.reject(.strict);
}

test "equals values flags terminator and positionals parse inline" {
    for ([_][]const u8{ "--a=b", "--a", "--a=", "--a=b=c" }, [_]?[]const u8{ "b", null, "", "b=c" }) |text, expected| {
        var args: Args = try .initSlice(testing.allocator, &.{ "tool", text });
        defer args.deinit(testing.allocator);
        try testing.expectEqualStrings("a", args.named.keys()[0]);
        if (expected) |value_text| {
            try testing.expectEqualStrings(value_text, (try args.optional([]const u8, "a")).?);
        } else try testing.expect(try args.required(bool, "a"));
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
    try testing.expectEqualStrings("", (try args.optional([]const u8, "x")).?);
    try testing.expectEqual(@as(?[]const u8, null), try args.optional([]const u8, "absent"));
    try testing.expectError(error.MissingValue, args.optional([]const u8, "flag"));
    try testing.expect(try args.required(bool, "flag"));
    try testing.expectEqual(@as(?bool, null), try args.optional(bool, "absent"));
    try args.reject(.named);
    try testing.expectError(error.UnusedPositional, args.reject(.positionals));
    try args.reject(.{});
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
    try testing.expectEqualStrings("value", (try args.optional([]const u8, "x")).?);
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
        if (stored.value) |text| try expectInside(args.bytes, text);
    }
    for (args.positionals.items) |text| try expectInside(args.bytes, text);
}

test "optional and required distinguish absent bare and empty values" {
    var args: Args = try .initSlice(testing.allocator, &.{ "tool", "--bare", "--empty=", "--output=bindings" });
    defer args.deinit(testing.allocator);
    try testing.expectEqual(@as(?[]const u8, null), try args.optional([]const u8, "absent"));
    try testing.expectError(error.MissingArgument, args.required([]const u8, "absent"));
    try testing.expectError(error.MissingValue, args.required([]const u8, "bare"));
    try testing.expectError(error.MissingArgument, args.required([]const u8, "empty"));
    try testing.expectEqualStrings("", (try args.optional([]const u8, "empty")).?);
    const output = try args.required([]const u8, "output");
    try testing.expectEqualStrings("bindings", output);
    try expectInside(args.bytes, output);
    try args.reject(.strict);
}

test "typed conversions validate enums numeric ranges floats and bools" {
    const Mode = enum { quiet, verbose };
    try expectConversion(Mode, "--x=quiet", .quiet);
    try expectConversion(Mode, "--x=other", null);
    try expectConversion(i32, "--x=-42", -42);
    try expectConversion(i32, "--x=2147483648", null);
    try expectConversion(u16, "--x=65535", 65535);
    try expectConversion(u16, "--x=65536", null);
    try expectConversion(u16, "--x=-1", null);
    try expectConversion(f32, "--x=1.25", 1.25);
    try expectConversion(f32, "--x=wrong", null);
    try expectConversion(bool, "--x=true", true);
    try expectConversion(bool, "--x=false", false);
    try expectConversion(bool, "--x", true);
    try expectConversion(bool, "--x=yes", null);
    try expectConversion(bool, "--x=", null);
    inline for ([_]type{ Mode, i32, f32 }) |T| {
        var args: Args = try .initSlice(testing.allocator, &.{ "tool", "--x" });
        defer args.deinit(testing.allocator);
        try testing.expectError(error.MissingValue, args.optional(T, "x"));
        try args.reject(.named);
    }
}

test "typed queries mark named values and consume positionals even on errors" {
    var args: Args = try .initSlice(testing.allocator, &.{ "tool", "--number=42", "--enabled", "7", "false", "wrong", "yes" });
    defer args.deinit(testing.allocator);
    try testing.expectError(error.UnusedArgument, args.reject(.strict));
    try testing.expectEqual(@as(?u16, 42), try args.optional(u16, "number"));
    try testing.expectError(error.UnusedArgument, args.reject(.named));
    try testing.expect(try args.required(bool, "enabled"));
    try args.reject(.named);
    try testing.expectError(error.UnusedPositional, args.reject(.strict));
    try testing.expectEqual(@as(?u32, 7), try args.positional(u32));
    try testing.expectEqual(@as(?bool, false), try args.positional(bool));
    try testing.expectError(error.InvalidValue, args.positional(u32));
    try testing.expectError(error.InvalidValue, args.positional(bool));
    try testing.expectEqual(@as(?bool, null), try args.positional(bool));
    try args.reject(.strict);
}

const std = @import("std");
const Allocator = std.mem.Allocator;
const testing = std.testing;
