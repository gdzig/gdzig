pub const BuildOptions = struct {
    headers: Build.LazyPath,
    target: Build.ResolvedTarget,
    optimize: OptimizeMode,
    precision: []const u8 = "float",
    architecture: []const u8 = "64",
};

/// Create the host bindgen executable with the requested API headers and modules.
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

    const compat_mod = b.createModule(.{
        .root_source_file = b.path("pkg/compat/compat.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "common", .module = common_mod }},
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
    build_options.addOptionPathDirectory("headers", options.headers);

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
            .{ .name = "compat", .module = compat_mod },
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
    godot_compatibility_minimum: ?Version = null,
};

/// Run bindgen and return the output directory containing generated bindings.
pub fn run(b: *Build, exe: *Build.Step.Compile, options: RunOptions) Build.LazyPath {
    const files = b.addWriteFiles();
    const mixins = files.addCopyDirectory(b.path("src"), "input", .{
        .include_extensions = &.{".mixin.zig"},
    });

    const cmd = b.addRunArtifact(exe);
    cmd.expectExitCode(0);
    cmd.addPrefixedFileArg("--gdextension-interface=", options.headers.path(b, "gdextension_interface.h"));
    cmd.addPrefixedFileArg("--extension-api=", options.headers.path(b, "extension_api.json"));
    cmd.addPrefixedDirectoryArg("--input=", mixins);
    const bindings_output = cmd.addPrefixedOutputDirectoryArg("--output=", "bindings");
    cmd.addArg(b.fmt("--precision={s}", .{options.precision}));
    cmd.addArg(b.fmt("--architecture={s}", .{options.architecture}));
    cmd.addArg(b.fmt("--verbosity={s}", .{if (b.graph.verbose) "verbose" else "quiet"}));
    if (options.godot_compatibility_minimum) |minimum| {
        cmd.addArg(b.fmt("--godot-compatibility-minimum={d}.{d}.{d}", .{
            minimum.major,
            minimum.minor,
            minimum.patch,
        }));
    }

    return bindings_output;
}

const std = @import("std");
const Build = std.Build;
const OptimizeMode = std.builtin.OptimizeMode;

const Version = @import("../pkg/common/version.zig").Version;
const common = @import("common.zig");
const gdextension = @import("gdextension.zig");
