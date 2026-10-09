const Config = @This();

arch: Arch,
extension_api: File,
gdextension_interface: File,
input: Dir,
output: Dir,
precision: Precision,
verbosity: Verbosity,
io: Io,
godot_compatibility_minimum: ?Version = null,
compatibility_path: []const u8 = build_options.compatibility,
metadata: ?manifest.Manifest = null,

pub const Precision = enum {
    float,
    double,
};

pub const Arch = enum(u8) {
    @"32" = 32,
    @"64" = 64,
};

pub const Verbosity = enum {
    quiet,
    verbose,
};

pub const Arguments = struct {
    gdextension_interface: []const u8,
    extension_api: []const u8,
    input: []const u8,
    output: []const u8,
    arch: Arch,
    precision: Precision,
    verbosity: Verbosity,
    godot_compatibility_minimum: ?Version = null,
    compatibility: ?[]const u8 = null,
};

pub const usage = "Usage: gdzig-bindgen --gdextension-interface=<header> --extension-api=<json> --input=<mixins> --output=<bindings> --precision=<float|double> --architecture=<32|64> [--compatibility=<manifest.zon>] [--verbosity=<quiet|verbose>] [--godot-compatibility-minimum=<major.minor[.patch]>]\n";

/// Validate named values without opening files. Returned paths borrow from args.
pub fn fromArgs(args: *Args) !Arguments {
    if (try args.optional(bool, "help") orelse false) return error.HelpRequested;
    const minimum_text = args.optional([]const u8, "godot-compatibility-minimum") catch
        return error.InvalidCompatibilityMinimum;
    const minimum: ?Version = if (minimum_text) |text|
        Version.parseStrict(text) catch return error.InvalidCompatibilityMinimum
    else
        null;
    const result: Arguments = .{
        .gdextension_interface = args.required([]const u8, "gdextension-interface") catch return error.MissingGdextensionInterface,
        .extension_api = args.required([]const u8, "extension-api") catch return error.MissingExtensionApi,
        .input = args.required([]const u8, "input") catch return error.MissingInput,
        .output = args.required([]const u8, "output") catch return error.MissingOutput,
        .precision = args.required(Precision, "precision") catch |err| return switch (err) {
            error.InvalidValue => error.InvalidPrecision,
            else => error.MissingPrecision,
        },
        .arch = args.required(Arch, "architecture") catch |err| return switch (err) {
            error.InvalidValue => error.InvalidArchitecture,
            else => error.MissingArchitecture,
        },
        .verbosity = (args.optional(Verbosity, "verbosity") catch return error.InvalidVerbosity) orelse .quiet,
        .godot_compatibility_minimum = minimum,
        .compatibility = try args.optional([]const u8, "compatibility"),
    };
    try args.reject(.strict);
    return result;
}

/// Open validated input files and prepare the output directory.
pub fn load(io: Io, arguments: Arguments) !Config {
    const cwd = Dir.cwd();
    const gdextension_interface = try cwd.openFile(io, arguments.gdextension_interface, .{});
    errdefer gdextension_interface.close(io);
    const extension_api = try cwd.openFile(io, arguments.extension_api, .{});
    errdefer extension_api.close(io);
    const input = try cwd.createDirPathOpen(io, arguments.input, .{});
    errdefer input.close(io);
    const output = try cwd.createDirPathOpen(io, arguments.output, .{});
    return .{
        .arch = arguments.arch,
        .extension_api = extension_api,
        .gdextension_interface = gdextension_interface,
        .input = input,
        .output = output,
        .precision = arguments.precision,
        .verbosity = arguments.verbosity,
        .io = io,
        .godot_compatibility_minimum = arguments.godot_compatibility_minimum,
        .compatibility_path = arguments.compatibility orelse build_options.compatibility,
    };
}

/// Read the supplied manifest into memory owned by the caller's arena.
pub fn loadCompatibility(self: Config, allocator: std.mem.Allocator) !manifest.Manifest {
    if (self.metadata) |metadata| return metadata;
    const bytes = try Dir.cwd().readFileAlloc(
        self.io,
        self.compatibility_path,
        allocator,
        .limited(16 * 1024 * 1024),
    );
    var diagnostics: std.zon.parse.Diagnostics = undefined;
    const metadata = try std.zon.parse.fromSlice(manifest.Manifest, .{
        .gpa = allocator,
        .arena = allocator,
        .source = try allocator.dupeSentinel(u8, bytes, 0),
        .diagnostics = &diagnostics,
    });
    try compatibility.validateManifest(metadata);
    return metadata;
}

/// Return the API layout name corresponding to configured width and precision.
pub fn buildConfiguration(self: *Config) []const u8 {
    return switch (self.precision) {
        .double => switch (self.arch) {
            .@"32" => "double_32",
            .@"64" => "double_64",
        },
        .float => switch (self.arch) {
            .@"32" => "float_32",
            .@"64" => "float_64",
        },
    };
}

/// Close the files and directories owned by this configuration.
pub fn deinit(self: *Config) void {
    self.gdextension_interface.close(self.io);
    self.extension_api.close(self.io);
    self.input.close(self.io);
    self.output.close(self.io);
}

/// Open configured API headers and use the caller's directory for test output.
pub fn testConfig(io: Io, output: Dir) !Config {
    var headers = Dir.openDirAbsolute(io, build_options.headers, .{}) catch |err| {
        std.debug.print("Failed to open headers dir: {s}\n", .{@errorName(err)});
        return err;
    };
    defer headers.close(io);

    return Config{
        .arch = .@"32",
        .extension_api = try headers.openFile(io, "extension_api.json", .{}),
        .gdextension_interface = try headers.openFile(io, "gdextension_interface.h", .{}),
        .input = output,
        .output = output,
        .precision = .float,
        .verbosity = .quiet,
        .io = io,
    };
}

fn testArguments(argv: []const []const u8) !void {
    var args: Args = try .initSlice(std.testing.allocator, argv);
    defer args.deinit(std.testing.allocator);
    _ = try fromArgs(&args);
}

test "named bindgen options accept arbitrary ordering" {
    var args: Args = try .initSlice(std.testing.allocator, &.{
        "bindgen",           "--output=bindings",        "--input=mixins",                      "--architecture=64",
        "--precision=float", "--extension-api=api.json", "--gdextension-interface=interface.h",
    });
    defer args.deinit(std.testing.allocator);
    const arguments = try fromArgs(&args);
    try std.testing.expectEqualStrings("api.json", arguments.extension_api);
    try std.testing.expectEqualStrings("bindings", arguments.output);
    try std.testing.expectEqual(Arch.@"64", arguments.arch);
    try std.testing.expectEqual(Precision.float, arguments.precision);
    try std.testing.expectEqual(Verbosity.quiet, arguments.verbosity);
}

test "precision and architecture select all four API layouts" {
    const Case = struct {
        precision: Precision,
        arch: Arch,
        name: []const u8,
    };
    for ([_]Case{
        .{ .precision = .float, .arch = .@"32", .name = "float_32" },
        .{ .precision = .float, .arch = .@"64", .name = "float_64" },
        .{ .precision = .double, .arch = .@"32", .name = "double_32" },
        .{ .precision = .double, .arch = .@"64", .name = "double_64" },
    }) |case| {
        // SAFETY: buildConfiguration reads only these two initialized fields.
        var config: Config = undefined;
        config.arch = case.arch;
        config.precision = case.precision;
        try std.testing.expectEqualStrings(case.name, config.buildConfiguration());
    }
}

test "named bindgen options report help missing unknown duplicate and malformed values" {
    try std.testing.expectError(error.HelpRequested, testArguments(&.{ "bindgen", "--help" }));
    try std.testing.expectError(error.MissingGdextensionInterface, testArguments(&.{"bindgen"}));
    try std.testing.expectError(error.MissingGdextensionInterface, testArguments(&.{ "bindgen", "--gdextension-interface" }));
    try std.testing.expectError(error.MissingGdextensionInterface, testArguments(&.{ "bindgen", "--gdextension-interface=" }));
    try std.testing.expectError(error.UnusedArgument, testArguments(&.{ "bindgen", "--gdextension-interface=h", "--extension-api=a", "--input=i", "--output=o", "--precision=float", "--architecture=64", "--bogus=value" }));
    try std.testing.expectError(error.UnusedPositional, testArguments(&.{ "bindgen", "--gdextension-interface=h", "--extension-api=a", "--input=i", "--output=o", "--precision=float", "--architecture=64", "path" }));
    try std.testing.expectError(error.DuplicateArgument, testArguments(&.{ "bindgen", "--output=one", "--output=two" }));
    const Case = struct {
        precision: []const u8 = "--precision=float",
        architecture: []const u8 = "--architecture=64",
        verbosity: []const u8 = "--verbosity=quiet",
        failure: anyerror,
    };
    for ([_]Case{
        .{ .precision = "--precision=invalid", .failure = error.InvalidPrecision },
        .{ .architecture = "--architecture=invalid", .failure = error.InvalidArchitecture },
        .{ .verbosity = "--verbosity=invalid", .failure = error.InvalidVerbosity },
    }) |case| {
        var args: Args = try .initSlice(std.testing.allocator, &.{
            "bindgen",      "--gdextension-interface=h", "--extension-api=a", "--input=i", "--output=o",
            case.precision, case.architecture,           case.verbosity,
        });
        defer args.deinit(std.testing.allocator);
        try std.testing.expectError(case.failure, fromArgs(&args));
    }
}

test "required options distinguish missing values from invalid empty enums" {
    const argv = [_][]const u8{
        "bindgen",    "--gdextension-interface=h", "--extension-api=a", "--input=i",
        "--output=o", "--precision=float",         "--architecture=64",
    };
    const Case = struct {
        name: []const u8,
        missing_error: anyerror,
        empty_error: anyerror,
    };
    const cases = [_]Case{
        .{
            .name = "gdextension-interface",
            .missing_error = error.MissingGdextensionInterface,
            .empty_error = error.MissingGdextensionInterface,
        },
        .{
            .name = "extension-api",
            .missing_error = error.MissingExtensionApi,
            .empty_error = error.MissingExtensionApi,
        },
        .{
            .name = "input",
            .missing_error = error.MissingInput,
            .empty_error = error.MissingInput,
        },
        .{
            .name = "output",
            .missing_error = error.MissingOutput,
            .empty_error = error.MissingOutput,
        },
        .{
            .name = "precision",
            .missing_error = error.MissingPrecision,
            .empty_error = error.InvalidPrecision,
        },
        .{
            .name = "architecture",
            .missing_error = error.MissingArchitecture,
            .empty_error = error.InvalidArchitecture,
        },
    };
    for (cases, 1..) |case, index| {
        inline for ([_][]const u8{ "--{s}", "--{s}=" }) |format| {
            var changed = argv;
            const option = try std.fmt.allocPrint(std.testing.allocator, format, .{case.name});
            defer std.testing.allocator.free(option);
            changed[index] = option;
            const failure = if (std.mem.eql(u8, format, "--{s}=")) case.empty_error else case.missing_error;
            try std.testing.expectError(failure, testArguments(&changed));
        }
        var missing: std.ArrayList([]const u8) = .empty;
        defer missing.deinit(std.testing.allocator);
        for (argv, 0..) |token, i| {
            if (i != index) try missing.append(std.testing.allocator, token);
        }
        try std.testing.expectError(case.missing_error, testArguments(missing.items));
    }
}

test "named compatibility minimum is accepted before input files are opened" {
    var args: Args = try .initSlice(std.testing.allocator, &.{
        "bindgen",
        "--gdextension-interface=h",
        "--extension-api=a",
        "--input=i",
        "--output=o",
        "--precision=float",
        "--architecture=64",
        "--godot-compatibility-minimum=4.6",
    });
    defer args.deinit(std.testing.allocator);
    const arguments = try fromArgs(&args);
    const minimum = arguments.godot_compatibility_minimum.?;
    try std.testing.expectEqual(@as(u32, 4), minimum.major);
    try std.testing.expectEqual(@as(u32, 6), minimum.minor);
    try std.testing.expectEqual(@as(u32, 0), minimum.patch);
}

test "external compatibility input permits a syntactically valid uncached minimum" {
    var args: Args = try .initSlice(std.testing.allocator, &.{
        "bindgen",
        "--gdextension-interface=h",
        "--extension-api=a",
        "--input=i",
        "--output=o",
        "--precision=float",
        "--architecture=64",
        "--compatibility=measured.zon",
        "--godot-compatibility-minimum=4.5.0",
    });
    defer args.deinit(std.testing.allocator);
    const arguments = try fromArgs(&args);
    try std.testing.expectEqual(@as(u32, 5), arguments.godot_compatibility_minimum.?.minor);
    try std.testing.expectEqualStrings("measured.zon", arguments.compatibility.?);
}

test "external minimum grammar errors are named before file access" {
    for ([_][]const u8{ "", "4.5.0-dev", "4.5.4294967296", "4", "4.5.bad" }) |text| {
        const option = try std.fmt.allocPrint(
            std.testing.allocator,
            "--godot-compatibility-minimum={s}",
            .{text},
        );
        defer std.testing.allocator.free(option);
        try std.testing.expectError(error.InvalidCompatibilityMinimum, testArguments(&.{
            "bindgen",
            "--gdextension-interface=h",
            "--extension-api=a",
            "--input=i",
            "--output=o",
            "--precision=float",
            "--architecture=64",
            "--compatibility=measured.zon",
            option,
        }));
    }
}

const std = @import("std");
const Io = std.Io;
const Dir = Io.Dir;
const File = Io.File;

const Version = @import("common").Version;
const manifest = @import("compat").manifest;
const compatibility = @import("compatibility.zig");

const build_options = @import("build_options");
const Args = @import("common").Args;
