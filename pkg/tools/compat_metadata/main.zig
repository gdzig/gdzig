const Arguments = struct {
    mode: manifest.Mode,
    current: []const u8,
    old: []const u8,
    input: ?[]const u8,
    output: []const u8,
    report: []const u8,
    expect: ?[]const u8,
};

const Report = struct {
    schema_version: u32 = 2,
    current: manifest.Provenance,
    source: manifest.Provenance,
    content: manifest.Provenance,
    comparison: ReportComparison,
};

// The report remains a stable JSON view, independent of the manifest's ZON schema.
const ReportOverride = struct {
    kind: records.Kind,
    owner: []const u8,
    method: []const u8,
    old_hash: u64,
    layout: std.meta.Tag(manifest.Layout),
    added_arguments: []const []const u8 = &.{},
    layout_diff: ?[]const u8 = null,
    old_arguments: ?[]const records.Argument = null,
    old_return: ?records.Return = null,
    old_flags: ?manifest.Flags = null,

    fn fromOverride(value: manifest.Override) ReportOverride {
        var result: ReportOverride = .{
            .kind = value.kind,
            .owner = value.owner,
            .method = value.method,
            .old_hash = value.old_hash,
            .layout = std.meta.activeTag(value.layout),
        };
        switch (value.layout) {
            .identical => {},
            .trailing_defaults => |details| result.added_arguments = details.added_arguments,
            .abi_compatible => |reason| result.layout_diff = switch (reason) {
                .const_flag => "const",
                .renamed_enum => "enum_renamed",
            },
            .return_added, .incompatible => |legacy| {
                result.layout_diff = legacy.difference;
                result.old_arguments = legacy.arguments;
                result.old_return = legacy.@"return";
                result.old_flags = legacy.flags;
            },
        }
        return result;
    }
};

const ReportComparison = struct {
    overrides: []const ReportOverride,
    virtual: []const manifest.Audit,
    absent: []const manifest.Audit,
    multi_compat: []const manifest.Audit,
    unresolved: []const manifest.Audit,

    fn fromComparison(allocator: std.mem.Allocator, comparison: manifest.Comparison) !ReportComparison {
        const overrides = try allocator.alloc(ReportOverride, comparison.overrides.len);
        for (comparison.overrides, overrides) |value, *result| {
            result.* = .fromOverride(value);
        }
        return .{
            .overrides = overrides,
            .virtual = comparison.virtual,
            .absent = comparison.absent,
            .multi_compat = comparison.multi_compat,
            .unresolved = comparison.unresolved,
        };
    }
};

const usage = "Usage: gdzig-compat-metadata --mode=overwrite|append [--input=<zon>] --current=<records.zon> --old=<records.zon> --output=<zon> --report=<json> [--expect=<zon>]\n";

fn fromArgs(args: *Args) !Arguments {
    const mode = args.required(manifest.Mode, "mode") catch |err| return switch (err) {
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

fn writeReport(
    allocator: std.mem.Allocator,
    io: std.Io,
    path: []const u8,
    current: records.Snapshot,
    old: records.Snapshot,
) !void {
    var report: std.Io.Writer.Allocating = .init(allocator);
    try std.json.Stringify.value(Report{
        .current = .fromSnapshot(current, false),
        .source = .fromSnapshot(old, false),
        .content = .fromSnapshot(old, !std.mem.eql(u8, old.version, current.version)),
        .comparison = try .fromComparison(allocator, try manifest.Comparison.compare(
            allocator,
            old.records,
            current.records,
            old.enums,
            current.enums,
        )),
    }, .{ .whitespace = .indent_2 }, &report.writer);
    try report.writer.writeByte('\n');
    try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = path, .data = report.written() });
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
    const current = try load(records.Snapshot, arena_allocator, init.io, arguments.current);
    const old = try load(records.Snapshot, arena_allocator, init.io, arguments.old);
    const previous = if (arguments.input) |path|
        try load(manifest.Manifest, arena_allocator, init.io, path)
    else
        null;

    // Preserve the comparison report before a merge failure aborts the update.
    const result_manifest = manifest.Manifest.merge(arena_allocator, current, old, arguments.mode, previous) catch |err| {
        try writeReport(arena_allocator, init.io, arguments.report, current, old);
        return err;
    };

    // Preserve the measured comparison beside the cache on successful updates too.
    try writeReport(arena_allocator, init.io, arguments.report, current, old);

    // Merge the target and write the canonical generated cache.
    var output: std.Io.Writer.Allocating = .init(arena_allocator);
    try result_manifest.write(&output.writer);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = arguments.output, .data = output.written() });

    // Check the expected bytes only when maintenance requested a stale-output guard.
    if (arguments.expect) |path| {
        const expected = try std.Io.Dir.cwd().readFileAlloc(
            init.io,
            path,
            arena_allocator,
            .limited(16 * 1024 * 1024),
        );
        try manifest.Manifest.checkExpected(output.written(), expected);
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
const manifest = @import("compat").manifest;
const records = @import("compat").records;
