//! Test server that runs inside the Godot extension.
//!
//! Reads commands from stdin, writes responses to stdout using JSON IPC.
//! Non-IPC output from Godot is filtered out by the coordinator.
//!
//! Commands:
//! - query_metadata: returns list of test names from builtin.test_functions
//! - run_test: executes a specific test and returns the result
//! - exit: triggers Godot to quit

const std = @import("std");
const json_ipc = @import("json_ipc.zig");

const gdzig = @import("gdzig");
const Os = gdzig.class.Os;

const builtin = @import("builtin");

/// Run the test server. This blocks until the runner sends an exit message.
/// After returning, the caller should trigger Godot to quit.
pub fn run(allocator: std.mem.Allocator) void {
    runImpl(allocator) catch {};
}

fn runImpl(allocator: std.mem.Allocator) !void {
    // Check if we should run (env var signals test mode)
    const test_mode = std.process.getEnvVarOwned(allocator, "GDZIG_TEST_MODE") catch |err| switch (err) {
        error.EnvironmentVariableNotFound => return,
        else => return,
    };
    defer allocator.free(test_mode);

    // Get stdin and stdout
    const stdin_file = std.fs.File.stdin();
    const stdout_file = std.fs.File.stdout();

    var line_buf: std.ArrayListUnmanaged(u8) = .empty;
    defer line_buf.deinit(allocator);

    // Message loop - read commands from stdin, write responses to stdout
    while (true) {
        // Read a line from stdin byte by byte (for Windows pipe compatibility)
        line_buf.clearRetainingCapacity();
        while (true) {
            var byte_buf: [1]u8 = undefined;
            const n = stdin_file.read(&byte_buf) catch return;
            if (n == 0) return; // EOF
            const byte = byte_buf[0];
            if (byte == '\n') break;
            try line_buf.append(allocator, byte);
        }

        const line = line_buf.items;

        // Skip non-IPC lines (shouldn't happen on stdin, but be safe)
        if (!json_ipc.isIpcMessage(line)) continue;

        // Parse command
        const cmd = json_ipc.parseCommand(line) orelse continue;

        switch (cmd) {
            .query_metadata => try handleQueryMetadata(stdout_file),
            .run_test => |index| try handleRunTest(stdout_file, index),
            .exit => break,
        }
    }
}

/// Trigger Godot to quit.
pub fn quit() void {
    const pid = Os.getProcessId();
    _ = Os.kill(pid);
}

fn handleQueryMetadata(stdout: std.fs.File) !void {
    const test_fns = getTestFunctions();
    var names: [256][]const u8 = undefined;
    const count = @min(test_fns.len, names.len);

    for (test_fns[0..count], 0..) |t, i| {
        names[i] = t.name;
    }

    var buf: [8192]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    try json_ipc.writeMetadataResponse(fbs.writer(), names[0..count]);
    try stdout.writeAll(fbs.getWritten());
}

fn handleRunTest(stdout: std.fs.File, index: u32) !void {
    const test_fns = getTestFunctions();

    var buf: [4096]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);

    if (index >= test_fns.len) {
        try json_ipc.writeResultResponse(fbs.writer(), index, false, "Test index out of bounds");
        try stdout.writeAll(fbs.getWritten());
        return;
    }

    const test_fn = test_fns[index];
    const result = runSingleTest(test_fn);

    try json_ipc.writeResultResponse(fbs.writer(), index, result.passed, result.message);
    try stdout.writeAll(fbs.getWritten());
}

const TestFn = std.builtin.TestFn;

fn getTestFunctions() []const TestFn {
    return builtin.test_functions;
}

const SingleTestResult = struct {
    passed: bool,
    message: ?[]const u8,
};

fn runSingleTest(test_fn: TestFn) SingleTestResult {
    if (test_fn.func()) |_| {
        return .{ .passed = true, .message = null };
    } else |err| {
        if (@errorReturnTrace()) |trace| {
            std.debug.dumpStackTrace(trace.*);
        }
        std.debug.print("test failed with error.{s}\n", .{@errorName(err)});
        return .{ .passed = false, .message = null };
    }
}
