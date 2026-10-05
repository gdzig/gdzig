const Arguments = struct {
    mode: Metadata.Mode,
    current: []const u8,
    old: []const u8,
    input: ?[]const u8,
    output: []const u8,
    report: []const u8,
    expect: ?[]const u8,
};

const Report = struct {
    schema_version: u32 = 2,
    current: Metadata.Provenance,
    source: Metadata.Provenance,
    content: Metadata.Provenance,
    comparison: Metadata.Comparison,
};

const usage = "Usage: gdzig-compat-metadata --mode=overwrite|append [--input=<zon>] --current=<records.zon> --old=<records.zon> --output=<zon> --report=<json> [--expect=<zon>]\n";

fn fromArgs(args: *Args) !Arguments {
    const mode = args.required(Metadata.Mode, "mode") catch |err| return switch (err) {
        error.InvalidValue => error.InvalidMode,
        else => err,
    };
    const input: ?[]const u8 = if (mode == .append)
        args.required([]const u8, "input") catch return error.MissingInput
    else
        null;
    const result: Arguments = .{
        .mode = mode,
        .current = try args.required([]const u8, "current"),
        .old = try args.required([]const u8, "old"),
        .input = input,
        .output = try args.required([]const u8, "output"),
        .report = try args.required([]const u8, "report"),
        .expect = try args.optional([]const u8, "expect"),
    };
    try args.reject(.strict);
    return result;
}

fn load(comptime T: type, allocator: std.mem.Allocator, io: std.Io, path: []const u8) !T {
    const bytes = try std.Io.Dir.cwd().readFileAlloc(io, path, allocator, .limited(128 * 1024 * 1024));
    var diagnostics: std.zon.parse.Diagnostics = undefined;
    return std.zon.parse.fromSlice(T, .{
        .gpa = allocator,
        .arena = allocator,
        .source = try allocator.dupeSentinel(u8, bytes, 0),
        .diagnostics = &diagnostics,
    });
}

fn run(init: std.process.Init) !void {
    // Parse arguments before opening any input files.
    var args: Args = try .init(init.gpa, init.minimal.args);
    defer args.deinit(init.gpa);
    const arguments = try fromArgs(&args);

    // Load the extracted inputs and any previous manifest into one arena.
    var arena: std.heap.ArenaAllocator = .init(init.gpa);
    defer arena.deinit();
    const arena_allocator = arena.allocator();
    const current = try load(Records.Snapshot, arena_allocator, init.io, arguments.current);
    const old = try load(Records.Snapshot, arena_allocator, init.io, arguments.old);
    const previous = if (arguments.input) |path|
        try load(Metadata.Manifest, arena_allocator, init.io, path)
    else
        null;

    // Preserve the comparison report before merging the target into the cache.
    var report: std.Io.Writer.Allocating = .init(arena_allocator);
    try std.json.Stringify.value(Report{
        .current = Metadata.provenance(current, false),
        .source = Metadata.provenance(old, false),
        .content = Metadata.provenance(old, !std.mem.eql(u8, old.version, current.version)),
        .comparison = try Metadata.compare(arena_allocator, old.records, current.records),
    }, .{ .whitespace = .indent_2 }, &report.writer);
    try report.writer.writeByte('\n');
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = arguments.report, .data = report.written() });

    // Merge the target and write the canonical generated cache.
    const manifest = try Metadata.merge(arena_allocator, current, old, arguments.mode, previous);
    var output: std.Io.Writer.Allocating = .init(arena_allocator);
    try Metadata.writeManifest(&output.writer, manifest);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = arguments.output, .data = output.written() });

    // Check the expected bytes only when maintenance requested a stale-output guard.
    if (arguments.expect) |path| {
        const expected = try std.Io.Dir.cwd().readFileAlloc(
            init.io,
            path,
            arena_allocator,
            .limited(16 * 1024 * 1024),
        );
        try Metadata.checkExpected(output.written(), expected);
    }
}

/// Merge one extracted target, preserving canonical cache bytes across run orders.
pub fn main(init: std.process.Init) void {
    run(init) catch |err| {
        if (err == error.StaleCompatibilityMetadata) {
            std.process.fatal("compatibility metadata is stale: run zig build update-compat-metadata -Dold=all\ncompat-metadata: {t}", .{err});
        }
        std.process.fatal("compat-metadata: {t}\n{s}", .{ err, usage });
    };
}

test "merge CLI enforces explicit mode and unread input policy before IO" {
    for ([_][]const []const u8{
        &.{"merge"},
        &.{ "merge", "--mode=invalid" },
        &.{ "merge", "--mode=overwrite", "--current=c", "--old=o", "--output=x", "--report=r", "--input=i" },
        &.{ "merge", "--mode=append" },
        &.{ "merge", "--mode=overwrite", "--current=c", "--old=o", "--output=x", "--report=r", "--unknown=x" },
        &.{ "merge", "--mode=overwrite", "--current=c", "--old=o", "--output=x", "--report=r", "path" },
    }, [_]anyerror{
        error.MissingArgument, error.InvalidMode,    error.UnusedArgument,
        error.MissingInput,    error.UnusedArgument, error.UnusedPositional,
    }) |argv, expected| {
        var args: Args = try .initSlice(std.testing.allocator, argv);
        defer args.deinit(std.testing.allocator);
        try std.testing.expectError(expected, fromArgs(&args));
    }
}

const std = @import("std");

const Args = @import("common").Args;
const Metadata = @import("CompatMetadata.zig");
const Records = @import("CompatRecords.zig");
