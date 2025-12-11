const TestCase = struct {
    name: []const u8,
    project_path: []const u8,
    script: ?[]const u8 = null,
};

var stdin_buffer: [4096]u8 = undefined;
var stdout_buffer: [4096]u8 = undefined;
var log_err_count: usize = 0;

pub const std_options: std.Options = .{
    .logFn = log,
};

pub fn main() void {
    @disableInstrumentation();

    const allocator = std.heap.page_allocator;
    const args = std.process.argsAlloc(allocator) catch
        @panic("unable to parse command line args");

    var listen = false;
    var godot_path: []const u8 = "godot";
    var tests: std.ArrayListUnmanaged(TestCase) = .empty;

    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        if (std.mem.eql(u8, arg, "--listen=-")) {
            // Only use IPC mode if stdin is not a TTY (i.e., connected to build system)
            listen = !std.fs.File.stdin().isTty();
        } else if (std.mem.startsWith(u8, arg, "--godot=")) {
            godot_path = arg["--godot=".len..];
        } else if (std.mem.eql(u8, arg, "--test")) {
            // --test <name> <project_path> [--script <script>]
            if (i + 2 >= args.len) @panic("--test requires name and project_path");
            const name = args[i + 1];
            const project_path = args[i + 2];
            i += 2;

            var script: ?[]const u8 = null;
            if (i + 2 < args.len and std.mem.eql(u8, args[i + 1], "--script")) {
                script = args[i + 2];
                i += 2;
            }

            tests.append(allocator, .{
                .name = name,
                .project_path = project_path,
                .script = script,
            }) catch @panic("OOM");
        }
    }

    if (tests.items.len == 0) {
        @panic("no tests specified");
    }

    if (listen) {
        mainServer(allocator, tests.items, godot_path) catch |e| {
            std.debug.print("runner error: {s}\n", .{@errorName(e)});
            std.process.exit(1);
        };
    } else {
        mainTerminal(allocator, tests.items, godot_path);
    }
}

fn mainServer(allocator: std.mem.Allocator, tests: []const TestCase, godot_path: []const u8) !void {
    var stdin_reader = std.fs.File.stdin().readerStreaming(&stdin_buffer);
    var stdout_writer = std.fs.File.stdout().writerStreaming(&stdout_buffer);
    var server = try std.zig.Server.init(.{
        .in = &stdin_reader.interface,
        .out = &stdout_writer.interface,
        .zig_version = builtin.zig_version_string,
    });

    while (true) {
        const hdr = try server.receiveMessage();
        switch (hdr.tag) {
            .exit => {
                std.process.exit(0);
            },
            .query_test_metadata => {
                var string_bytes: std.ArrayListUnmanaged(u8) = .empty;
                defer string_bytes.deinit(allocator);
                try string_bytes.append(allocator, 0); // Reserve 0 for null

                const names = try allocator.alloc(u32, tests.len);
                defer allocator.free(names);
                const expected_panic_msgs = try allocator.alloc(u32, tests.len);
                defer allocator.free(expected_panic_msgs);

                for (tests, names, expected_panic_msgs) |test_case, *name, *expected_panic_msg| {
                    name.* = @intCast(string_bytes.items.len);
                    try string_bytes.appendSlice(allocator, test_case.name);
                    try string_bytes.append(allocator, 0);
                    expected_panic_msg.* = 0;
                }

                try server.serveTestMetadata(.{
                    .names = names,
                    .expected_panic_msgs = expected_panic_msgs,
                    .string_bytes = string_bytes.items,
                });
            },
            .run_test => {
                log_err_count = 0;
                const index = try server.receiveBody_u32();
                const test_case = tests[index];

                const result = runGodotTest(allocator, godot_path, test_case);

                // Print stderr to stderr so build system can capture it
                if (result.stderr) |stderr_output| {
                    std.debug.print("{s}", .{stderr_output});
                }

                try server.serveTestResults(.{
                    .index = index,
                    .flags = .{
                        .fail = result.fail,
                        .skip = false,
                        .leak = false,
                        .fuzz = false,
                        .log_err_count = std.math.lossyCast(
                            @FieldType(std.zig.Server.Message.TestResults.Flags, "log_err_count"),
                            log_err_count,
                        ),
                    },
                });
            },
            else => {
                std.debug.print("unsupported message: {x}\n", .{@intFromEnum(hdr.tag)});
                std.process.exit(1);
            },
        }
    }
}

fn mainTerminal(allocator: std.mem.Allocator, tests: []const TestCase, godot_path: []const u8) void {
    var ok_count: usize = 0;
    var fail_count: usize = 0;

    for (tests, 0..) |test_case, i| {
        std.debug.print("{d}/{d} {s}...", .{ i + 1, tests.len, test_case.name });
        const result = runGodotTest(allocator, godot_path, test_case);
        if (result.fail) {
            fail_count += 1;
            std.debug.print("FAIL\n", .{});
            if (result.stderr) |stderr| {
                std.debug.print("{s}\n", .{stderr});
            }
        } else {
            ok_count += 1;
            std.debug.print("OK\n", .{});
        }
    }

    if (ok_count == tests.len) {
        std.debug.print("All {d} tests passed.\n", .{ok_count});
    } else {
        std.debug.print("{d} passed; {d} failed.\n", .{ ok_count, fail_count });
    }

    if (fail_count != 0) {
        std.process.exit(1);
    }
}

const TestResult = struct {
    fail: bool,
    stderr: ?[]const u8,
};

fn runGodotTest(allocator: std.mem.Allocator, godot_path: []const u8, test_case: TestCase) TestResult {
    var argv: std.ArrayListUnmanaged([]const u8) = .empty;
    defer argv.deinit(allocator);

    argv.appendSlice(allocator, &.{ godot_path, "--headless", "--quiet", "--no-header", "--quit" }) catch return .{ .fail = true, .stderr = null };

    if (test_case.script) |script| {
        argv.appendSlice(allocator, &.{ "--script", script }) catch return .{ .fail = true, .stderr = null };
    }

    argv.appendSlice(allocator, &.{ "--path", test_case.project_path }) catch return .{ .fail = true, .stderr = null };

    var child = std.process.Child.init(argv.items, allocator);
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Pipe;

    child.spawn() catch |e| {
        std.debug.print("failed to spawn godot: {s}\n", .{@errorName(e)});
        return .{ .fail = true, .stderr = null };
    };

    // Collect stdout and stderr
    var stdout_list: std.ArrayListUnmanaged(u8) = .empty;
    var stderr_list: std.ArrayListUnmanaged(u8) = .empty;
    defer stdout_list.deinit(allocator);
    defer stderr_list.deinit(allocator);

    child.collectOutput(allocator, &stdout_list, &stderr_list, 10 * 1024 * 1024) catch |e| {
        std.debug.print("failed to collect output: {s}\n", .{@errorName(e)});
        return .{ .fail = true, .stderr = null };
    };

    const term = child.wait() catch |e| {
        std.debug.print("failed to wait for godot: {s}\n", .{@errorName(e)});
        return .{ .fail = true, .stderr = null };
    };

    const success = term == .Exited and term.Exited == 0;
    const stderr = if (stderr_list.items.len > 0) stderr_list.toOwnedSlice(allocator) catch null else null;
    return .{ .fail = !success, .stderr = if (!success) stderr else null };
}

fn log(
    comptime message_level: std.log.Level,
    comptime scope: @Type(.enum_literal),
    comptime format: []const u8,
    args: anytype,
) void {
    @disableInstrumentation();
    if (@intFromEnum(message_level) <= @intFromEnum(std.log.Level.err)) {
        log_err_count +|= 1;
    }
    if (@intFromEnum(message_level) <= @intFromEnum(std.testing.log_level)) {
        std.debug.print(
            "[" ++ @tagName(scope) ++ "] (" ++ @tagName(message_level) ++ "): " ++ format ++ "\n",
            args,
        );
    }
}

const std = @import("std");
const builtin = @import("builtin");
