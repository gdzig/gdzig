//! Test coordinator that bridges the Zig build system and Godot processes.
//!
//! This executable:
//! 1. Speaks the std.zig.Server protocol with the build system (via stdin/stdout)
//! 2. Spawns Godot processes for each test folder
//! 3. Communicates with test harnesses via TCP using our protocol
//!
//! The coordinator maintains a mapping from global test indices to (folder, local_index) pairs.

const std = @import("std");
const builtin = @import("builtin");
const protocol = @import("protocol.zig");
const options = @import("runner_options");

const Allocator = std.mem.Allocator;
const Io = std.Io;
const ZigServer = std.zig.Server;
const ZigClient = std.zig.Client;

const log = std.log.scoped(.gdzig_testing);

pub const std_options: std.Options = .{
    // Set gdzig_testing scope to .warn by default (silent)
    // To enable debug logging, set GDZIG_TEST_DEBUG=1 environment variable
    .log_scope_levels = &.{
        .{ .scope = .gdzig_testing, .level = .warn },
    },
};

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
        log.debug("runner started, waiting for messages from build system", .{});
        log.debug("test_folders: {d}", .{options.test_folders.len});
        for (options.test_folders) |folder| {
            log.debug("  folder: {s}", .{folder});
        }

        while (true) {
            log.debug("waiting for message...", .{});
            const header = self.server.receiveMessage() catch |err| {
                log.debug("receiveMessage error: {}", .{err});
                // End of input from build system
                if (err == error.EndOfStream) break;
                return err;
            };

            log.debug("received message tag: {} (raw={d}) bytes_len={d}", .{ header.tag, @intFromEnum(header.tag), header.bytes_len });

            switch (header.tag) {
                .exit => {
                    log.debug("exit requested", .{});
                    break;
                },
                .query_test_metadata => {
                    log.debug("query_test_metadata requested", .{});
                    try self.handleQueryTestMetadata();
                },
                .run_test => {
                    const index = try self.server.receiveBody_u32();
                    log.debug("run_test requested: index={d}", .{index});
                    try self.handleRunTest(index);
                },
                else => {
                    log.debug("unknown message, skipping {d} bytes", .{header.bytes_len});
                    // Unknown message, skip body
                    _ = try self.server.in.discard(Io.Limit.limited(header.bytes_len));
                },
            }
        }
        log.debug("runner finished", .{});
    }

    fn handleQueryTestMetadata(self: *Runner) !void {
        log.debug("handleQueryTestMetadata: starting", .{});
        // Clear previous state
        self.test_mappings.clearRetainingCapacity();
        self.string_bytes.clearRetainingCapacity();
        self.test_name_indices.clearRetainingCapacity();

        // Collect metadata from each test folder
        for (options.test_folders, 0..) |folder, folder_idx| {
            try self.collectFolderMetadata(folder, @intCast(folder_idx));
        }
        log.debug("handleQueryTestMetadata: collected {d} tests", .{self.test_name_indices.items.len});

        // Build expected_panic_msgs (all zeros - we don't use panic expectations)
        const expected_panic_msgs = try self.allocator.alloc(u32, self.test_name_indices.items.len);
        defer self.allocator.free(expected_panic_msgs);
        @memset(expected_panic_msgs, 0);

        // Send metadata to build system
        log.debug("handleQueryTestMetadata: sending {d} tests to build system", .{self.test_name_indices.items.len});

        try self.server.serveTestMetadata(.{
            .names = self.test_name_indices.items,
            .expected_panic_msgs = expected_panic_msgs,
            .string_bytes = self.string_bytes.items,
        });
        log.debug("handleQueryTestMetadata: sent metadata", .{});
    }

    fn collectFolderMetadata(self: *Runner, folder: []const u8, folder_idx: u32) !void {
        log.debug("collectFolderMetadata: folder={s} idx={d}", .{ folder, folder_idx });

        // Extract folder name for prefixing
        const folder_name = std.fs.path.basename(folder);
        log.debug("  folder_name={s}", .{folder_name});

        // Start TCP listener
        const address = std.net.Address.initIp4(.{ 127, 0, 0, 1 }, 0);
        var listener = try address.listen(.{ .reuse_address = true });
        defer listener.stream.close();

        const port = listener.listen_address.getPort();
        log.debug("  listening on port {d}", .{port});

        // Spawn Godot
        log.debug("  spawning godot: {s}", .{options.godot_exe});
        var child = try self.spawnGodot(folder, port);
        defer {
            // Collect and log Godot output before waiting
            const output = self.collectGodotOutput(&child) catch "";
            defer if (output.len > 0) self.allocator.free(output);
            if (output.len > 0) {
                log.debug("  godot output:\n{s}", .{output});
            }
            _ = child.wait() catch {};
        }
        log.debug("  godot spawned, pid={d}", .{child.id});

        // Accept connection
        log.debug("  waiting for connection...", .{});
        var conn = try listener.accept();
        defer conn.stream.close();
        log.debug("  connection accepted!", .{});

        // Set up buffered I/O
        var read_buf: [4096]u8 = undefined;
        var write_buf: [4096]u8 = undefined;
        var reader = std.net.Stream.Reader.init(conn.stream, &read_buf);
        var writer = std.net.Stream.Writer.init(conn.stream, &write_buf);

        // Query test metadata
        log.debug("  sending query_test_metadata to extension...", .{});
        try protocol.writeMessage(&writer.interface, .query_test_metadata, &.{});
        log.debug("  sent query_test_metadata, waiting for response...", .{});

        // Read response
        var msg_buf: [65536]u8 = undefined;
        const msg = try protocol.readMessage(reader.interface(), &msg_buf);
        log.debug("  received response from extension, tag={}", .{msg.tag});

        if (msg.tag != .test_metadata) {
            return error.UnexpectedResponse;
        }

        // Parse test names and add to our mappings
        var iter = protocol.decodeTestMetadata(msg.payload);
        var local_idx: u32 = 0;
        while (iter.next()) |name| {
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
                .local_index = local_idx,
            });

            local_idx += 1;
        }

        // Tell extension to exit
        try protocol.writeMessage(&writer.interface, .exit, &.{});
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

        // Start TCP listener
        const address = std.net.Address.initIp4(.{ 127, 0, 0, 1 }, 0);
        var listener = try address.listen(.{ .reuse_address = true });
        defer listener.stream.close();

        const port = listener.listen_address.getPort();

        // Spawn Godot
        var child = try self.spawnGodot(folder, port);
        errdefer {
            _ = child.wait() catch {};
        }

        // Accept connection
        var conn = try listener.accept();
        defer conn.stream.close();

        // Set up buffered I/O
        var read_buf: [4096]u8 = undefined;
        var write_buf: [4096]u8 = undefined;
        var reader = std.net.Stream.Reader.init(conn.stream, &read_buf);
        var writer = std.net.Stream.Writer.init(conn.stream, &write_buf);

        // Send run_test command
        const run_payload = protocol.encodeRunTest(mapping.local_index);
        try protocol.writeMessage(&writer.interface, .run_test, &run_payload);

        // Read result
        var msg_buf: [65536]u8 = undefined;
        const msg = try protocol.readMessage(reader.interface(), &msg_buf);

        var failed = false;
        if (msg.tag != .test_result) {
            failed = true;
        } else {
            const result = protocol.decodeTestResult(msg.payload);
            failed = !result.passed;
        }

        // Tell extension to exit
        try protocol.writeMessage(&writer.interface, .exit, &.{});

        // Collect Godot output (contains stack traces on failure)
        const output = self.collectGodotOutput(&child) catch "";
        defer if (output.len > 0) self.allocator.free(output);

        // Wait for child to exit
        _ = child.wait() catch {};

        // If test failed, print Godot's output to stderr so user sees stack trace
        if (failed and output.len > 0) {
            std.fs.File.stderr().writeAll(output) catch {};
        }

        log.debug("godot output:\n{s}", .{output});

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

    /// Collect any remaining output from a Godot child process
    fn collectGodotOutput(self: *Runner, child: *std.process.Child) ![]const u8 {
        var output: std.ArrayListUnmanaged(u8) = .empty;
        errdefer output.deinit(self.allocator);

        // Read stdout
        if (child.stdout) |stdout| {
            var buf: [4096]u8 = undefined;
            while (true) {
                const n = stdout.read(&buf) catch break;
                if (n == 0) break;
                try output.appendSlice(self.allocator, buf[0..n]);
            }
        }

        // Read stderr
        if (child.stderr) |stderr| {
            var buf: [4096]u8 = undefined;
            while (true) {
                const n = stderr.read(&buf) catch break;
                if (n == 0) break;
                try output.appendSlice(self.allocator, buf[0..n]);
            }
        }

        return output.toOwnedSlice(self.allocator);
    }

    fn spawnGodot(self: *Runner, folder: []const u8, port: u16) !std.process.Child {
        _ = self;

        // Format port as string
        var port_buf: [8]u8 = undefined;
        const port_str = std.fmt.bufPrint(&port_buf, "{d}", .{port}) catch unreachable;

        var env_map = std.process.EnvMap.init(std.heap.page_allocator);
        defer env_map.deinit();

        // Copy existing environment
        var env_iter = try std.process.getEnvMap(std.heap.page_allocator);
        defer env_iter.deinit();

        var it = env_iter.iterator();
        while (it.next()) |entry| {
            try env_map.put(entry.key_ptr.*, entry.value_ptr.*);
        }

        // Add our port
        try env_map.put("GDZIG_TEST_PORT", port_str);

        var child = std.process.Child.init(
            &.{ options.godot_exe, "--headless", "--quiet", "-e", "--path", folder, "--quit-after", "60" },
            std.heap.page_allocator,
        );
        child.env_map = &env_map;
        // CRITICAL: Don't let Godot's stdout/stderr pollute our protocol stream
        // Capture them so we can display on test failure
        child.stdout_behavior = .Pipe;
        child.stderr_behavior = .Pipe;

        try child.spawn();
        return child;
    }
};

pub fn main() !void {
    // Log command line args
    var args_iter = std.process.args();
    var arg_idx: usize = 0;
    while (args_iter.next()) |arg| {
        log.debug("arg[{d}]: {s}", .{ arg_idx, arg });
        arg_idx += 1;
    }

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Set up stdin/stdout for build system communication
    var stdin_buf: [4096]u8 = undefined;
    var stdout_buf: [4096]u8 = undefined;

    var stdin_reader = std.fs.File.Reader.initStreaming(std.fs.File.stdin(), &stdin_buf);
    var stdout_writer = std.fs.File.Writer.initStreaming(std.fs.File.stdout(), &stdout_buf);

    var runner = try Runner.init(allocator, &stdin_reader.interface, &stdout_writer.interface);
    defer runner.deinit();
    log.debug("runner initialized", .{});

    try runner.run();
}
