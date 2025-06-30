fn SliceCase(comptime c: Case) type {
    return struct {
        pub fn format(
            str: []const u8,
            comptime _: []const u8,
            _: FormatOptions,
            writer: anytype,
        ) !void {
            var buf: [128]u8 = undefined;
            const result = try case.bufTo(&buf, c, str);
            try writer.writeAll(result);
        }
    };
}

const formatSlicePascal = SliceCase(.pascal).format;
const formatSliceCamel = SliceCase(.camel).format;
const formatSliceSnake = SliceCase(.snake).format;
const formatSliceKebab = SliceCase(.kebab).format;

pub fn fmtSliceCasePascal(str: []const u8) Formatter(formatSlicePascal) {
    return .{ .data = str };
}

pub fn fmtSliceCaseCamel(str: []const u8) Formatter(formatSliceCamel) {
    return .{ .data = str };
}

pub fn fmtSliceCaseSnake(str: []const u8) Formatter(formatSliceSnake) {
    return .{ .data = str };
}

pub fn fmtSliceCaseKebab(str: []const u8) Formatter(formatSliceKebab) {
    return .{ .data = str };
}

const Case = case.Case;
const Formatter = std.fmt.Formatter;
const FormatOptions = std.fmt.FormatOptions;

const std = @import("std");
const case = @import("case");
