pub fn ArrayListWriter(comptime T: type) type {
    return CodeWriter(std.ArrayList(T).Writer);
}

pub const AnyWriter = CodeWriter(std.io.AnyWriter);

pub fn codeWriter(inner: anytype) CodeWriter(@TypeOf(inner)) {
    return .{ .inner = inner };
}

/// A writer that tracks indentation level, and commenting state.
pub fn CodeWriter(comptime W: type) type {
    return struct {
        const Self = @This();
        const Error = W.Error;

        inner: W,
        indent: usize = 0,
        at_line_start: bool = true,

        comment: enum { off, on, doc } = .off,

        pub fn write(self: *Self, data: []const u8) Error!usize {
            var written: usize = 0;

            for (data) |byte| {
                // Add indentation at start of line (but not for empty lines)
                if (self.at_line_start) {
                    if (byte != '\n') for (0..self.indent) |_| {
                        try self.inner.writeByteNTimes(' ', 4);
                    };

                    _ = switch (self.comment) {
                        .on => try self.inner.write("// "),
                        .doc => try self.inner.write("/// "),
                        else => {},
                    };

                    self.at_line_start = false;
                }

                // Write the byte
                _ = try self.inner.writeByte(byte);
                written += 1;

                // Track if we're at the start of the next line
                if (byte == '\n') {
                    self.at_line_start = true;
                }
            }

            return written;
        }

        pub fn writeLine(self: *Self, bytes: []const u8) Error!void {
            _ = try self.write(bytes);
            _ = try self.write("\n");
        }

        pub inline fn writeAll(self: *Self, bytes: []const u8) Error!void {
            return self.writer().writeAll(bytes);
        }

        pub inline fn writeAllLine(self: *Self, bytes: []const u8) Error!void {
            try self.writeAll(bytes);
            try self.writeAll("\n");
        }

        pub inline fn print(self: *Self, comptime format: []const u8, args: anytype) Error!void {
            return self.writer().print(format, args);
        }

        pub inline fn printLine(self: *Self, comptime format: []const u8, args: anytype) Error!void {
            try self.print(format, args);
            _ = try self.write("\n");
        }

        pub inline fn writeByte(self: *Self, byte: u8) Error!void {
            return self.writer().writeByte(byte);
        }

        pub inline fn writeByteNTimes(self: *Self, byte: u8, n: usize) Error!void {
            return self.writer().writeByteNTimes(byte, n);
        }

        pub inline fn writeBytesNTimes(self: *Self, bytes: []const u8, n: usize) Error!void {
            return self.writer().writeBytesNTimes(bytes, n);
        }

        pub inline fn writeInt(self: *Self, comptime T: type, value: T, endian: std.builtin.Endian) Error!void {
            return self.writer().writeInt(T, value, endian);
        }

        pub inline fn writeStruct(self: *Self, value: anytype) Error!void {
            return self.writer().writeStruct(value);
        }

        pub inline fn writeStructEndian(self: Self, value: anytype, endian: std.builtin.Endian) Error!void {
            return self.writer().writeStructEndian(value, endian);
        }

        pub fn writer(self: *Self) std.io.Writer(*Self, Error, write) {
            return .{ .context = self };
        }
    };
}

const std = @import("std");
const testing = std.testing;

test "indents" {
    var list = std.ArrayList(u8).init(testing.allocator);
    defer list.deinit();

    var w = codeWriter(list.writer());

    try w.writeAll("Hello\nHello\nHello\n");
    w.indent += 1;
    try w.writeAll("Hello\nHello\nHello\n");
    w.indent += 1;
    w.comment = .on;
    try w.writeAll("Hello\nHello\nHello\n");
    w.comment = .doc;
    w.indent -= 1;
    try w.writeAll("Hello\nHello\nHello\n");
    w.comment = .off;
    w.indent -= 1;
    try w.writeAll("Hello\nHello\nHello\n");

    try testing.expectEqualStrings(
        \\Hello
        \\Hello
        \\Hello
        \\    Hello
        \\    Hello
        \\    Hello
        \\        // Hello
        \\        // Hello
        \\        // Hello
        \\    /// Hello
        \\    /// Hello
        \\    /// Hello
        \\Hello
        \\Hello
        \\Hello
        \\
    , list.items);
}
