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
    const arena = init.arena.allocator();
    const args = try init.minimal.args.toSlice(arena);
    if (args.len < 6) {
        std.debug.print("Usage: bindgen <gdextension_interface.h> <extension_api.json> <mixins_root> <output_path> <float|double> <32|64> <quiet|verbose>\n", .{});
        return;
    }

    // Assemble the bindgen configuration
    var config = try Config.loadFromArgs(init.io, args);
    defer config.deinit(init.io);

    verbose = config.verbosity == .verbose;

    var buf: [4096]u8 = undefined;
    var reader = config.extension_api.reader(init.io, &buf);

    // Parse the extension_api.json
    const parser_start = std.Io.Timestamp.now(init.io, .awake);
    const godot_api = try GodotApi.parseFromReader(init.arena, &reader.interface);
    defer godot_api.deinit();
    const context_start = std.Io.Timestamp.now(init.io, .awake);
    const parser_time = parser_start.durationTo(context_start).nanoseconds;

    // Build the codegen context
    var ctx = try Context.build(init.arena, godot_api.value, config, init.io);
    const codegen_start = std.Io.Timestamp.now(init.io, .awake);
    const context_time = context_start.durationTo(codegen_start).nanoseconds;

    // Generate the code
    try codegen.generate(&ctx, init.io);
    const format_start = std.Io.Timestamp.now(init.io, .awake);
    const codegen_time = codegen_start.durationTo(codegen_start).nanoseconds;

    // Format the code
    _ = try std.process.run(arena, init.io, .{
        .cwd = .{ .dir = config.output },
        .argv = &.{ "zig", "fmt" },
        .stderr_limit = .limited(1024 * 1024),
        .stdout_limit = .limited(1024 * 1024),
    });
    const format_time = format_start.durationTo(std.Io.Timestamp.now(init.io, .awake)).nanoseconds;

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
