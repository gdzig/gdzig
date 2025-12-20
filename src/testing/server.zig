//! Test server that runs inside the Godot extension.
//!
//! Connects to the test runner via TCP and handles:
//! - query_test_metadata: returns list of test names from builtin.test_functions
//! - run_test: executes a specific test and returns the result
//! - exit: triggers Godot to quit

const std = @import("std");
const protocol = @import("protocol.zig");
const Io = std.Io;

const gdzig = @import("gdzig");
const Os = gdzig.class.Os;

const log = std.log.scoped(.gdzig_testing);

/// Run the test server. This blocks until the runner sends an exit message.
/// After returning, the caller should trigger Godot to quit.
pub fn run(allocator: std.mem.Allocator) void {
    runImpl(allocator) catch |err| {
        log.debug("test server error: {}", .{err});
    };
}

fn runImpl(allocator: std.mem.Allocator) !void {
    log.debug("server starting...", .{});

    // Get port from environment variable
    const port_str = std.posix.getenv("GDZIG_TEST_PORT") orelse {
        log.debug("GDZIG_TEST_PORT not set, skipping test server", .{});
        return;
    };

    log.debug("GDZIG_TEST_PORT={s}", .{port_str});

    const port = std.fmt.parseInt(u16, port_str, 10) catch {
        log.debug("invalid GDZIG_TEST_PORT: {s}", .{port_str});
        return;
    };

    // Connect to the runner
    log.debug("connecting to runner on port {d}...", .{port});
    const address = std.net.Address.initIp4(.{ 127, 0, 0, 1 }, port);
    const stream = std.net.tcpConnectToAddress(address) catch |err| {
        log.debug("failed to connect to test runner on port {d}: {}", .{ port, err });
        return;
    };
    defer stream.close();
    log.debug("connected!", .{});

    // Create buffered reader and writer
    var read_buf: [4096]u8 = undefined;
    var write_buf: [4096]u8 = undefined;
    var reader = std.net.Stream.Reader.init(stream, &read_buf);
    var writer = std.net.Stream.Writer.init(stream, &write_buf);

    var msg_buf: [65536]u8 = undefined;

    // Message loop
    log.debug("entering message loop...", .{});
    while (true) {
        log.debug("waiting for message...", .{});
        const msg = protocol.readMessage(reader.interface(), &msg_buf) catch |err| {
            log.debug("failed to read message: {}", .{err});
            break;
        };

        log.debug("received message tag: {}", .{msg.tag});

        switch (msg.tag) {
            .query_test_metadata => {
                log.debug("handling query_test_metadata", .{});
                try handleQueryMetadata(allocator, &writer.interface);
                log.debug("query_test_metadata done", .{});
            },
            .run_test => {
                const index = protocol.decodeRunTest(msg.payload);
                log.debug("handling run_test index={d}", .{index});
                try handleRunTest(allocator, &writer.interface, index);
                log.debug("run_test done", .{});
            },
            .exit => {
                log.debug("exit requested", .{});
                break;
            },
            else => {
                log.debug("unknown message tag: {}", .{@intFromEnum(msg.tag)});
            },
        }
    }
    log.debug("server finished", .{});
}

/// Trigger Godot to quit.
pub fn quit() void {
    const pid = Os.getProcessId();
    _ = Os.kill(pid);
}

fn handleQueryMetadata(allocator: std.mem.Allocator, writer: *Io.Writer) !void {
    const test_fns = getTestFunctions();
    var names: std.ArrayListUnmanaged([]const u8) = .empty;
    defer names.deinit(allocator);

    for (test_fns) |t| {
        try names.append(allocator, t.name);
    }

    const payload = try protocol.encodeTestMetadata(allocator, names.items);
    defer allocator.free(payload);

    try protocol.writeMessage(writer, .test_metadata, payload);
}

fn handleRunTest(allocator: std.mem.Allocator, writer: *Io.Writer, index: u32) !void {
    const test_fns = getTestFunctions();

    if (index >= test_fns.len) {
        const payload = try protocol.encodeTestResult(allocator, index, false, "Test index out of bounds");
        defer allocator.free(payload);
        try protocol.writeMessage(writer, .test_result, payload);
        return;
    }

    const test_fn = test_fns[index];
    const result = runSingleTest(allocator, test_fn);

    const payload = try protocol.encodeTestResult(allocator, index, result.passed, result.message);
    defer allocator.free(payload);
    try protocol.writeMessage(writer, .test_result, payload);
}

const TestFn = std.builtin.TestFn;
const builtin = @import("builtin");

fn getTestFunctions() []const TestFn {
    return builtin.test_functions;
}

const SingleTestResult = struct {
    passed: bool,
    message: []const u8,
};

fn runSingleTest(allocator: std.mem.Allocator, test_fn: TestFn) SingleTestResult {
    _ = allocator;
    // Run the test function
    if (test_fn.func()) |_| {
        return .{ .passed = true, .message = "" };
    } else |err| {
        // Print error with stack trace like Zig's built-in test runner
        if (@errorReturnTrace()) |trace| {
            std.debug.dumpStackTrace(trace.*);
        }
        std.debug.print("test failed with error.{s}\n", .{@errorName(err)});

        return .{ .passed = false, .message = "" };
    }
}
