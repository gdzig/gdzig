//! Simple binary protocol for communication between test runner and Godot extension.
//!
//! Message format: [tag: u8][length: u32 little-endian][payload: [length]u8]
//!
//! Messages:
//! - query_test_metadata: no payload → response: test_metadata
//! - test_metadata: [count: u32][names: [count]LengthPrefixedString]
//! - run_test: [index: u32]
//! - test_result: [index: u32][passed: u8][message_len: u32][message: [message_len]u8]
//! - exit: no payload

const std = @import("std");
const Allocator = std.mem.Allocator;
const Io = std.Io;

pub const Tag = enum(u8) {
    query_test_metadata = 1,
    test_metadata = 2,
    run_test = 3,
    test_result = 4,
    exit = 5,
    _,
};

pub const Message = struct {
    tag: Tag,
    payload: []const u8,
};

pub const TestResult = struct {
    index: u32,
    passed: bool,
    message: []const u8,
};

/// Write a message to the stream.
pub fn writeMessage(writer: *Io.Writer, tag: Tag, payload: []const u8) Io.Writer.Error!void {
    try writer.writeByte(@intFromEnum(tag));
    try writer.writeInt(u32, @intCast(payload.len), .little);
    try writer.writeAll(payload);
    try writer.flush();
}

/// Read a message from the stream into the provided buffer.
/// Returns the tag and a slice of the buffer containing the payload.
pub fn readMessage(reader: *Io.Reader, buf: []u8) (Io.Reader.Error || error{PayloadTooLarge})!Message {
    const tag_byte = try reader.takeByte();
    const length = try reader.takeInt(u32, .little);

    if (length > buf.len) {
        return error.PayloadTooLarge;
    }

    const payload = buf[0..length];
    try reader.readSliceAll(payload);

    return .{
        .tag = @enumFromInt(tag_byte),
        .payload = payload,
    };
}

/// Encode test metadata (list of test names) into a payload.
pub fn encodeTestMetadata(allocator: Allocator, names: []const []const u8) Allocator.Error![]u8 {
    // Calculate total size
    var total_size: usize = 4; // count
    for (names) |name| {
        total_size += 4 + name.len; // length prefix + string
    }

    const buf = try allocator.alloc(u8, total_size);
    var pos: usize = 0;

    // Write count
    std.mem.writeInt(u32, buf[pos..][0..4], @intCast(names.len), .little);
    pos += 4;

    // Write each name
    for (names) |name| {
        std.mem.writeInt(u32, buf[pos..][0..4], @intCast(name.len), .little);
        pos += 4;
        @memcpy(buf[pos..][0..name.len], name);
        pos += name.len;
    }

    return buf;
}

/// Iterator for decoding test metadata payload.
pub const TestMetadataIterator = struct {
    data: []const u8,
    pos: usize,
    remaining: u32,

    pub fn init(payload: []const u8) TestMetadataIterator {
        if (payload.len < 4) {
            return .{ .data = payload, .pos = 0, .remaining = 0 };
        }
        const cnt = std.mem.readInt(u32, payload[0..4], .little);
        return .{ .data = payload, .pos = 4, .remaining = cnt };
    }

    pub fn next(self: *TestMetadataIterator) ?[]const u8 {
        if (self.remaining == 0) return null;
        if (self.pos + 4 > self.data.len) return null;

        const len = std.mem.readInt(u32, self.data[self.pos..][0..4], .little);
        self.pos += 4;

        if (self.pos + len > self.data.len) return null;

        const name = self.data[self.pos..][0..len];
        self.pos += len;
        self.remaining -= 1;

        return name;
    }

    pub fn count(self: *const TestMetadataIterator) u32 {
        if (self.data.len < 4) return 0;
        return std.mem.readInt(u32, self.data[0..4], .little);
    }
};

/// Decode test metadata payload into an iterator.
pub fn decodeTestMetadata(payload: []const u8) TestMetadataIterator {
    return TestMetadataIterator.init(payload);
}

/// Encode a run_test message payload.
pub fn encodeRunTest(index: u32) [4]u8 {
    var buf: [4]u8 = undefined;
    std.mem.writeInt(u32, &buf, index, .little);
    return buf;
}

/// Decode a run_test message payload.
pub fn decodeRunTest(payload: []const u8) u32 {
    if (payload.len < 4) return 0;
    return std.mem.readInt(u32, payload[0..4], .little);
}

/// Encode a test_result message payload.
pub fn encodeTestResult(allocator: Allocator, index: u32, passed: bool, message: []const u8) Allocator.Error![]u8 {
    const buf = try allocator.alloc(u8, 4 + 1 + 4 + message.len);
    var pos: usize = 0;

    std.mem.writeInt(u32, buf[pos..][0..4], index, .little);
    pos += 4;

    buf[pos] = if (passed) 1 else 0;
    pos += 1;

    std.mem.writeInt(u32, buf[pos..][0..4], @intCast(message.len), .little);
    pos += 4;

    @memcpy(buf[pos..][0..message.len], message);

    return buf;
}

/// Decode a test_result message payload.
pub fn decodeTestResult(payload: []const u8) TestResult {
    if (payload.len < 9) {
        return .{ .index = 0, .passed = false, .message = "" };
    }

    const index = std.mem.readInt(u32, payload[0..4], .little);
    const passed = payload[4] != 0;
    const msg_len = std.mem.readInt(u32, payload[5..9], .little);

    const message = if (payload.len >= 9 + msg_len)
        payload[9..][0..msg_len]
    else
        "";

    return .{ .index = index, .passed = passed, .message = message };
}

test "encode and decode test metadata" {
    const allocator = std.testing.allocator;

    const names = &[_][]const u8{ "test one", "test two", "test three" };
    const encoded = try encodeTestMetadata(allocator, names);
    defer allocator.free(encoded);

    var iter = decodeTestMetadata(encoded);
    try std.testing.expectEqual(@as(u32, 3), iter.count());
    try std.testing.expectEqualStrings("test one", iter.next().?);
    try std.testing.expectEqualStrings("test two", iter.next().?);
    try std.testing.expectEqualStrings("test three", iter.next().?);
    try std.testing.expectEqual(@as(?[]const u8, null), iter.next());
}

test "encode and decode run_test" {
    const encoded = encodeRunTest(42);
    const decoded = decodeRunTest(&encoded);
    try std.testing.expectEqual(@as(u32, 42), decoded);
}

test "encode and decode test_result" {
    const allocator = std.testing.allocator;

    const encoded = try encodeTestResult(allocator, 5, false, "assertion failed");
    defer allocator.free(encoded);

    const decoded = decodeTestResult(encoded);
    try std.testing.expectEqual(@as(u32, 5), decoded.index);
    try std.testing.expectEqual(false, decoded.passed);
    try std.testing.expectEqualStrings("assertion failed", decoded.message);
}
