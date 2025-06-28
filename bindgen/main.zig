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
    var parser = zimdjson.ondemand.FullParser(.default).init;
    defer parser.deinit(allocator);
    var document = try parser.parseFromReader(allocator, config.extension_api.reader().any());
    const godot_api = try document.asLeaky(GodotApi, allocator, .{});

    // Build the codegen context
    var ctx = try Context.build(allocator, godot_api, config);

    // Generate the code
    try codegen.generate(&ctx);

    // Format the code
    _ = try std.process.Child.run(.{
        .allocator = allocator,
        .cwd_dir = config.output,
        .argv = &.{ "zig", "fmt" },
        .max_output_bytes = 1024 * 1024,
    });

    if (config.verbosity == .verbose) {
        std.debug.print("Output path: {s}\n", .{args[2]});
        std.debug.print("API JSON: {s}/extension_api.json\n", .{args[1]});
    }
}

const std = @import("std");

const zimdjson = @import("zimdjson");

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
