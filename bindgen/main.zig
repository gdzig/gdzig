pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 5) {
        std.debug.print("Usage: bindgen <vendor_path> <output_path> <float|double> <32|64> <quiet|verbose>\n", .{});
        return;
    }

    // Assemble the bindgen configuration
    var config = try Config.loadFromArgs(args);
    defer config.deinit();

    // Parse the extension_api.json
    const parser_start = std.time.nanoTimestamp();
    const godot_api = try GodotApi.parseFromReader(&arena, config.extension_api.reader().any());
    defer godot_api.deinit();
    const parser_time = std.time.nanoTimestamp() - parser_start;

    // Build the codegen context
    const context_start = std.time.nanoTimestamp();
    var ctx = try Context.build(&arena, godot_api.value, config);
    const context_time = std.time.nanoTimestamp() - context_start;

    // Generate the code
    const codegen_start = std.time.nanoTimestamp();
    try codegen.generate(&ctx);
    const codegen_time = std.time.nanoTimestamp() - codegen_start;

    // Format the code
    const format_start = std.time.nanoTimestamp();
    _ = try std.process.Child.run(.{
        .allocator = allocator,
        .cwd_dir = config.output,
        .argv = &.{ "zig", "fmt" },
        .max_output_bytes = 1024 * 1024,
    });
    const format_time = std.time.nanoTimestamp() - format_start;

    if (config.verbosity == .verbose) {
        if (config.verbosity == .verbose) {
            const total_time = parser_time + context_time + codegen_time + format_time;
            std.debug.print("Parser time: {d:.2}ms\n", .{@as(f64, @floatFromInt(parser_time)) / 1_000_000.0});
            std.debug.print("Context time: {d:.2}ms\n", .{@as(f64, @floatFromInt(context_time)) / 1_000_000.0});
            std.debug.print("Codegen time: {d:.2}ms\n", .{@as(f64, @floatFromInt(codegen_time)) / 1_000_000.0});
            std.debug.print("Format time: {d:.2}ms\n", .{@as(f64, @floatFromInt(format_time)) / 1_000_000.0});
            std.debug.print("Total time: {d:.2}ms\n", .{@as(f64, @floatFromInt(total_time)) / 1_000_000.0});
        }
        std.debug.print("Output path: {s}\n", .{args[2]});
        std.debug.print("API JSON: {s}/extension_api.json\n", .{args[1]});
    }
}

const std = @import("std");

const codegen = @import("codegen.zig");
const Config = @import("Config.zig");
const Context = @import("Context.zig");
const GodotApi = @import("GodotApi.zig");

comptime {
    _ = @import("writer.zig");
}

test {
    _ = @import("Context/docs.zig");
}
