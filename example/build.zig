pub fn build(b: *Build) !void {
    // Options
    var target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const godot_version = b.option([]const u8, "godot-version", "Download and use this Godot version (e.g. `latest` or `4.5`)");
    const godot_path = b.option([]const u8, "godot-path", "Directory containing Godot executable [default: $PATH]");
    const single_threaded = b.option(bool, "single_threaded", "Target single threaded GdExtension [default: false]") orelse false;

    if (!single_threaded and target.result.cpu.arch.isWasm()) {
        target.query.cpu_features_add.addFeature(@intFromEnum(std.Target.wasm.Feature.atomics));
        target.query.cpu_features_add.addFeature(@intFromEnum(std.Target.wasm.Feature.bulk_memory));
    }

    // Dependencies
    const gdzig_dep = b.dependency("gdzig", .{
        .target = target,
        .optimize = optimize,
        .@"godot-version" = godot_version,
        .@"godot-path" = godot_path,
    });

    // Extension module
    const mod = b.createModule(.{
        .root_source_file = b.path("src/example.zig"),
        .target = target,
        .optimize = optimize,
        .single_threaded = single_threaded,
        .imports = &.{
            .{ .name = "godot", .module = gdzig_dep.module("gdzig") },
        },
    });

    // Extension library (handles both native and wasm)
    const extension = gdzig.addExtension(b, .{
        .name = "example",
        .root_module = mod,
        .entry_symbol = "my_extension_init",
        .target = target,
        .optimize = optimize,
    }) orelse return;

    // Install
    const install = b.addInstallFileWithDir(extension.output, .{ .custom = "../project/lib" }, extension.filename);
    b.default_step.dependOn(&install.step);

    // Run
    const run = Build.Step.Run.create(b, "run godot");
    run.addFileArg(gdzig_dep.namedLazyPath("godot"));
    run.addArg("--path");
    run.addDirectoryArg(b.path("./project"));
    run.step.dependOn(&install.step);

    const run_step = b.step("run", "Run with Godot");
    run_step.dependOn(&run.step);

    // Tests
    const tests = gdzig.addTest(b, .{
        .root_module = mod,
        .target = target,
        .optimize = optimize,
    });
    b.step("test", "Run tests in Godot").dependOn(&tests.step);
}

const std = @import("std");
const Build = std.Build;

const gdzig = @import("gdzig");
const godot = @import("godot");
