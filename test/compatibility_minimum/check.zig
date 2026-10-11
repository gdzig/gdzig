//! Finite real-engine startup assertions, independent of Godot's exit status.
const Arguments = struct {
    godot: []const u8,
    project: []const u8,
    library: []const u8,
    minimum_text: []const u8,
    harness: bool = false,
    timeout_seconds: u32 = 20,

    fn fromArgs(args: *Args) !Arguments {
        const result: Arguments = .{
            .godot = args.required([]const u8, "godot") catch return error.MissingGodot,
            .project = args.required([]const u8, "project") catch return error.MissingProject,
            .library = args.required([]const u8, "library") catch return error.MissingLibrary,
            .minimum_text = args.required([]const u8, "compatibility-minimum") catch
                return error.MissingCompatibilityMinimum,
            .harness = (args.optional(bool, "harness") catch return error.InvalidHarness) orelse false,
            .timeout_seconds = (args.optional(u32, "timeout") catch return error.InvalidTimeout) orelse 20,
        };
        if (result.timeout_seconds == 0 or result.timeout_seconds > 300) return error.InvalidTimeout;
        try args.reject(.strict);
        return result;
    }
};

fn parseEngineVersion(text: []const u8) !Version {
    var components = std.mem.splitScalar(u8, std.mem.trim(u8, text, " \r\n\t"), '.');
    return .{
        .major = try std.fmt.parseInt(u32, components.next() orelse return error.InvalidEngineVersion, 10),
        .minor = try std.fmt.parseInt(u32, components.next() orelse return error.InvalidEngineVersion, 10),
        .patch = try std.fmt.parseInt(u32, components.next() orelse return error.InvalidEngineVersion, 10),
    };
}

/// Assert exact registration or rejection, independently of process exit code.
pub fn checkOutput(output: []const u8, actual: Version, minimum: ?Version, harness: bool) !bool {
    const effective = minimum orelse actual;
    const rejected = if (minimum) |floor| actual.lt(floor) else false;
    var diagnostic_buffer: [256]u8 = undefined;
    const diagnostic = try std.fmt.bufPrint(
        &diagnostic_buffer,
        "gdzig requires Godot {d}.{d}.{d} or newer; running {d}.{d}.{d}",
        .{ effective.major, effective.minor, effective.patch, actual.major, actual.minor, actual.patch },
    );
    const marker_prefix = "GDZIG_COMPATIBILITY_MINIMUM_REGISTERED actual=";
    const markers = std.mem.count(u8, output, marker_prefix);

    // An older runtime must be rejected before registration or IPC startup.
    if (rejected) {
        if (std.mem.indexOf(u8, output, diagnostic) == null or markers != 0) return error.InvalidRejection;
    } else {
        // Only the real IPC coordinator can prove harness acceptance.
        if (harness) return error.HarnessAcceptanceNotSupported;
        var marker_buffer: [256]u8 = undefined;
        const marker = try std.fmt.bufPrint(
            &marker_buffer,
            "{s}{d}.{d}.{d} effective={d}.{d}.{d}",
            .{
                marker_prefix,
                actual.major,
                actual.minor,
                actual.patch,
                effective.major,
                effective.minor,
                effective.patch,
            },
        );
        if (markers != 1 or std.mem.indexOf(u8, output, marker) == null) return error.InvalidRegistration;
        if (std.mem.indexOf(u8, output, "gdzig requires Godot") != null or
            std.mem.indexOf(u8, output, "Error loading extension") != null or
            std.mem.indexOf(u8, output, "Failed loading resource") != null)
        {
            return error.ExtensionLoadFailed;
        }
    }
    return rejected;
}

fn successful(term: std.process.Child.Term) bool {
    return switch (term) {
        .exited => |code| code == 0,
        else => false,
    };
}

fn runBounded(
    allocator: Allocator,
    io: std.Io,
    argv: []const []const u8,
    seconds: u32,
) !std.process.RunResult {
    // A fixed deadline cannot be extended by an engine producing more output.
    const timeout: std.Io.Timeout = .{
        .duration = .{ .raw = .fromSeconds(seconds), .clock = .awake },
    };
    return std.process.run(allocator, io, .{
        .argv = argv,
        .stdout_limit = .limited(16 * 1024 * 1024),
        .stderr_limit = .limited(16 * 1024 * 1024),
        .timeout = timeout.toDeadline(io),
    });
}

fn run(allocator: Allocator, io: std.Io, args: *Args) !void {
    // Validate all named arguments before filesystem or subprocess work.
    const arguments = try Arguments.fromArgs(args);
    const minimum = if (std.mem.eql(u8, arguments.minimum_text, "none"))
        null
    else
        try Version.parseStrict(arguments.minimum_text);
    const identity = try std.fmt.allocPrint(
        allocator,
        "GDZIG_COMPATIBILITY_MINIMUM_BINARY={s}\x00",
        .{arguments.minimum_text},
    );
    const bytes = try std.Io.Dir.cwd().readFileAlloc(
        io,
        arguments.library,
        allocator,
        .limited(128 * 1024 * 1024),
    );
    if (std.mem.indexOf(u8, bytes, identity) == null) return error.CompiledIdentityMismatch;

    // Identify the exact engine, then execute the installed fixture with a deadline.
    const version = try runBounded(
        allocator,
        io,
        &.{ arguments.godot, "--version" },
        arguments.timeout_seconds,
    );
    if (!successful(version.term)) return error.VersionQueryFailed;
    const actual = try parseEngineVersion(version.stdout);
    std.debug.print("engine_identity: {s}\n", .{std.mem.trim(u8, version.stdout, " \r\n")});
    const command = [_][]const u8{
        arguments.godot, "--headless", "--path", arguments.project, "--quit-after", "2",
    };
    std.debug.print("command: {any}\n", .{command});
    const result = try runBounded(allocator, io, &command, arguments.timeout_seconds);
    const output = try std.mem.concat(allocator, u8, &.{ result.stdout, result.stderr });
    std.debug.print("{s}", .{output});
    const rejected = try checkOutput(output, actual, minimum, arguments.harness);
    if (!rejected and !successful(result.term)) return error.AcceptedEngineFailed;
    std.debug.print("ASSERTION_OK rejected={} process_term={any} minimum={s}\n", .{
        rejected, result.term, arguments.minimum_text,
    });
}

/// Check a real engine against the exact compiled normal or rejected IPC fixture.
pub fn main(init: std.process.Init) void {
    var arena: std.heap.ArenaAllocator = .init(init.gpa);
    defer arena.deinit();
    const allocator = arena.allocator();
    var args = Args.init(allocator, init.minimal.args) catch |err|
        std.process.fatal("startup checker: {t}", .{err});
    defer args.deinit(allocator);
    run(allocator, init.io, &args) catch |err|
        std.process.fatal("startup checker: {t}", .{err});
}

fn parseFixture(argv: []const []const u8) !void {
    var args: Args = try .initSlice(std.testing.allocator, argv);
    defer args.deinit(std.testing.allocator);
    _ = try Arguments.fromArgs(&args);
}

test "matching and newer require exact single registration" {
    const marker = "GDZIG_COMPATIBILITY_MINIMUM_REGISTERED actual=4.7.2 effective=4.6.0\n";
    const actual: Version = .{ .major = 4, .minor = 7, .patch = 2 };
    try std.testing.expect(!try checkOutput(marker, actual, .@"4.6", false));
    try std.testing.expectError(error.InvalidRegistration, checkOutput("", actual, .@"4.6", false));
    try std.testing.expectError(error.InvalidRegistration, checkOutput(marker ++ marker, actual, .@"4.6", false));
    try std.testing.expectError(error.InvalidRegistration, checkOutput(marker, .@"4.6", .@"4.6", false));
    try std.testing.expectError(error.ExtensionLoadFailed, checkOutput(
        marker ++ "Error loading extension",
        actual,
        .@"4.6",
        false,
    ));
}

test "rejection needs exact diagnostic and no registration" {
    const actual: Version = .{ .major = 4, .minor = 6, .patch = 3 };
    const diagnostic = "gdzig requires Godot 4.7.0 or newer; running 4.6.3\n";
    try std.testing.expect(try checkOutput(diagnostic, actual, .@"4.7", false));
    try std.testing.expect(try checkOutput(diagnostic, actual, .@"4.7", true));
    try std.testing.expectError(error.InvalidRejection, checkOutput("extension failed", actual, .@"4.7", false));
    try std.testing.expectError(error.InvalidRejection, checkOutput(
        diagnostic ++ "GDZIG_COMPATIBILITY_MINIMUM_REGISTERED actual=4.6.3",
        actual,
        .@"4.7",
        false,
    ));
}

test "harness cannot claim acceptance without the actual IPC coordinator" {
    try std.testing.expectError(error.HarnessAcceptanceNotSupported, checkOutput("", .@"4.7", .@"4.7", true));
}

test "typed checker arguments reject duplicate timeout and unread tokens" {
    const required = .{
        "checker",                     "--godot=godot", "--project=project", "--library=fixture",
        "--compatibility-minimum=4.6",
    };
    try parseFixture(&required);
    try parseFixture(&(required ++ .{ "--harness", "--timeout=1" }));
    try std.testing.expectError(error.DuplicateArgument, parseFixture(
        &(required ++ .{ "--timeout=1", "--timeout=2" }),
    ));
    try std.testing.expectError(error.UnusedArgument, parseFixture(&(required ++ .{"--typo=value"})));
    try std.testing.expectError(error.UnusedPositional, parseFixture(&(required ++ .{"extra"})));
    try std.testing.expectError(error.InvalidTimeout, parseFixture(&(required ++ .{"--timeout=0"})));
    try std.testing.expectError(error.InvalidTimeout, parseFixture(&(required ++ .{"--timeout=301"})));
    try std.testing.expectError(error.InvalidTimeout, parseFixture(&(required ++ .{"--timeout=bad"})));
    try std.testing.expectError(error.MissingGodot, parseFixture(&.{"checker"}));
}

test "engine identity includes numeric version before release suffix" {
    const actual = try parseEngineVersion("4.7.2.stable.official.hash\n");
    try std.testing.expectEqual(@as(u32, 2), actual.patch);
    try std.testing.expectError(error.InvalidCharacter, parseEngineVersion("bad.version"));
}

const std = @import("std");
const Allocator = std.mem.Allocator;

const Args = @import("common").Args;
const Version = @import("common").Version;
