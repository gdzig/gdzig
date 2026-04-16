const std = @import("std");

const codegen = @import("codegen.zig");
const Config = @import("Config.zig");
const Context = @import("Context.zig");
const GodotApi = @import("GodotApi.zig");

var verbose: bool = false;

pub const std_options: std.Options = .{
    .logFn = logFn,
};

fn logFn(
    comptime level: std.log.Level,
    comptime scope: @EnumLiteral(),
    comptime format: []const u8,
    args: anytype,
) void {
    if (!verbose and level != .err) return;
    if (!verbose and scope == .markdown_formatter) return;
    std.log.defaultLog(level, scope, format, args);
}

pub fn main(init: std.process.Init) !void {
    const gpa = init.gpa;
    const io = init.io;

    const args = try init.minimal.args.toSlice(init.arena.allocator());

    if (args.len < 6) {
        std.debug.print("Usage: bindgen <gdextension_interface.h> <extension_api.json> <mixins_root> <output_path> <float|double> <32|64> <quiet|verbose>\n", .{});
        return;
    }

    // Assemble the bindgen configuration
    var config = try Config.loadFromArgs(io, args);
    defer config.deinit(io);

    verbose = config.verbosity == .verbose;

    var buf: [4096]u8 = undefined;
    var reader = config.extension_api.reader(io, &buf);

    // Parse the extension_api.json
    const parser_start = std.Io.Timestamp.now(io, .awake);
    const godot_api = try GodotApi.parseFromReader(init.arena, &reader.interface);
    defer godot_api.deinit();
    const parser_end = std.Io.Timestamp.now(io, .awake);
    const parser_time = std.Io.Timestamp.durationTo(parser_start, parser_end).nanoseconds;

    // Build the codegen context
    const context_start = std.Io.Timestamp.now(io, .awake);
    var ctx = try Context.build(init.arena, godot_api.value, config, io);
    const context_end = std.Io.Timestamp.now(io, .awake);
    const context_time = std.Io.Timestamp.durationTo(context_start, context_end).nanoseconds;

    // Generate the code
    const codegen_start = std.Io.Timestamp.now(io, .awake);
    try codegen.generate(&ctx);
    const codegen_end = std.Io.Timestamp.now(io, .awake);
    const codegen_time = std.Io.Timestamp.durationTo(codegen_start, codegen_end).nanoseconds;

    // Format the code
    const format_start = std.Io.Timestamp.now(io, .awake);
    const fmt_result = try std.process.run(gpa, io, .{
        .argv = &.{ "zig", "fmt" },
        .stdout_limit = .limited(1024 * 1024),
        .stderr_limit = .limited(1024 * 1024),
    });
    gpa.free(fmt_result.stdout);
    gpa.free(fmt_result.stderr);
    const format_end = std.Io.Timestamp.now(io, .awake);
    const format_time = std.Io.Timestamp.durationTo(format_start, format_end).nanoseconds;

    if (config.verbosity == .verbose) {
        if (config.verbosity == .verbose) {
            const total_time = parser_time + context_time + codegen_time + format_time;
            std.debug.print("Parser time: {d:.2}ms\n", .{@as(f64, @floatFromInt(parser_time)) / 1_000_000.0});
            std.debug.print("Context time: {d:.2}ms\n", .{@as(f64, @floatFromInt(context_time)) / 1_000_000.0});
            std.debug.print("Codegen time: {d:.2}ms\n", .{@as(f64, @floatFromInt(codegen_time)) / 1_000_000.0});
            std.debug.print("Format time: {d:.2}ms\n", .{@as(f64, @floatFromInt(format_time)) / 1_000_000.0});
            std.debug.print("Total time: {d:.2}ms\n", .{@as(f64, @floatFromInt(total_time)) / 1_000_000.0});
        }
        std.debug.print("Output path: {s}\n", .{args[4]});
        std.debug.print("Interface: {s}\n", .{args[1]});
        std.debug.print("API JSON: {s}\n", .{args[2]});
    }
}

test {
    std.testing.log_level = .err;
    std.testing.refAllDecls(@This());
}
