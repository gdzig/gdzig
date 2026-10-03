//! JSON-based IPC protocol for test communication.
//!
//! Uses newline-delimited JSON over stdin/stdout. Messages are identified
//! by the presence of `"__gdzig__": "test_ipc"` field, allowing Godot's
//! normal output to be filtered out.
//!
//! Commands (coordinator -> extension via stdin):
//! - {"__gdzig__":"test_ipc","cmd":"query_metadata"}
//! - {"__gdzig__":"test_ipc","cmd":"run_test","index":5}
//! - {"__gdzig__":"test_ipc","cmd":"exit"}
//!
//! Responses (extension -> coordinator via stdout):
//! - {"__gdzig__":"test_ipc","type":"metadata","tests":["test_one","test_two"]}
//! - {"__gdzig__":"test_ipc","type":"result","index":5,"status":"pass"}
//! - {"__gdzig__":"test_ipc","type":"result","index":5,"status":"fail","message":"error details"}
//! - {"__gdzig__":"test_ipc","type":"result","index":5,"status":"skip"}
//!
//! This is a private contract between the co-built harness and coordinator.
//! Legacy boolean result fields are not supported.

const MARKER = "test_ipc";

/// Write a JSON-encoded string (with quotes and escaping)
fn writeJsonString(writer: anytype, s: []const u8) !void {
    try writer.writeByte('"');
    for (s) |c| {
        switch (c) {
            '"' => try writer.writeAll("\\\""),
            '\\' => try writer.writeAll("\\\\"),
            '\n' => try writer.writeAll("\\n"),
            '\r' => try writer.writeAll("\\r"),
            '\t' => try writer.writeAll("\\t"),
            else => {
                if (c < 0x20) {
                    // Control character - encode as \u00XX
                    try writer.writeAll("\\u00");
                    const hex = "0123456789abcdef";
                    try writer.writeByte(hex[c >> 4]);
                    try writer.writeByte(hex[c & 0xf]);
                } else {
                    try writer.writeByte(c);
                }
            },
        }
    }
    try writer.writeByte('"');
}

pub const Command = union(enum) {
    query_metadata,
    run_test: u32,
    exit,
};

pub const Response = union(enum) {
    metadata: []const []const u8,
    result: TestResult,
};

pub const TestStatus = enum { pass, fail, skip };

pub const TestResult = struct {
    index: u32,
    status: TestStatus,
    message: ?[]const u8 = null,
};

/// Check if a line is a gdzig IPC message.
pub fn isIpcMessage(line: []const u8) bool {
    // Quick check before parsing
    return std.mem.indexOf(u8, line, "\"__gdzig__\"") != null and
        std.mem.indexOf(u8, line, MARKER) != null;
}

/// Parse a command from a JSON line.
pub fn parseCommand(line: []const u8) ?Command {
    const parsed = std.json.parseFromSlice(std.json.Value, std.heap.page_allocator, line, .{}) catch return null;
    defer parsed.deinit();

    const root = parsed.value.object;

    // Verify marker
    const marker = root.get("__gdzig__") orelse return null;
    if (marker != .string or !std.mem.eql(u8, marker.string, MARKER)) return null;

    // Get command
    const cmd = root.get("cmd") orelse return null;
    if (cmd != .string) return null;

    if (std.mem.eql(u8, cmd.string, "query_metadata")) {
        return .query_metadata;
    } else if (std.mem.eql(u8, cmd.string, "run_test")) {
        const index = root.get("index") orelse return null;
        if (index != .integer) return null;
        return .{ .run_test = @intCast(index.integer) };
    } else if (std.mem.eql(u8, cmd.string, "exit")) {
        return .exit;
    }

    return null;
}

/// Parse a response from a JSON line. Caller must free returned slices.
pub fn parseResponse(allocator: std.mem.Allocator, line: []const u8) !?Response {
    const parsed = std.json.parseFromSlice(std.json.Value, allocator, line, .{}) catch return null;
    defer parsed.deinit();

    const root = parsed.value.object;

    // Verify marker
    const marker = root.get("__gdzig__") orelse return null;
    if (marker != .string or !std.mem.eql(u8, marker.string, MARKER)) return null;

    // Get type
    const msg_type = root.get("type") orelse return null;
    if (msg_type != .string) return null;

    if (std.mem.eql(u8, msg_type.string, "metadata")) {
        const tests_val = root.get("tests") orelse return null;
        if (tests_val != .array) return null;

        var tests: std.ArrayListUnmanaged([]const u8) = .empty;
        errdefer {
            for (tests.items) |t| allocator.free(t);
            tests.deinit(allocator);
        }

        for (tests_val.array.items) |item| {
            if (item != .string) continue;
            try tests.append(allocator, try allocator.dupe(u8, item.string));
        }

        return .{ .metadata = try tests.toOwnedSlice(allocator) };
    } else if (std.mem.eql(u8, msg_type.string, "result")) {
        const index_val = root.get("index") orelse return null;
        if (index_val != .integer) return null;

        const status_val = root.get("status") orelse return null;
        if (status_val != .string) return null;
        const status = std.meta.stringToEnum(TestStatus, status_val.string) orelse return null;

        var message: ?[]const u8 = null;
        if (root.get("message")) |msg_val| {
            if (msg_val == .string) {
                message = try allocator.dupe(u8, msg_val.string);
            }
        }

        return .{ .result = .{
            .index = @intCast(index_val.integer),
            .status = status,
            .message = message,
        } };
    }

    return null;
}

/// Free a parsed response.
pub fn freeResponse(allocator: std.mem.Allocator, response: *Response) void {
    switch (response.*) {
        .metadata => |tests| {
            for (tests) |t| allocator.free(t);
            allocator.free(tests);
        },
        .result => |*r| {
            if (r.message) |m| allocator.free(m);
        },
    }
}

/// Write a command as JSON to a writer.
pub fn writeCommand(writer: anytype, cmd: Command) !void {
    try writer.writeAll("{\"__gdzig__\":\"");
    try writer.writeAll(MARKER);
    try writer.writeAll("\",\"cmd\":\"");

    switch (cmd) {
        .query_metadata => try writer.writeAll("query_metadata\"}"),
        .run_test => |index| {
            try writer.writeAll("run_test\",\"index\":");
            var num_buf: [16]u8 = undefined;
            const num_str = std.fmt.bufPrint(&num_buf, "{d}", .{index}) catch unreachable;
            try writer.writeAll(num_str);
            try writer.writeAll("}");
        },
        .exit => try writer.writeAll("exit\"}"),
    }
    try writer.writeAll("\n");
}

/// Write a metadata response as JSON to a writer.
pub fn writeMetadataResponse(writer: anytype, tests: []const []const u8) !void {
    try writer.writeAll("{\"__gdzig__\":\"");
    try writer.writeAll(MARKER);
    try writer.writeAll("\",\"type\":\"metadata\",\"tests\":[");

    for (tests, 0..) |name, i| {
        if (i > 0) try writer.writeAll(",");
        try writeJsonString(writer, name);
    }

    try writer.writeAll("]}\n");
}

/// Write a test result response as JSON to a writer.
pub fn writeResultResponse(writer: anytype, result: TestResult) !void {
    try writer.writeAll("{\"__gdzig__\":\"");
    try writer.writeAll(MARKER);
    try writer.writeAll("\",\"type\":\"result\",\"index\":");
    var num_buf: [16]u8 = undefined;
    const num_str = std.fmt.bufPrint(&num_buf, "{d}", .{result.index}) catch unreachable;
    try writer.writeAll(num_str);
    try writer.writeAll(",\"status\":");
    try writeJsonString(writer, @tagName(result.status));

    if (result.message) |msg| {
        try writer.writeAll(",\"message\":");
        try writeJsonString(writer, msg);
    }

    try writer.writeAll("}\n");
}

test "pass fail and skip survive IPC serialization" {
    for ([_]TestStatus{ .pass, .fail, .skip }) |status| {
        var output: std.Io.Writer.Allocating = .init(std.testing.allocator);
        defer output.deinit();
        try writeResultResponse(&output.writer, .{ .index = 5, .status = status });
        var response = (try parseResponse(std.testing.allocator, output.written())).?;
        defer freeResponse(std.testing.allocator, &response);
        try std.testing.expect(response == .result);
        try std.testing.expectEqual(@as(u32, 5), response.result.index);
        try std.testing.expectEqual(status, response.result.status);
        try std.testing.expectEqual(null, response.result.message);
    }
}

test "result status is required and rejects unknown or legacy representations" {
    const invalid_fields = [_][]const u8{
        "",
        ",\"status\":\"unknown\"",
        ",\"status\":true",
        ",\"status\":0",
        ",\"status\":null",
        ",\"passed\":true",
        ",\"passed\":true,\"skipped\":true",
    };
    for (invalid_fields) |fields| {
        const line = try std.fmt.allocPrint(std.testing.allocator, "{{\"__gdzig__\":\"test_ipc\",\"type\":\"result\",\"index\":5{s}}}", .{fields});
        defer std.testing.allocator.free(line);
        var response = try parseResponse(std.testing.allocator, line);
        defer if (response) |*value| freeResponse(std.testing.allocator, value);
        try std.testing.expect(response == null);
    }
}

test "failure diagnostics survive IPC serialization" {
    for ([_][]const u8{ "Test index out of bounds", "details: \"quoted\"\\\n\r\t\x01" }) |message| {
        var output: std.Io.Writer.Allocating = .init(std.testing.allocator);
        defer output.deinit();
        try writeResultResponse(&output.writer, .{
            .index = std.math.maxInt(u32),
            .status = .fail,
            .message = message,
        });
        var response = (try parseResponse(std.testing.allocator, output.written())).?;
        defer freeResponse(std.testing.allocator, &response);
        try std.testing.expect(response == .result);
        try std.testing.expectEqual(std.math.maxInt(u32), response.result.index);
        try std.testing.expectEqual(TestStatus.fail, response.result.status);
        try std.testing.expectEqualStrings(message, response.result.message.?);
    }
}

test "parse query_metadata command" {
    const cmd = parseCommand("{\"__gdzig__\":\"test_ipc\",\"cmd\":\"query_metadata\"}");
    try std.testing.expect(cmd != null);
    try std.testing.expect(cmd.? == .query_metadata);
}

test "parse run_test command" {
    const cmd = parseCommand("{\"__gdzig__\":\"test_ipc\",\"cmd\":\"run_test\",\"index\":42}");
    try std.testing.expect(cmd != null);
    try std.testing.expectEqual(@as(u32, 42), cmd.?.run_test);
}

test "parse exit command" {
    const cmd = parseCommand("{\"__gdzig__\":\"test_ipc\",\"cmd\":\"exit\"}");
    try std.testing.expect(cmd != null);
    try std.testing.expect(cmd.? == .exit);
}

test "reject non-ipc json" {
    const cmd = parseCommand("{\"some\":\"other json\"}");
    try std.testing.expect(cmd == null);
}

test "reject godot output" {
    try std.testing.expect(!isIpcMessage("Godot Engine v4.2.1"));
    try std.testing.expect(!isIpcMessage("Loading project..."));
    try std.testing.expect(!isIpcMessage(""));
}

test "accept ipc messages" {
    try std.testing.expect(isIpcMessage("{\"__gdzig__\":\"test_ipc\",\"cmd\":\"exit\"}"));
}

const std = @import("std");
