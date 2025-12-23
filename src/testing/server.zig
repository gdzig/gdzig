//! Test server that runs inside the Godot extension.
//!
//! Reads command from GDZIG_TEST_CMD environment variable, executes it,
//! writes response to stdout using JSON IPC, then exits.
//!
//! Commands (via GDZIG_TEST_CMD env var):
//! - "query_metadata": returns list of test names from builtin.test_functions
//! - "run_test:<index>": executes a specific test and returns the result

const std = @import("std");
const json_ipc = @import("json_ipc.zig");

const gdzig = @import("gdzig");
const Os = gdzig.class.Os;

const builtin = @import("builtin");

/// Run the test server. Reads command from env var, executes, writes response, exits.
pub fn run(allocator: std.mem.Allocator) void {
    runImpl(allocator) catch {};
}

fn runImpl(allocator: std.mem.Allocator) !void {
    // Check for command in env var
    const cmd_str = std.process.getEnvVarOwned(allocator, "GDZIG_TEST_CMD") catch |err| switch (err) {
        error.EnvironmentVariableNotFound => return,
        else => return,
    };
    defer allocator.free(cmd_str);

    const stdout_file = std.fs.File.stdout();

    // Parse and execute command
    if (std.mem.eql(u8, cmd_str, "query_metadata")) {
        try handleQueryMetadata(stdout_file);
    } else if (std.mem.startsWith(u8, cmd_str, "run_test:")) {
        const index_str = cmd_str["run_test:".len..];
        const index = std.fmt.parseInt(u32, index_str, 10) catch return;
        try handleRunTest(stdout_file, index);
    }
    // Command executed, server will exit and Godot will quit
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
