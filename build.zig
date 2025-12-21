const latest_version = "4.5";

pub fn build(b: *Build) !void {
    //
    // Options
    //

    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const precision = b.option([]const u8, "precision", "Floating point precision, either `float` or `double` [default: `float`]") orelse "float";
    const architecture = b.option([]const u8, "arch", "32") orelse "64";
    const godot_version = b.option([]const u8, "godot-version", "Download and use this Godot version (e.g. `latest` or `4.5`)");
    const godot_path = b.option([]const u8, "godot-path", "Directory containing Godot executable [default: $PATH]");

    //
    // Steps
    //

    const check_step = b.step("check", "Check the build without installing artifacts");
    const test_step = b.step("test", "Run unit tests");

    //
    // Dependencies
    //

    const casez = b.dependency("casez", .{});
    const oopz = b.dependency("oopz", .{});

    //
    // Godot
    //

    const godot_exe: Build.LazyPath = blk: {
        if (godot_version) |v| {
            break :blk godot.executable(b, b.graph.host, v) orelse return;
        }
        if (godot_path) |p| {
            const dir: Build.LazyPath = .{ .cwd_relative = p };
            break :blk dir.path(b, "godot");
        }
        if (b.findProgram(&.{"godot"}, &.{}) catch null) |p| {
            break :blk .{ .cwd_relative = p };
        }
        break :blk godot.executable(b, b.graph.host, latest_version) orelse return;
    };

    const headers = blk: {
        const gdextension_interface_h = godot.headers(b, latest_version).path(b, "gdextension_interface.h");
        const extension_api_json = godot.headers(b, godot_version orelse getGodotVersion(b, godot_exe)).path(b, "extension_api.json");

        const write = b.addWriteFiles();
        _ = write.addCopyFile(gdextension_interface_h, "gdextension_interface.h");
        _ = write.addCopyFile(extension_api_json, "extension_api.json");
        break :blk write.getDirectory();
    };

    b.addNamedLazyPath("godot", godot_exe);
    b.addNamedLazyPath("gdextension_interface.h", headers.path(b, "gdextension_interface.h"));
    b.addNamedLazyPath("extension_api.json", headers.path(b, "extension_api.json"));

    //
    // GDExtension
    //

    const gdextension_mod = gdextension.build(b, .{
        .headers = headers,
        .target = target,
        .optimize = optimize,
    });

    //
    // Common
    //

    const common_mod = common.build(b, .{
        .target = target,
        .optimize = optimize,
        .casez = casez.module("casez"),
    });

    //
    // Bindgen
    //

    const bindgen_exe = bindgen.build(b, .{
        .headers = headers,
        .target = b.graph.host,
        .optimize = .ReleaseFast,
        .precision = precision,
        .architecture = architecture,
    });
    const bindings = bindgen.run(b, bindgen_exe, .{
        .headers = headers,
        .precision = precision,
        .architecture = architecture,
    });

    //
    // Library
    //

    const gdzig_files = b.addWriteFiles();
    const gdzig_combined = gdzig_files.addCopyDirectory(b.path("src"), "gdzig", .{
        .exclude_extensions = &.{".mixin.zig"},
    });
    _ = gdzig_files.addCopyDirectory(bindings, "gdzig", .{});

    const gdzig_options = b.addOptions();
    gdzig_options.addOption([]const u8, "architecture", architecture);
    gdzig_options.addOption([]const u8, "precision", precision);

    const gdzig_mod = b.addModule("gdzig", .{
        .root_source_file = gdzig_combined.path(b, "gdzig.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "build_options", .module = gdzig_options.createModule() },
            .{ .name = "casez", .module = casez.module("casez") },
            .{ .name = "gdextension", .module = gdextension_mod },
            .{ .name = "common", .module = common_mod },
            .{ .name = "oopz", .module = oopz.module("oopz") },
        },
    });
    gdzig_mod.addImport("gdzig", gdzig_mod);

    const gdzig_lib = b.addLibrary(.{
        .name = "gdzig",
        .root_module = gdzig_mod,
        .linkage = .static,
        .use_llvm = true,
    });

    //
    // Tests
    //

    const tests_gdzig = b.addTest(.{ .root_module = gdzig_mod });
    const tests_gdzig_run = b.addRunArtifact(tests_gdzig);

    var tests_dir = try std.fs.cwd().openDir(b.path("test").getPath2(b, null), .{ .iterate = true });
    defer tests_dir.close();

    var iter = tests_dir.iterate();
    while (iter.next() catch null) |entry| {
        if (entry.kind != .directory) continue;

        const test_mod = b.createModule(.{
            .root_source_file = b.path(b.fmt("test/{s}/root.zig", .{entry.name})),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "gdzig", .module = gdzig_mod },
            },
        });

        const run_test = api.addTestImpl(b, .{ .b = b, .dep = null }, .{
            .name = b.dupe(entry.name),
            .root_module = test_mod,
            .target = target,
            .optimize = optimize,
        });
        test_step.dependOn(&run_test.step);
    }

    //
    // Step dependencies
    //

    check_step.dependOn(&gdzig_lib.step);
    test_step.dependOn(&tests_gdzig_run.step);

    //
    // Default step
    //

    b.installDirectory(.{
        .source_dir = bindings,
        .install_dir = .{ .custom = "../" },
        .install_subdir = "src",
    });
    b.installArtifact(bindgen_exe);
    b.installDirectory(.{
        .source_dir = gdzig_lib.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "docs",
    });
    b.installDirectory(.{
        .source_dir = headers,
        .install_dir = .prefix,
        .install_subdir = "vendor",
    });
}

fn getGodotVersion(b: *Build, p: Build.LazyPath) []const u8 {
    const result = std.process.Child.run(.{
        .allocator = b.allocator,
        .argv = &.{ p.getPath2(b, null), "--version" },
    }) catch @panic("Failed to run godot --version");
    const output = std.mem.trim(u8, result.stdout, &std.ascii.whitespace);

    var parts = std.mem.splitScalar(u8, output, '.');
    const major = parts.next() orelse @panic("Failed to parse major version");
    const minor = parts.next() orelse @panic("Failed to parse minor version");
    const patch = parts.next() orelse @panic("Failed to parse patch version");

    return b.fmt("{s}.{s}.{s}", .{ major, minor, patch });
}

const std = @import("std");
const Build = std.Build;

const godot = @import("godot");

const api = @import("build/api.zig");
pub const addExtension = api.addExtension;
pub const addTest = api.addTest;
pub const Extension = api.Extension;
pub const ExtensionOptions = api.ExtensionOptions;
pub const TestOptions = api.TestOptions;
pub const InitializationLevel = api.InitializationLevel;
const bindgen = @import("build/bindgen.zig");
const common = @import("build/common.zig");
const gdextension = @import("build/gdextension.zig");
