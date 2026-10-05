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

pub const usage = "Usage: gdzig-bindgen --gdextension-interface <header> --extension-api <json> --input <mixins> --output <bindings> --precision <float|double> --architecture <32|64> [--verbosity <quiet|verbose>]\n";

const Option = enum {
    @"gdextension-interface",
    @"extension-api",
    input,
    output,
    precision,
    architecture,
    verbosity,
};

/// Parse named options once and validate all values before opening any files.
pub fn parseArgs(args: []const []const u8) !Arguments {
    var slots: [@typeInfo(Option).@"enum".field_names.len]?[]const u8 = @splat(null);
    var i: usize = 0;
    while (i < args.len) : (i += 2) {
        const flag = args[i];
        if (std.mem.eql(u8, flag, "--help")) return error.HelpRequested;
        // CLI names deliberately use hyphens, while Config fields use snake case.
        if (!std.mem.startsWith(u8, flag, "--")) return error.UnknownOption;
        const option = std.meta.stringToEnum(Option, flag[2..]) orelse return error.UnknownOption;
        if (slots[@backingInt(option)] != null) return error.DuplicateOption;
        if (i + 1 >= args.len or std.mem.startsWith(u8, args[i + 1], "--")) return error.MissingOptionValue;
        slots[@backingInt(option)] = args[i + 1];
    }
    const header = try requiredOption(&slots, .@"gdextension-interface");
    const api = try requiredOption(&slots, .@"extension-api");
    const input = try requiredOption(&slots, .input);
    const output = try requiredOption(&slots, .output);

    const precision_text = slots[@backingInt(Option.precision)] orelse return error.MissingOption;
    const precision = std.meta.stringToEnum(Precision, precision_text) orelse return error.InvalidPrecision;
    const arch_text = slots[@backingInt(Option.architecture)] orelse return error.MissingOption;
    const arch = std.meta.stringToEnum(Arch, arch_text) orelse return error.InvalidArchitecture;
    const verbosity_text = slots[@backingInt(Option.verbosity)] orelse "quiet";
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

fn requiredOption(slots: []const ?[]const u8, option: Option) ![]const u8 {
    const value = slots[@backingInt(option)] orelse return error.MissingOption;
    if (value.len == 0) return error.MissingOptionValue;
    return value;
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

test "named bindgen options accept arbitrary ordering" {
    const arguments = try parseArgs(&.{ "--output", "bindings", "--input", "mixins", "--architecture", "64", "--precision", "float", "--extension-api", "api.json", "--gdextension-interface", "interface.h" });
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
    try std.testing.expectError(error.HelpRequested, parseArgs(&.{"--help"}));
    try std.testing.expectError(error.MissingOption, parseArgs(&.{}));
    try std.testing.expectError(error.MissingOptionValue, parseArgs(&.{"--output"}));
    try std.testing.expectError(error.MissingOptionValue, parseArgs(&.{ "--output", "--input", "mixins" }));
    try std.testing.expectError(error.UnknownOption, parseArgs(&.{ "--bogus", "value" }));
    try std.testing.expectError(error.DuplicateOption, parseArgs(&.{ "--output", "one", "--output", "two" }));
}

const std = @import("std");
const Io = std.Io;
const Dir = Io.Dir;
const File = Io.File;

const build_options = @import("build_options");
