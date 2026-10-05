const Config = @This();

arch: Arch,
extension_api: File,
gdextension_interface: File,
input: Dir,
output: Dir,
precision: Precision,
verbosity: Verbosity,
io: Io,

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
};

pub const usage = "Usage: gdzig-bindgen --gdextension-interface=<header> --extension-api=<json> --input=<mixins> --output=<bindings> --precision=<float|double> --architecture=<32|64> [--verbosity=<quiet|verbose>]\n";

/// Validate named values without opening files. Returned paths borrow from args.
pub fn fromArgs(args: Args) !Arguments {
    if (try args.flag("help")) return error.HelpRequested;
    try args.rejectUnknown(&.{
        "help",      "gdextension-interface", "extension-api", "input", "output",
        "precision", "architecture",          "verbosity",
    });
    if (args.positionals.items.len != 0) return error.UnexpectedPositional;

    const header = args.required("gdextension-interface") catch return error.MissingGdextensionInterface;
    const api = args.required("extension-api") catch return error.MissingExtensionApi;
    const input = args.required("input") catch return error.MissingInput;
    const output = args.required("output") catch return error.MissingOutput;
    const precision_text = args.required("precision") catch return error.MissingPrecision;
    const precision = std.meta.stringToEnum(Precision, precision_text) orelse return error.InvalidPrecision;
    const arch_text = args.required("architecture") catch return error.MissingArchitecture;
    const arch = std.meta.stringToEnum(Arch, arch_text) orelse return error.InvalidArchitecture;
    const verbosity_text = try args.value("verbosity") orelse "quiet";
    const verbosity = std.meta.stringToEnum(Verbosity, verbosity_text) orelse return error.InvalidVerbosity;

    return .{
        .gdextension_interface = header,
        .extension_api = api,
        .input = input,
        .output = output,
        .arch = arch,
        .precision = precision,
        .verbosity = verbosity,
    };
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
    };
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
    _ = try fromArgs(args);
}

test "named bindgen options accept arbitrary ordering" {
    var args: Args = try .initSlice(std.testing.allocator, &.{
        "bindgen",           "--output=bindings",        "--input=mixins",                      "--architecture=64",
        "--precision=float", "--extension-api=api.json", "--gdextension-interface=interface.h",
    });
    defer args.deinit(std.testing.allocator);
    const arguments = try fromArgs(args);
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
    try std.testing.expectError(error.UnknownArgument, testArguments(&.{ "bindgen", "--bogus=value" }));
    try std.testing.expectError(error.UnexpectedPositional, testArguments(&.{ "bindgen", "path" }));
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
        try std.testing.expectError(case.failure, fromArgs(args));
    }
}

test "every required option has a specific missing error for absent bare and empty values" {
    const argv = [_][]const u8{
        "bindgen",    "--gdextension-interface=h", "--extension-api=a", "--input=i",
        "--output=o", "--precision=float",         "--architecture=64",
    };
    const names = [_][]const u8{ "gdextension-interface", "extension-api", "input", "output", "precision", "architecture" };
    const errors = [_]anyerror{
        error.MissingGdextensionInterface, error.MissingExtensionApi, error.MissingInput,
        error.MissingOutput,               error.MissingPrecision,    error.MissingArchitecture,
    };
    for (names, errors, 1..) |name, expected, index| {
        inline for ([_][]const u8{ "--{s}", "--{s}=" }) |format| {
            var changed = argv;
            const option = try std.fmt.allocPrint(std.testing.allocator, format, .{name});
            defer std.testing.allocator.free(option);
            changed[index] = option;
            try std.testing.expectError(expected, testArguments(&changed));
        }
        var missing: std.ArrayList([]const u8) = .empty;
        defer missing.deinit(std.testing.allocator);
        for (argv, 0..) |token, i| {
            if (i != index) try missing.append(std.testing.allocator, token);
        }
        try std.testing.expectError(expected, testArguments(missing.items));
    }
}

const std = @import("std");
const Io = std.Io;
const Dir = Io.Dir;
const File = Io.File;

const build_options = @import("build_options");
const Args = @import("common").Args;
