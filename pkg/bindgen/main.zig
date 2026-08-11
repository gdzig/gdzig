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
    var arena = std.heap.ArenaAllocator.init(init.gpa);
    defer arena.deinit();

    const allocator = arena.allocator();

    var args_iter = std.process.Args.Iterator.init(init.minimal.args);
    var args_list: std.ArrayListUnmanaged([]const u8) = .empty;
    while (args_iter.next()) |arg| {
        try args_list.append(allocator, arg);
    }
    const args = args_list.items;

    if (args.len < 6) {
        std.debug.print("Usage: bindgen <gdextension_interface.h> <extension_api.json> <mixins_root> <output_path> <float|double> <32|64> <quiet|verbose>\n", .{});
        return;
    }

    // Assemble the bindgen configuration
    var config = try Config.loadFromArgs(init.io, args);
    defer config.deinit();

    verbose = config.verbosity == .verbose;

    var buf: [4096]u8 = undefined;
    var reader = config.extension_api.readerStreaming(init.io, &buf);

    // Parse the extension_api.json
    const godot_api = try GodotApi.parseFromReader(&arena, &reader.interface);
    defer godot_api.deinit();

    // Build the codegen context
    var ctx = try Context.build(&arena, godot_api.value, config);

    // Generate the code
    try codegen.generate(&ctx);

    // Format the code
    var fmt_child = try std.process.spawn(init.io, .{
        .argv = &.{ "zig", "fmt", "." },
        .cwd = .{ .dir = config.output },
    });
    _ = try fmt_child.wait(init.io);

    if (config.verbosity == .verbose) {
        std.debug.print("Output path: {s}\n", .{args[4]});
        std.debug.print("Interface: {s}\n", .{args[1]});
        std.debug.print("API JSON: {s}\n", .{args[2]});
    }
}

test {
    std.testing.log_level = .err;
    std.testing.refAllDecls(@This());
}
