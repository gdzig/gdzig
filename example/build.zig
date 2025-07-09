pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const godot_path = b.option([]const u8, "godot", "Path to Godot engine binary [default: `godot`]") orelse "godot";

    const gdzig_dep = b.dependency("gdzig", .{
        .target = target,
        .optimize = optimize,
        .godot = godot_path,

        // This is the default value, so could be omitted. If you want, you can change it to "double".
        // You should hardcode this for your project, rather than exposing it as a build option like the godot path.
        .precision = @as([]const u8, "float"),
    });

    const lib = b.addSharedLibrary(.{
        .name = "example",
        .root_source_file = b.path("src/example.zig"),
        .target = target,
        .optimize = optimize,
    });
    lib.root_module.addImport("gdzig", gdzig_dep.module("gdzig"));

    b.lib_dir = "./project/lib";
    b.installArtifact(lib);

    const project_path = b.path("./project");
    const load_cmd = b.addSystemCommand(&.{
        godot_path, "--headless", "--quit", "--editor", "--path",
    });
    load_cmd.addDirectoryArg(project_path);
    //load_cmd.expectExitCode(0);
    load_cmd.step.dependOn(b.getInstallStep());
    const load_step = b.step("load", "Load project");
    load_step.dependOn(&load_cmd.step);

    const run_cmd = b.addSystemCommand(&.{
        godot_path, "--path",
    });
    run_cmd.addDirectoryArg(project_path);
    run_cmd.step.dependOn(b.getInstallStep());
    const run_step = b.step("run", "Run with Godot");
    run_step.dependOn(&run_cmd.step);
}

const std = @import("std");
