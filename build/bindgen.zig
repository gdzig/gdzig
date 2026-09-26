pub const BuildOptions = struct {
    headers: Build.LazyPath,
    target: Build.ResolvedTarget,
    optimize: OptimizeMode,
    precision: []const u8 = "float",
    architecture: []const u8 = "64",
};

pub fn build(b: *Build, options: BuildOptions) *Build.Step.Compile {
    const target = options.target;
    const optimize = options.optimize;

    //
    // Dependencies (host-targeted)
    //

    const bbcodez = b.dependency("bbcodez", .{ .target = target, .optimize = optimize });
    const casez = b.dependency("casez", .{ .target = target, .optimize = optimize });

    const common_mod = common.build(b, .{
        .target = target,
        .optimize = optimize,
        .casez = casez.module("casez"),
    });

    const gdextension_mod = gdextension.build(b, .{
        .headers = options.headers,
        .target = target,
        .optimize = optimize,
    });

    //
    // Bindgen
    //

    const build_options = b.addOptions();
    build_options.addOption([]const u8, "architecture", options.architecture);
    build_options.addOption([]const u8, "precision", options.precision);
    // TODO(zig 0.16.0): zig master's `addOptionPath` is file-only and gained
    // `addOptionPathDirectory` for directories (this path is opened as a dir
    // by pkg/bindgen/Config.zig).
    if (comptime builtin.zig_version.minor == 16) {
        build_options.addOptionPath("headers", options.headers);
    } else {
        build_options.addOptionPathDirectory("headers", options.headers);
    }

    const mod = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .root_source_file = b.path("pkg/bindgen/main.zig"),
        .link_libc = true,
        .imports = &.{
            .{ .name = "bbcodez", .module = bbcodez.module("bbcodez") },
            .{ .name = "build_options", .module = build_options.createModule() },
            .{ .name = "casez", .module = casez.module("casez") },
            .{ .name = "common", .module = common_mod },
            .{ .name = "gdextension", .module = gdextension_mod },
        },
    });

    return b.addExecutable(.{
        .name = "gdzig-bindgen",
        .root_module = mod,
    });
}

pub const RunOptions = struct {
    headers: Build.LazyPath,
    precision: []const u8 = "float",
    architecture: []const u8 = "64",
};

/// Run bindgen and return the output directory containing generated bindings.
pub fn run(b: *Build, exe: *Build.Step.Compile, options: RunOptions) Build.LazyPath {
    const files = b.addWriteFiles();
    const mixins = files.addCopyDirectory(b.path("src"), "input", .{
        .include_extensions = &.{".mixin.zig"},
    });

    const cmd = b.addRunArtifact(exe);
    cmd.expectExitCode(0);
    cmd.addFileArg(options.headers.path(b, "gdextension_interface.h"));
    cmd.addFileArg(options.headers.path(b, "extension_api.json"));
    cmd.addDirectoryArg(mixins);

    const bindings_output = cmd.addOutputDirectoryArg("bindings");
    cmd.addArg(options.precision);
    cmd.addArg(options.architecture);
    // TODO(zig 0.16.0): zig master moved `Build.verbose` into `Build.Graph`.
    const verbose: bool = if (comptime builtin.zig_version.minor == 16) b.verbose else b.graph.verbose;
    cmd.addArg(if (verbose) "verbose" else "quiet");

    return bindings_output;
}

const std = @import("std");
const builtin = @import("builtin");
const Build = std.Build;
const OptimizeMode = std.builtin.OptimizeMode;

const common = @import("common.zig");
const gdextension = @import("gdextension.zig");
