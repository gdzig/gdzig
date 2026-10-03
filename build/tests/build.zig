pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const dep = b.dependency("gdzig", .{
        .target = target,
        .optimize = optimize,
        .@"godot-version" = b.option([]const u8, "godot-version", "Binding target").?,
        .@"godot-path" = b.option([]const u8, "godot-path", "Godot wrapper").?,
    });
    const run = gdzig.addTest(b, .{
        .name = "probe",
        .root_module = b.createModule(.{
            .root_source_file = b.path("root.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{.{ .name = "gdzig", .module = dep.module("gdzig") }},
        }),
        .target = target,
        .optimize = optimize,
    });
    b.step("test", "Run the downstream regression fixture").dependOn(&run.step);
}

const std = @import("std");

const gdzig = @import("gdzig");
