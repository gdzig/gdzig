const std = @import("std");
const build_options = @import("build_options");
const Io = std.Io;
const Dir = Io.Dir;
const File = Io.File;

const Config = @This();

arch: Arch,
extension_api: File,
gdextension_interface: File,
input: Dir,
output: Dir,
precision: Precision,
verbosity: Verbosity,
io: Io,

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

pub fn loadFromArgs(io: Io, args: []const []const u8) !Config {
    const cwd = Dir.cwd();

    // args[1]: path to gdextension_interface.h
    // args[2]: path to extension_api.json
    const gdextension_interface = try cwd.openFile(io, args[1], .{});
    const extension_api = try cwd.openFile(io, args[2], .{});

    const input = try cwd.createDirPathOpen(io, args[3], .{});
    const output = try cwd.createDirPathOpen(io, args[4], .{});

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
        .io = io,
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
    self.gdextension_interface.close(self.io);
    self.extension_api.close(self.io);
    self.input.close(self.io);
    self.output.close(self.io);
}

pub fn testConfig(io: Io, output: Dir) !Config {
    var headers = Dir.openDirAbsolute(io, build_options.headers, .{}) catch |err| {
        std.debug.print("Failed to open headers dir: {s}\n", .{@errorName(err)});
        return err;
    };
    defer headers.close(io);

    return Config{
        .arch = .float,
        .extension_api = try headers.openFile(io, "extension_api.json", .{}),
        .gdextension_interface = try headers.openFile(io, "gdextension_interface.h", .{}),
        .input = output,
        .output = output,
        .precision = .@"32",
        .verbosity = .quiet,
        .io = io,
    };
}
