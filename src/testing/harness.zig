//! Test harness for GDExtension tests.
//!
//! This is the Zig test runner that runs inside Godot. It:
//! 1. Has access to builtin.test_functions (because it's a Zig test runner)
//! 2. Exports the GDExtension entrypoint (so Godot can load it)
//! 3. Reads commands from stdin, writes JSON responses to stdout

const std = @import("std");
const builtin = @import("builtin");
const gdzig = @import("gdzig");
const options = @import("options");
const protocol = @import("protocol.zig");

const Os = gdzig.class.Os;

// Export the GDExtension entrypoint
comptime {
    @export(&entrypoint, .{
        .name = options.entry_symbol,
        .linkage = .strong,
    });
}

fn entrypoint(
    get_proc_address: gdzig.c.GDExtensionInterfaceGetProcAddress,
    library: gdzig.c.GDExtensionClassLibraryPtr,
    r_initialization: *gdzig.c.GDExtensionInitialization,
) callconv(.c) gdzig.c.GDExtensionBool {
    gdzig.raw = .init(get_proc_address.?, library.?);
    gdzig.raw.getGodotVersion(@ptrCast(&gdzig.version));

    r_initialization.* = .{
        .minimum_initialization_level = @intFromEnum(options.minimum_initialization_level),
        .initialize = &enter,
        .deinitialize = &exit,
        .userdata = null,
    };

    return 1;
}

fn enter(_: ?*anyopaque, level: gdzig.c.GDExtensionInitializationLevel) callconv(.c) void {
    if (level != @intFromEnum(options.minimum_initialization_level)) return;

    run();
    quit();
}

fn exit(_: ?*anyopaque, _: gdzig.c.GDExtensionInitializationLevel) callconv(.c) void {}

/// Run the test server. Reads commands from stdin, writes responses to stdout.
fn run() void {
    // Check if we should run (env var signals test mode)
    if (!std.process.Environ.containsUnemptyConstant(.{ .block = .global }, "GDZIG_TEST_MODE")) return;

    runImpl() catch {};
}

fn runImpl() !void {
    const allocator = gdzig.engine_allocator;
    const io = std.Io.Threaded.global_single_threaded.io();

    // Get stdin and stdout with buffering
    const stdin_file = std.Io.File.stdin();
    const stdout_file = std.Io.File.stdout();

    var stdin_buf: [4096]u8 = undefined;
    var stdout_buf: [4096]u8 = undefined;
    var stdin = std.Io.File.Reader.initStreaming(stdin_file, io, &stdin_buf);
    var stdout = std.Io.File.Writer.initStreaming(stdout_file, io, &stdout_buf);

    var line_buf: std.ArrayListUnmanaged(u8) = .empty;
    defer line_buf.deinit(allocator);

    // Message loop - read commands from stdin, write responses to stdout
    while (true) {
        // Read a line from stdin
        line_buf.clearRetainingCapacity();
        while (true) {
            const byte = stdin.interface.takeByte() catch |err| {
                if (err == error.EndOfStream) return;
                return;
            };
            if (byte == '\n') break;
            try line_buf.append(allocator, byte);
        }

        const line = line_buf.items;

        // Skip non-IPC lines (shouldn't happen on stdin, but be safe)
        if (!protocol.isIpcMessage(line)) continue;

        // Parse command
        const cmd = protocol.parseCommand(line) orelse continue;

        switch (cmd) {
            .query_metadata => try handleQueryMetadata(&stdout.interface),
            .run_test => |index| try handleRunTest(&stdout.interface, index),
            .exit => break,
        }
    }
}

/// Trigger Godot to quit.
fn quit() void {
    const pid = Os.getProcessId();
    _ = Os.kill(pid);
}

fn handleQueryMetadata(writer: *std.Io.Writer) !void {
    const test_fns = builtin.test_functions;
    var names: [256][]const u8 = undefined;
    const count = @min(test_fns.len, names.len);

    for (test_fns[0..count], 0..) |t, i| {
        names[i] = t.name;
    }

    try protocol.writeMetadataResponse(writer, names[0..count]);
    try writer.flush();
}

fn handleRunTest(writer: *std.Io.Writer, index: u32) !void {
    const test_fns = builtin.test_functions;

    if (index >= test_fns.len) {
        try protocol.writeResultResponse(writer, index, false, "Test index out of bounds");
        try writer.flush();
        return;
    }

    const test_fn = test_fns[index];
    const result = runSingleTest(test_fn);

    try protocol.writeResultResponse(writer, index, result.passed, result.message);
    try writer.flush();
}

const SingleTestResult = struct {
    passed: bool,
    message: ?[]const u8,
};

fn runSingleTest(test_fn: std.builtin.TestFn) SingleTestResult {
    if (test_fn.func()) |_| {
        return .{ .passed = true, .message = null };
    } else |err| {
        std.debug.print("test failed with error.{s}\n", .{@errorName(err)});
        return .{ .passed = false, .message = null };
    }
}
