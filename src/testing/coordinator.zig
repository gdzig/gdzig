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
const json_ipc = @import("json_ipc.zig");
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
    test_mappings: std.ArrayList(TestMapping),
    string_bytes: std.ArrayList(u8),
    test_name_indices: std.ArrayList(u32),

    fn init(allocator: Allocator, in: *Io.Reader, out: *Io.Writer) !Runner {
        return .{
            .allocator = allocator,
            .server = try ZigServer.init(.{
                .in = in,
                .out = out,
                .zig_version = builtin.zig_version_string,
            }),
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

        // Spawn Godot with query_metadata command
        var child = try self.spawnGodot(folder, "query_metadata");
        defer {
            _ = child.wait() catch {};
        }

        // Read response from stdout, filtering out Godot noise
        var godot_output: std.ArrayListUnmanaged(u8) = .empty;
        defer godot_output.deinit(self.allocator);

        const response = try self.readResponse(&child, &godot_output);
        if (response) |resp| {
            defer {
                var r = resp;
                json_ipc.freeResponse(self.allocator, &r);
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
    }

    fn handleRunTest(self: *Runner, global_index: u32) !void {
        if (global_index >= self.test_mappings.items.len) {
            try self.server.serveTestResults(.{
                .index = global_index,
                .flags = .{ .fail = true, .skip = false, .leak = false, .fuzz = false },
            });
            return;
        }

        const mapping = self.test_mappings.items[global_index];
        const folder = options.test_folders[mapping.folder_index];

        // Format command with test index
        var cmd_buf: [64]u8 = undefined;
        const cmd = std.fmt.bufPrint(&cmd_buf, "run_test:{d}", .{mapping.local_index}) catch "run_test:0";

        // Spawn Godot with run_test command
        var child = try self.spawnGodot(folder, cmd);
        defer {
            _ = child.wait() catch {};
        }

        // Read response, collecting Godot output
        var godot_output: std.ArrayListUnmanaged(u8) = .empty;
        defer godot_output.deinit(self.allocator);

        var failed = true;
        const response = try self.readResponse(&child, &godot_output);
        if (response) |resp| {
            defer {
                var r = resp;
                json_ipc.freeResponse(self.allocator, &r);
            }

            switch (resp) {
                .result => |result| {
                    failed = !result.passed;
                },
                .metadata => {},
            }
        }

        // Wait for child to exit
        _ = child.wait() catch {};

        // If test failed, print Godot's output to stderr so user sees stack trace
        if (failed and godot_output.items.len > 0) {
            std.fs.File.stderr().writeAll(godot_output.items) catch {};
        }

        // Send result to build system
        try self.server.serveTestResults(.{
            .index = global_index,
            .flags = .{
                .fail = failed,
                .skip = false,
                .leak = false,
                .fuzz = false,
            },
        });
    }

    /// Read lines from Godot's stdout until we get an IPC response.
    /// Non-IPC lines are collected in godot_output for error display.
    fn readResponse(self: *Runner, child: *std.process.Child, godot_output: *std.ArrayListUnmanaged(u8)) !?json_ipc.Response {
        const stdout = child.stdout orelse return null;
        var line_buf: std.ArrayListUnmanaged(u8) = .empty;
        defer line_buf.deinit(self.allocator);

        while (true) {
            // Read bytes until we find a newline
            line_buf.clearRetainingCapacity();
            while (true) {
                var byte_buf: [1]u8 = undefined;
                const n = stdout.read(&byte_buf) catch return null;
                if (n == 0) return null; // EOF
                const byte = byte_buf[0];
                if (byte == '\n') break;
                try line_buf.append(self.allocator, byte);
            }

            const line = line_buf.items;

            // Check if this is an IPC message
            if (json_ipc.isIpcMessage(line)) {
                if (try json_ipc.parseResponse(self.allocator, line)) |resp| {
                    return resp;
                }
            } else {
                // Collect non-IPC output
                try godot_output.appendSlice(self.allocator, line);
                try godot_output.append(self.allocator, '\n');
            }
        }
    }

    fn spawnGodot(self: *Runner, folder: []const u8, cmd: []const u8) !std.process.Child {
        // Copy existing environment and add command
        var env_map = std.process.getEnvMap(self.allocator) catch return error.EnvironmentError;
        defer env_map.deinit();

        try env_map.put("GDZIG_TEST_CMD", cmd);

        var child = std.process.Child.init(
            &.{ options.godot_exe, "--headless", "-e", "--path", folder, "--quit-after", "60" },
            self.allocator,
        );
        child.env_map = &env_map;
        child.stdout_behavior = .Pipe;
        child.stderr_behavior = .Pipe;

        try child.spawn();
        return child;
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var stdin_buf: [4096]u8 = undefined;
    var stdout_buf: [4096]u8 = undefined;

    var stdin_reader = std.fs.File.Reader.initStreaming(std.fs.File.stdin(), &stdin_buf);
    var stdout_writer = std.fs.File.Writer.initStreaming(std.fs.File.stdout(), &stdout_buf);

    var runner = try Runner.init(allocator, &stdin_reader.interface, &stdout_writer.interface);
    defer runner.deinit();

    try runner.run();
}
