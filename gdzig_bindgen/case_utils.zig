fn SliceCase(comptime c: Case) type {
    return struct {
        pub fn format(
            str: []const u8,
            writer: *Writer,
        ) Writer.Error!void {
            var buf: [128]u8 = undefined;

            const result = blk: {
                if (c == .camel and case.isSnake(str) and str[0] == '_') {
                    break :blk godotMethodCamel(&buf, str);
                }

                break :blk case.bufTo(&buf, c, str);
            } catch return error.WriteFailed;

            try writer.writeAll(result);
        }
    };
}

const formatSlicePascal = SliceCase(.pascal).format;
const formatSliceCamel = SliceCase(.camel).format;
const formatSliceSnake = SliceCase(.snake).format;
const formatSliceKebab = SliceCase(.kebab).format;

pub fn fmtSliceCasePascal(str: []const u8) Alt([]const u8, formatSlicePascal) {
    return .{ .data = str };
}

pub fn fmtSliceCaseCamel(str: []const u8) Alt([]const u8, formatSliceCamel) {
    return .{ .data = str };
}

pub fn fmtSliceCaseSnake(str: []const u8) Alt([]const u8, formatSliceSnake) {
    return .{ .data = str };
}

pub fn fmtSliceCaseKebab(str: []const u8) Alt([]const u8, formatSliceKebab) {
    return .{ .data = str };
}

/// Formats a Godot method name.
///
/// Will preserve leading underscores on private methods.
pub fn godotMethodCamel(buf: []u8, input: []const u8) ![]const u8 {
    // formatting a private method
    if (case.isSnake(input) and input[0] == '_') {
        var copy_buf: [128]u8 = undefined;
        const tmp = try case.bufTo(&copy_buf, .camel, input[1..]);
        return try std.fmt.bufPrint(buf, "_{s}", .{tmp});
    }

    return try case.bufTo(buf, .camel, input);
}

const std = @import("std");
const Alt = std.fmt.Alt;
const Writer = std.io.Writer;

const case = @import("case");
const Case = case.Case;
