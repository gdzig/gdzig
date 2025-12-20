pub fn build(b: *Build) !void {
    // Options
    var target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const godot_version = b.option([]const u8, "godot", "Which version of Godot to generate bindings for [default: `4.5.1`]") orelse "4.5.1";
    const single_threaded = b.option(bool, "single_threaded", "Target single threaded GdExtension [default: false]") orelse false;
    const godot_exe = godot.executable(b, b.graph.host, godot_version) orelse return;

    if (!single_threaded and target.result.cpu.arch.isWasm()) {
        target.query.cpu_features_add.addFeature(@intFromEnum(std.Target.wasm.Feature.atomics));
        target.query.cpu_features_add.addFeature(@intFromEnum(std.Target.wasm.Feature.bulk_memory));
    }

    // Dependencies
    const gdzig_dep = b.dependency("gdzig", .{
        .target = target,
        .optimize = optimize,
        .godot = godot_version,
    });

    // Module
    const mod = b.createModule(.{
        .root_source_file = b.path("src/example.zig"),
        .target = target,
        .optimize = optimize,
        .single_threaded = single_threaded,
        .imports = &.{
            .{ .name = "gdzig", .module = gdzig_dep.module("gdzig") },
        },
    });

    const out_path = "../project/lib";
    const install_step = if (target.result.cpu.arch.isWasm()) blk: {
        // Library
        mod.pic = true;
        const lib = gdzig.buildWeb(b, .{
            .name = "example",
            .root_module = mod,
        });

        // Install
        const install = b.addInstallFileWithDir(lib, .{ .custom = out_path }, "libexample.wasm");
        b.default_step.dependOn(&install.step);
        break :blk &install.step;
    } else blk: {
        // Library
        const lib = b.addLibrary(.{
            .name = "example",
            .linkage = .dynamic,
            .root_module = mod,
            .use_llvm = true,
        });

        // Install
        const install = b.addInstallArtifact(lib, .{
            .dest_dir = .{ .override = .{ .custom = out_path } },
        });
        b.default_step.dependOn(&install.step);
        break :blk &install.step;
    };

    // Run
    const run = Build.Step.Run.create(b, "run godot");
    run.addFileArg(godot_exe);
    run.addArg("--path");
    run.addDirectoryArg(b.path("./project"));
    run.step.dependOn(install_step);

    const run_step = b.step("run", "Run with Godot");
    run_step.dependOn(&run.step);
}

const std = @import("std");
const Build = std.Build;
const gdzig = @import("gdzig");
const godot = @import("godot");
