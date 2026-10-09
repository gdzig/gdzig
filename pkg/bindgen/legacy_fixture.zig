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
        call: bool,
        runtime_minor: u32 = 6,
    }{
        .{ .name = "default-ref.zig", .minimum = null, .call = false },
        .{ .name = "default-valid.zig", .minimum = null, .call = true },
        .{ .name = "default-rejected.zig", .minimum = null, .call = true, .runtime_minor = 7 },
        .{ .name = "minimum-valid.zig", .minimum = .@"4.6", .call = true },
        .{ .name = "minimum-ref.zig", .minimum = .@"4.7", .call = false },
        .{ .name = "minimum-missing.zig", .minimum = .@"4.7", .call = true },
    };
    for (cases) |case| {
        var output: std.Io.Writer.Allocating = .init(init.gpa);
        defer output.deinit();
        try codegen.writeLegacyFixture(
            &output.writer,
            init.gpa,
            case.minimum,
            case.call,
            case.runtime_minor,
        );
        try directory.writeFile(init.io, .{ .sub_path = case.name, .data = output.written() });
    }
}

/// Materialize range acceptance fixtures using the production legacy writer.
pub fn main(init: std.process.Init) void {
    run(init) catch |err| std.process.fatal("legacy-fixture: {t}", .{err});
}

const std = @import("std");

const Version = @import("common").Version;
const codegen = @import("codegen.zig");
