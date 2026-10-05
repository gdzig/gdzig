const Arguments = struct {
    api: []const u8,
    version: []const u8,
    output: []const u8,
};

const usage = "Usage: gdzig-compat-extract --api=<json> --version=<x.y.z> --output=<records.zon>\n";

fn fromArgs(args: *Args) !Arguments {
    const version = try args.required([]const u8, "version");
    _ = try Records.exactVersion(version);
    const result: Arguments = .{
        .api = try args.required([]const u8, "api"),
        .version = version,
        .output = try args.required([]const u8, "output"),
    };
    try args.reject(.strict);
    return result;
}

fn run(init: std.process.Init) !void {
    var args: Args = try .init(init.gpa, init.minimal.args);
    defer args.deinit(init.gpa);
    const arguments = try fromArgs(&args);
    var arena: std.heap.ArenaAllocator = .init(init.gpa);
    defer arena.deinit();
    const allocator = arena.allocator();
    const bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, arguments.api, allocator, .limited(128 * 1024 * 1024));
    const records = try Records.extract(allocator, bytes, arguments.version);
    var output: std.Io.Writer.Allocating = .init(allocator);
    try std.zon.stringify.serialize(records, .{}, &output.writer);
    try output.writer.writeByte('\n');
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = arguments.output, .data = output.written() });
}

/// Extract one validated API dump. Only this executable parses API JSON.
pub fn main(init: std.process.Init) void {
    run(init) catch |err| std.process.fatal("compat-extract: {t}\n{s}", .{ err, usage });
}

test "extract arguments reject unknown positional and abbreviated versions before IO" {
    for ([_][]const []const u8{
        &.{ "extract", "--version=4.6.0", "--api=api.json", "--output=records.zon", "--unknown=x" },
        &.{ "extract", "--version=4.6.0", "--api=api.json", "--output=records.zon", "path" },
        &.{ "extract", "--version=4.6" },
    }, [_]anyerror{ error.UnusedArgument, error.UnusedPositional, error.InvalidExactVersion }) |argv, expected| {
        var args: Args = try .initSlice(std.testing.allocator, argv);
        defer args.deinit(std.testing.allocator);
        try std.testing.expectError(expected, fromArgs(&args));
    }
}

const std = @import("std");

const Args = @import("common").Args;
const Records = @import("CompatRecords.zig");
