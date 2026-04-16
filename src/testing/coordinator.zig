//! Test coordinator that bridges the Zig build system and Godot processes.
//!
//! This executable:
//! 1. Speaks the std.zig.Server protocol with the build system (via stdin/stdout)
//! 2. Spawns Godot processes for each test folder
//! 3. Communicates with test harnesses via JSON IPC over stdin/stdout pipes
//!
//! The coordinator maintains a mapping from global test indices to (folder, local_index) pairs.

const std = @import("std");
const builtin = @import("builtin");
const protocol = @import("protocol.zig");
const options = @import("runner_options");

const Allocator = std.mem.Allocator;
const Io = std.Io;
const ZigServer = std.zig.Server;

/// Mapping from global test index to folder and local index
const TestMapping = struct {
    folder_index: u32,
    local_index: u32,
};

/// State for the test runner
const Runner = struct {
    allocator: Allocator,
    server: ZigServer,
    io: Io,
    test_mappings: std.ArrayListUnmanaged(TestMapping),
    string_bytes: std.ArrayListUnmanaged(u8),
    test_name_indices: std.ArrayListUnmanaged(u32),

    fn init(allocator: Allocator, in: *Io.Reader, out: *Io.Writer) !Runner {
        const server = try ZigServer.init(.{
            .in = in,
            .out = out,
            .zig_version = builtin.zig_version_string,
        });

        return .{
            .allocator = allocator,
            .server = server,
            .io = undefined,
            .test_mappings = .empty,
            .string_bytes = .empty,
            .test_name_indices = .empty,
        };
    }

    fn deinit(self: *Runner) void {
        self.test_mappings.deinit(self.allocator);
        self.string_bytes.deinit(self.allocator);
        self.test_name_indices.deinit(self.allocator);
    }

    fn run(self: *Runner) !void {
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
        // Clear previous state
        self.test_mappings.clearRetainingCapacity();
        self.string_bytes.clearRetainingCapacity();
        self.test_name_indices.clearRetainingCapacity();

        // Collect metadata from each test folder
        for (options.test_folders, 0..) |folder, folder_idx| {
            try self.collectFolderMetadata(folder, @intCast(folder_idx));
        }

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

    fn collectFolderMetadata(self: *Runner, folder: []const u8, folder_idx: u32) !void {
        const folder_name = std.fs.path.basename(folder);

        // Spawn Godot with stdin/stdout piped
        var child = try self.spawnGodot(folder);
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
                    for (tests, 0..) |name, i| {
                        // Record the string index before adding the prefixed name
                        const string_idx: u32 = @intCast(self.string_bytes.items.len);
                        try self.test_name_indices.append(self.allocator, string_idx);

                        // Add prefixed name: "folder.test name\0"
                        try self.string_bytes.appendSlice(self.allocator, folder_name);
                        try self.string_bytes.append(self.allocator, '.');
                        try self.string_bytes.appendSlice(self.allocator, name);
                        try self.string_bytes.append(self.allocator, 0);

                        // Record mapping
                        try self.test_mappings.append(self.allocator, .{
                            .folder_index = folder_idx,
                            .local_index = @intCast(i),
                        });
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

    fn handleRunTest(self: *Runner, global_index: u32) !void {
        if (global_index >= self.test_mappings.items.len) {
            try self.server.serveTestResults(.{
                .index = global_index,
                .flags = .{ .status = .fail, .fuzz = false, .log_err_count = 0, .leak_count = 0 },
            });
            return;
        }

        const mapping = self.test_mappings.items[global_index];
        const folder = options.test_folders[mapping.folder_index];

        // Notify build system that the test has started
        try self.server.serveStringMessage(.test_started, &.{});

        // Spawn Godot
        var child = try self.spawnGodot(folder);

        // Send run_test command
        try self.sendCommand(&child, .{ .run_test = mapping.local_index });

        // Read response, collecting Godot output
        var godot_output: std.ArrayListUnmanaged(u8) = .empty;
        defer godot_output.deinit(self.allocator);

        var failed = true;
        const response = try self.readResponse(&child, &godot_output);
        if (response) |resp| {
            defer {
                var r = resp;
                protocol.freeResponse(self.allocator, &r);
            }

            switch (resp) {
                .result => |result| {
                    failed = !result.passed;
                },
                .metadata => {},
            }
        }

        // Send exit command
        self.sendCommand(&child, .exit) catch {};

        // Wait for child to exit
        _ = child.wait(self.io) catch {};

        // If test failed, print Godot's output to stderr so user sees stack trace
        if (failed and godot_output.items.len > 0) {
            var stderr_buf: [4096]u8 = undefined;
            var stderr_writer = std.Io.File.Writer.initStreaming(std.Io.File.stderr(), self.io, &stderr_buf);
            stderr_writer.interface.writeAll(godot_output.items) catch {};
            stderr_writer.interface.flush() catch {};
        }

        // Send result to build system
        try self.server.serveTestResults(.{
            .index = global_index,
            .flags = .{
                .status = if (failed) .fail else .pass,
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
        var writer = std.Io.File.Writer.initStreaming(stdin, self.io, &buf);
        try protocol.writeCommand(&writer.interface, cmd);
        try writer.interface.flush();
    }

    /// Read lines from Godot's stdout until we get an IPC response.
    /// Non-IPC lines are collected in godot_output for error display.
    /// Uses direct read() to avoid Windows pipe issues with pread/overlapped I/O.
    /// See: https://github.com/ziglang/zig/issues/25291
    fn readResponse(self: *Runner, child: *std.process.Child, godot_output: *std.ArrayListUnmanaged(u8)) !?protocol.Response {
        const stdout_file = child.stdout orelse return null;
        var read_buf: [4096]u8 = undefined;
        var stdout_reader = std.Io.File.Reader.initStreaming(stdout_file, self.io, &read_buf);
        var line_buf: std.ArrayListUnmanaged(u8) = .empty;
        defer line_buf.deinit(self.allocator);

        while (true) {
            // Read bytes until we find a newline
            line_buf.clearRetainingCapacity();
            while (true) {
                const byte = stdout_reader.interface.takeByte() catch |err| {
                    if (err == error.EndOfStream) return null;
                    return err;
                };
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

    fn spawnGodot(self: *Runner, folder: []const u8) !std.process.Child {
        // Copy existing environment and add test mode flag
        var env_map = try std.process.Environ.createMap(.{ .block = .global }, self.allocator);
        defer env_map.deinit();

        try env_map.put("GDZIG_TEST_MODE", "1");

        return try std.process.spawn(self.io, .{
            .argv = &.{ options.godot_exe, "--headless", "--path", folder, "--quit-after", "60" },
            .environ_map = &env_map,
            .stdin = .pipe,
            .stdout = .pipe,
            .stderr = .pipe,
        });
    }
};

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const io = init.io;

    var stdin_buf: [4096]u8 = undefined;
    var stdout_buf: [4096]u8 = undefined;

    var stdin_reader = std.Io.File.Reader.initStreaming(std.Io.File.stdin(), io, &stdin_buf);
    var stdout_writer = std.Io.File.Writer.initStreaming(std.Io.File.stdout(), io, &stdout_buf);

    var runner = try Runner.init(allocator, &stdin_reader.interface, &stdout_writer.interface);
    defer runner.deinit();
    runner.io = io;

    try runner.run();
}
