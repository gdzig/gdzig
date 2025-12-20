//! A writer that tracks indentation level, and commenting state.

const CodeWriter = @This();

out: *Writer,
indent: usize = 0,
at_line_start: bool = true,
comment: enum { off, on, doc } = .off,
writer: Writer,

pub fn init(out: *Writer) CodeWriter {
    return .{
        .out = out,
        .writer = .{
            .buffer = &.{},
            .vtable = &.{
                .drain = CodeWriter.drain,
            },
        },
    };
}

fn drain(w: *Writer, data: []const []const u8, splat: usize) Error!usize {
    _ = splat; // autofix
    const this: *CodeWriter = @alignCast(@fieldParentPtr("writer", w));

    var written: usize = 0;
    for (data) |bytes| {
        for (bytes) |byte| {
            // Add indentation at start of line (but not for empty lines)
            if (this.at_line_start and (this.comment != .off or byte != '\n')) {
                for (0..this.indent) |_| {
                    _ = try this.out.writeAll(" " ** 4);
                }

                _ = switch (this.comment) {
                    .on => try this.out.writeAll("// "),
                    .doc => try this.out.writeAll("/// "),
                    else => {},
                };

                this.at_line_start = false;
            }

            // Write the byte
            _ = try this.out.writeByte(byte);
            written += 1;

            // Track if we're at the start of the next line
            if (byte == '\n') {
                this.at_line_start = true;
            }
        }
    }
    return written;
}

pub fn writeLine(this: *CodeWriter, line: []const u8) !void {
    try this.writer.writeAll(line);
    try this.writer.writeByte('\n');
}

pub fn writeAll(this: *CodeWriter, bytes: []const u8) !void {
    try this.writer.writeAll(bytes);
}

pub fn print(this: *CodeWriter, comptime fmt: []const u8, args: anytype) !void {
    try this.writer.print(fmt, args);
}

pub fn printLine(this: *CodeWriter, comptime fmt: []const u8, args: anytype) !void {
    try this.print(fmt, args);
    try this.writer.writeByte('\n');
}

test "indents" {
    var out = std.Io.Writer.Allocating.init(testing.allocator);
    defer out.deinit();

    var w = CodeWriter.init(&out.writer);

    try w.writer.writeAll("Hello\nHello\nHello\n");
    w.indent += 1;
    try w.writer.writeAll("Hello\nHello\nHello\n");
    w.indent += 1;
    w.comment = .on;
    try w.writer.writeAll("Hello\nHello\nHello\n");
    w.comment = .doc;
    w.indent -= 1;
    try w.writer.writeAll("Hello\nHello\nHello\n");
    w.comment = .off;
    w.indent -= 1;
    try w.writer.writeAll("Hello\nHello\nHello\n");

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
    , out.written());
}

const std = @import("std");
const testing = std.testing;
const Writer = std.Io.Writer;
pub const Error = Writer.Error;
