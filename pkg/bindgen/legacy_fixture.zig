fn run(init: std.process.Init) !void {
    const argv = try init.minimal.args.toSlice(init.gpa);
    defer init.gpa.free(argv);
    if (argv.len != 2) return error.MissingOutput;
    var directory = try std.Io.Dir.cwd().createDirPathOpen(init.io, argv[1], .{});
    defer directory.close(init.io);

    // All cases share production emission; only the range and call site differ.
    const cases = [_]struct {
        name: []const u8,
        minimum: ?Version,
        usage: codegen.testing.Usage,
        runtime_version: Version = .{ .major = 4, .minor = 6, .patch = 2 },
        dispatch: ?bool = null,
    }{
        .{
            .name = "default-ref.zig",
            .minimum = null,
            .usage = .reference,
        },
        .{
            .name = "default-valid.zig",
            .minimum = null,
            .usage = .call,
        },
        .{
            .name = "default-rejected.zig",
            .minimum = null,
            .usage = .call,
            .runtime_version = .{ .major = 4, .minor = 7, .patch = 2 },
        },
        .{
            .name = "minimum-valid.zig",
            .minimum = .@"4.6",
            .usage = .call,
        },
        .{
            .name = "minimum-ref.zig",
            .minimum = .@"4.7",
            .usage = .reference,
        },
        .{
            .name = "minimum-missing.zig",
            .minimum = .@"4.7",
            .usage = .call,
        },
        .{
            .name = "dispatch-ref.zig",
            .minimum = null,
            .usage = .reference,
            .dispatch = false,
        },
        .{
            .name = "dispatch-panic.zig",
            .minimum = null,
            .usage = .call,
            .dispatch = false,
        },
        .{
            .name = "dispatch-modern.zig",
            .minimum = null,
            .usage = .call,
            .runtime_version = .{ .major = 4, .minor = 7, .patch = 2 },
            .dispatch = false,
        },
        .{
            .name = "dispatch-missing.zig",
            .minimum = .@"4.6",
            .usage = .call,
            .dispatch = false,
        },
        .{
            .name = "dispatch-above.zig",
            .minimum = .@"4.7",
            .usage = .call,
            .dispatch = false,
        },
        .{
            .name = "adapter-default.zig",
            .minimum = null,
            .usage = .call,
            .dispatch = true,
        },
        .{
            .name = "adapter-inside.zig",
            .minimum = .@"4.6",
            .usage = .call,
            .dispatch = true,
        },
        .{
            .name = "adapter-above.zig",
            .minimum = .@"4.7",
            .usage = .call,
            .dispatch = true,
        },
    };
    for (cases) |case| {
        var output: std.Io.Writer.Allocating = .init(init.gpa);
        defer output.deinit();
        if (case.dispatch) |adapter| {
            try codegen.testing.writeDispatchFixture(
                &output.writer,
                init.gpa,
                case.minimum,
                case.usage,
                case.runtime_version,
                adapter,
            );
        } else {
            try codegen.testing.writeLegacyFixture(
                &output.writer,
                init.gpa,
                case.minimum,
                case.usage,
                case.runtime_version,
            );
        }
        try directory.writeFile(init.io, .{ .sub_path = case.name, .data = output.written() });
    }

    // An external hash observer keeps both optimized branches non-vacuous.
    for ([_]Version{ .@"4.6", .@"4.7" }) |minimum| {
        var output: std.Io.Writer.Allocating = .init(init.gpa);
        defer output.deinit();
        try codegen.testing.writeDispatchIrFixture(&output.writer, init.gpa, minimum);
        const name = try std.fmt.allocPrint(init.gpa, "dispatch-ir-{d}.zig", .{minimum.minor});
        defer init.gpa.free(name);
        try directory.writeFile(init.io, .{ .sub_path = name, .data = output.written() });
    }
}

/// Materialize range acceptance fixtures using the production legacy writer.
pub fn main(init: std.process.Init) void {
    run(init) catch |err| std.process.fatal("legacy-fixture: {t}", .{err});
}

const std = @import("std");

const Version = @import("common").Version;
const codegen = @import("codegen.zig");
