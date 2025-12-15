const std = @import("std");
const build_options = @import("build_options");
const fs = std.fs;
const Dir = std.fs.Dir;

const Config = @This();

arch: Arch,
extension_api: fs.File,
gdextension_interface: fs.File,
input: fs.Dir,
output: fs.Dir,
precision: Precision,
verbosity: Verbosity,

pub const Arch = enum {
    double,
    float,
};

pub const Precision = enum(u8) {
    @"32" = 32,
    @"64" = 64,
};

pub const Verbosity = enum {
    quiet,
    verbose,
};

pub fn loadFromArgs(args: [][:0]u8) !Config {
    const cwd = std.fs.cwd();

    // args[1]: path to gdextension_interface.h
    // args[2]: path to extension_api.json
    const gdextension_interface = try cwd.openFile(args[1], .{});
    const extension_api = try cwd.openFile(args[2], .{});

    const input = try cwd.makeOpenPath(args[3], .{});
    const output = try cwd.makeOpenPath(args[4], .{});

    const arch = std.meta.stringToEnum(Config.Arch, args[5]) orelse std.debug.panic("Invalid architecture {s}, expected {any}", .{ args[5], std.meta.tags(Config.Arch) });
    const precision = std.meta.stringToEnum(Config.Precision, args[6]) orelse std.debug.panic("Invalid precision {s}, expected {any}", .{ args[6], std.meta.tags(Config.Precision) });
    const verbosity = std.meta.stringToEnum(Config.Verbosity, args[7]) orelse .quiet;

    return .{
        .arch = arch,
        .extension_api = extension_api,
        .gdextension_interface = gdextension_interface,
        .input = input,
        .output = output,
        .precision = precision,
        .verbosity = verbosity,
    };
}

pub fn buildConfiguration(self: *Config) []const u8 {
    return switch (self.arch) {
        .double => switch (self.precision) {
            .@"32" => "double_32",
            .@"64" => "double_64",
        },
        .float => switch (self.precision) {
            .@"32" => "float_32",
            .@"64" => "float_64",
        },
    };
}

pub fn deinit(self: *Config) void {
    self.gdextension_interface.close();
    self.extension_api.close();
    self.input.close();
    self.output.close();
}

pub fn testConfig(output: Dir) !Config {
    var headers = std.fs.openDirAbsolute(build_options.headers, .{}) catch |err| {
        std.debug.print("Failed to open headers dir: {s}\n", .{@errorName(err)});
        return err;
    };
    defer headers.close();

    return Config{
        .arch = .float,
        .extension_api = try headers.openFile("extension_api.json", .{}),
        .gdextension_interface = try headers.openFile("gdextension_interface.h", .{}),
        .input = output,
        .output = output,
        .precision = .@"32",
        .verbosity = .quiet,
    };
}
