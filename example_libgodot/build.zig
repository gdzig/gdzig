const std = @import("std");

pub fn build(b: *std.Build) void {
    var target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const os_tag = target.result.os.tag;

    const godot_path = b.option([]const u8, "godot-path", "Directory containing Godot executable");
    const libgodot_path = b.option([]const u8, "libgodot-path", "Directory containing LibGodot library") orelse @panic("libgodot-path is required");
    const libgodot_library = b.option([]const u8, "libgodot-library", "The libgodot library name") orelse @panic("libgodot-library is required");

    const single_threaded = b.option(bool, "single_threaded", "Target single threaded GdExtension [default: false]") orelse false;

    if (!single_threaded and target.result.cpu.arch.isWasm()) {
        target.query.cpu_features_add.addFeature(@intFromEnum(std.Target.wasm.Feature.atomics));
        target.query.cpu_features_add.addFeature(@intFromEnum(std.Target.wasm.Feature.bulk_memory));
    }

    // Dependencies
    const gdzig_dep = b.dependency("gdzig", .{
        .target = target,
        .optimize = optimize,
        .@"godot-path" = godot_path,
    });

    // Application module
    const mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .single_threaded = single_threaded,
        .link_libc = true,
        .imports = &.{
            .{ .name = "godot", .module = gdzig_dep.module("gdzig") },
        },
    });

    // Application executable
    const exe = b.addExecutable(.{
        .name = "libgodot_example",
        .root_module = mod,
        .linkage = .dynamic,
        .win32_manifest = b.path("app.manifest"), // Manifest is needed to make common controls available
    });
    exe.addLibraryPath(.{ .cwd_relative = libgodot_path });
    exe.linkSystemLibrary(libgodot_library);

    b.installArtifact(exe);

    // Copy dynamic lib
    const suffix = os_tag.dynamicLibSuffix();
    const prefix = if (os_tag == .windows) "" else "lib";
    const lib_filename = b.fmt("{s}{s}{s}", .{ prefix, libgodot_library, suffix });
    const copy_dynlib = b.addInstallFile(
        .{ .cwd_relative = b.fmt("{s}/{s}", .{ libgodot_path, lib_filename }) },
        b.fmt("bin/{s}", .{lib_filename}),
    );
    b.getInstallStep().dependOn(&copy_dynlib.step);

    // Run
    const run = b.addRunArtifact(exe);
    run.addArg("--path");
    run.addDirectoryArg(b.path("./project"));
    run.step.dependOn(b.getInstallStep());

    const run_step = b.step("run", "Run libgodot example");
    run_step.dependOn(&run.step);
}
