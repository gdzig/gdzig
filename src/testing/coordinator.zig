//! Test coordinator that bridges the Zig build system and Godot processes.
//!
//! This executable:
//! 1. Speaks the std.zig.Server protocol with the build system (via stdin/stdout)
//! 2. Spawns Godot processes for its test suite
//! 3. Communicates with test harnesses via JSON IPC over stdin/stdout pipes

/// State for the test runner
const Runner = struct {
    allocator: Allocator,
    io: Io,
    server: ZigServer,
    string_bytes: std.ArrayListUnmanaged(u8),
    test_name_indices: std.ArrayListUnmanaged(u32),
    environ_map: *std.process.Environ.Map,

    fn init(allocator: Allocator, io: Io, environ_map: *std.process.Environ.Map, in: *Io.Reader, out: *Io.Writer) !Runner {
        const server: ZigServer = if (comptime @hasDecl(std.zig.Server, "init"))
            try ZigServer.init(.{
                .in = in,
                .out = out,
                .zig_version = builtin.zig_version_string,
            })
        else blk: {
            var s: ZigServer = .{ .in = in, .out = out };
            try s.serveStringMessage(.zig_version, builtin.zig_version_string);
            break :blk s;
        };

        return .{
            .allocator = allocator,
            .io = io,
            .server = server,
            .string_bytes = .empty,
            .test_name_indices = .empty,
            .environ_map = environ_map,
        };
    }

    fn deinit(self: *Runner) void {
        self.string_bytes.deinit(self.allocator);
        self.test_name_indices.deinit(self.allocator);
    }

    fn run(self: *Runner) !void {
        try self.collectMetadata();

        while (true) {
            const header = self.server.receiveMessage() catch |err| {
                if (err == error.EndOfStream) break;
                return err;
            };

            switch (header.tag) {
                .exit => break,
                .query_test_metadata => try self.handleQueryTestMetadata(),
                .run_test => {
                    const index = try self.server.receiveBody_u32();
                    try self.handleRunTest(index);
                },
                else => {
                    _ = try self.server.in.discard(Io.Limit.limited(header.bytes_len));
                },
            }
        }
    }

    fn handleQueryTestMetadata(self: *Runner) !void {
        // Build expected_panic_msgs (all zeros - we don't use panic expectations)
        const expected_panic_msgs = try self.allocator.alloc(u32, self.test_name_indices.items.len);
        defer self.allocator.free(expected_panic_msgs);
        @memset(expected_panic_msgs, 0);

        // Send metadata to build system
        try self.server.serveTestMetadata(.{
            .names = self.test_name_indices.items,
            .expected_panic_msgs = expected_panic_msgs,
            .string_bytes = self.string_bytes.items,
        });
    }

    fn collectMetadata(self: *Runner) !void {
        const folder_name = std.fs.path.basename(options.test_folder);

        // Spawn Godot with stdin/stdout piped
        var child = try self.spawnGodot();
        defer {
            _ = child.wait(self.io) catch {};
        }

        // Send query_metadata command
        try self.sendCommand(&child, .query_metadata);

        // Read response from stdout, filtering out Godot noise
        var godot_output: std.ArrayListUnmanaged(u8) = .empty;
        defer godot_output.deinit(self.allocator);

        const response = try self.readResponse(&child, &godot_output);
        if (response) |resp| {
            defer {
                var r = resp;
                protocol.freeResponse(self.allocator, &r);
            }

            switch (resp) {
                .metadata => |tests| {
                    for (tests) |name| {
                        // Record the string index before adding the prefixed name
                        const string_idx: u32 = @intCast(self.string_bytes.items.len);
                        try self.test_name_indices.append(self.allocator, string_idx);

                        // Add prefixed name: "folder.test name\0"
                        try self.string_bytes.appendSlice(self.allocator, folder_name);
                        try self.string_bytes.append(self.allocator, '.');
                        try self.string_bytes.appendSlice(self.allocator, name);
                        try self.string_bytes.append(self.allocator, 0);
                    }
                },
                .result => return error.UnexpectedResponse,
            }
        } else {
            if (godot_output.items.len > 0) {
                std.debug.print("Godot output:\n{s}\n", .{godot_output.items});
            }
            return error.NoResponse;
        }

        // Send exit command
        try self.sendCommand(&child, .exit);
    }

    fn handleRunTest(self: *Runner, index: u32) !void {
        if (index >= self.test_name_indices.items.len) {
            std.debug.print("Invalid test index {d} (suite has {d} tests)\n", .{ index, self.test_name_indices.items.len });
            try self.server.serveStringMessage(.test_started, &.{});
            try self.server.serveTestResults(.{
                .index = index,
                .flags = .{ .status = .fail, .fuzz = false, .log_err_count = 0, .leak_count = 0 },
            });
            return;
        }

        // Tell the build server we're starting the test.
        try self.server.serveStringMessage(.test_started, &.{});

        // Spawn Godot
        var child = try self.spawnGodot();
        defer _ = child.wait(self.io) catch {};

        // Send run_test command
        try self.sendCommand(&child, .{ .run_test = index });

        // Read response, collecting Godot output
        var godot_output: std.ArrayListUnmanaged(u8) = .empty;
        defer godot_output.deinit(self.allocator);

        // A crash or missing result must still report a failed test.
        var status: protocol.TestStatus = .fail;
        const response = try self.readResponse(&child, &godot_output);
        if (response) |resp| {
            defer {
                var r = resp;
                protocol.freeResponse(self.allocator, &r);
            }

            switch (resp) {
                .result => |result| {
                    status = result.status;
                    if (status == .fail) {
                        if (result.message) |message| std.debug.print("{s}\n", .{message});
                    }
                },
                .metadata => {},
            }
        }

        // Send exit command
        self.sendCommand(&child, .exit) catch {};

        // If test failed, print Godot's output to stderr
        if (status == .fail and godot_output.items.len > 0) {
            var buf: [4096]u8 = undefined;
            var stderr_writer = File.stderr().writerStreaming(self.io, &buf);
            stderr_writer.interface.writeAll(godot_output.items) catch {};
            stderr_writer.interface.flush() catch {};
        }

        // Send result to build system
        try self.server.serveTestResults(.{
            .index = index,
            .flags = .{
                .status = switch (status) {
                    .pass => .pass,
                    .fail => .fail,
                    .skip => .skip,
                },
                .fuzz = false,
                .log_err_count = 0,
                .leak_count = 0,
            },
        });
    }

    /// Send a command to the child process stdin
    fn sendCommand(self: *Runner, child: *std.process.Child, cmd: protocol.Command) !void {
        const stdin = child.stdin orelse return error.NoStdin;
        var buf: [4096]u8 = undefined;
        var writer = stdin.writerStreaming(self.io, &buf);
        try protocol.writeCommand(&writer.interface, cmd);
        try writer.interface.flush();
    }

    /// Read lines from Godot's stdout until we get an IPC response.
    /// Non-IPC lines are collected in godot_output for error display.
    fn readResponse(self: *Runner, child: *std.process.Child, godot_output: *std.ArrayListUnmanaged(u8)) !?protocol.Response {
        const stdout = child.stdout orelse return null;
        var line_buf: std.ArrayListUnmanaged(u8) = .empty;
        defer line_buf.deinit(self.allocator);

        var read_buf: [4096]u8 = undefined;
        var stdout_reader = stdout.readerStreaming(self.io, &read_buf);

        while (true) {
            // Read bytes until we find a newline
            line_buf.clearRetainingCapacity();
            while (true) {
                const byte_slice = stdout_reader.interface.take(1) catch return null;
                if (byte_slice.len == 0) return null; // EOF

                const byte = byte_slice[0];
                if (byte == '\n') break;
                try line_buf.append(self.allocator, byte);
            }

            const line = line_buf.items;

            // Check if this is an IPC message
            if (protocol.isIpcMessage(line)) {
                if (try protocol.parseResponse(self.allocator, line)) |resp| {
                    return resp;
                }
            } else {
                // Collect non-IPC output
                try godot_output.appendSlice(self.allocator, line);
                try godot_output.append(self.allocator, '\n');
            }
        }
    }

    fn spawnGodot(self: *Runner) !std.process.Child {
        // Copy existing environment and add test mode flag
        var env_map = try self.environ_map.clone(self.allocator);
        defer env_map.deinit();

        try env_map.put("GDZIG_TEST_MODE", "1");

        return std.process.spawn(self.io, .{
            .argv = &.{ options.godot_exe, "--headless", "--path", options.test_folder, "--quit-after", "60" },
            .environ_map = &env_map,
            .stdin = .pipe,
            .stdout = .pipe,
            .stderr = .inherit,
        });
    }
};

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const io = init.io;

    var stdin_buf: [4096]u8 = undefined;
    var stdout_buf: [4096]u8 = undefined;

    var stdin_reader = File.stdin().readerStreaming(io, &stdin_buf);
    var stdout_writer = File.stdout().writerStreaming(io, &stdout_buf);

    var runner = try Runner.init(allocator, io, init.environ_map, &stdin_reader.interface, &stdout_writer.interface);
    defer runner.deinit();

    try runner.run();
}

const std = @import("std");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;
const Io = std.Io;
const File = Io.File;
const ZigServer = std.zig.Server;

const protocol = @import("protocol.zig");
const options = @import("runner_options");
