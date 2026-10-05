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

/// Validate named inputs, generate API bindings, then format the output.
pub fn main(init: std.process.Init) !void {
    var arena: std.heap.ArenaAllocator = .init(init.gpa);
    defer arena.deinit();

    const allocator = arena.allocator();

    const args = try init.minimal.args.toSlice(allocator);
    const arguments = Config.parseArgs(args[1..]) catch |err| {
        if (err != error.HelpRequested) {
            std.debug.print("Invalid bindgen arguments: {s}\n", .{@errorName(err)});
        }
        std.debug.print("{s}", .{Config.usage});
        if (err == error.HelpRequested) return;
        return err;
    };

    var config = try Config.load(init.io, arguments);
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
        std.debug.print("Output path: {s}\n", .{arguments.output});
        std.debug.print("Interface: {s}\n", .{arguments.gdextension_interface});
        std.debug.print("API JSON: {s}\n", .{arguments.extension_api});
    }
}

test {
    std.testing.log_level = .err;
    std.testing.refAllDecls(@This());
    std.testing.refAllDecls(@import("Mixin.zig"));
}

const std = @import("std");

const codegen = @import("codegen.zig");
const Config = @import("Config.zig");
const Context = @import("Context.zig");
const GodotApi = @import("GodotApi.zig");
