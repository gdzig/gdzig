pub fn build(b: *Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const godot_path = b.option([]const u8, "godot", "Path to Godot engine binary, used when 'headers' are 'GENERATED' [default: `godot`]") orelse "godot";
    const precision = b.option([]const u8, "precision", "Floating point precision, either `float` or `double` [default: `float`]") orelse "float";
    const architecture = b.option([]const u8, "arch", "32") orelse "64";
    const headers_input = b.option([]const u8, "headers", "Where to source Godot header files. [options: GENERATED, VENDORED, DEPENDENCY, <dir_path>] [default: GENERATED]") orelse "GENERATED";

    const headers_normalized = std.ascii.allocLowerString(b.allocator, headers_input) catch unreachable;

    //
    // Dependencies
    //

    const dep_bbcodez = b.dependency("bbcodez", .{});
    const dep_case = b.dependency("case", .{});
    const dep_oopz = b.dependency("oopz", .{});
    const dep_temp = b.dependency("temp", .{});

    //
    // Headers
    //

    const headers_files = b.addWriteFiles();
    const headers_source: Build.LazyPath = blk: {
        if (std.mem.eql(u8, headers_normalized, "dependency"))
            break :blk b.dependency("godot_cpp", .{}).path("gdextension");

        if (std.mem.eql(u8, headers_normalized, "vendored"))
            break :blk b.path("vendor");

        if (std.mem.eql(u8, headers_normalized, "generated") or headers_normalized.len == 0) {
            const tmp = b.addWriteFiles();
            const out = tmp.getDirectory();
            const dump = b.addSystemCommand(&.{
                godot_path,
                "--dump-extension-api-with-docs",
                "--dump-gdextension-interface",
                "--headless",
            });
            dump.setCwd(out);
            _ = dump.captureStdOut();
            _ = dump.captureStdErr();
            headers_files.step.dependOn(&dump.step);
            break :blk out;
        }

        break :blk b.path(headers_normalized);
    };

    const headers_root = headers_files.getDirectory();
    _ = headers_files.addCopyFile(headers_source.path(b, "extension_api.json"), "extension_api.json");
    const headers_header = headers_files.addCopyFile(headers_source.path(b, "gdextension_interface.h"), "gdextension_interface.h");

    //
    // GDExtension
    //

    const gdextension_translate = b.addTranslateC(.{
        .link_libc = true,
        .optimize = optimize,
        .target = target,
        .root_source_file = headers_header,
    });

    const gdextension_mod = b.createModule(.{
        .root_source_file = gdextension_translate.getOutput(),
        .optimize = optimize,
        .target = target,
        .link_libc = true,
    });

    //
    // Bindgen
    //

    const bindgen_options = b.addOptions();
    bindgen_options.addOption([]const u8, "architecture", architecture);
    bindgen_options.addOption([]const u8, "precision", precision);

    const bindgen_mod = b.addModule("gdzig_bindgen", .{
        .target = target,
        .optimize = optimize,
        .root_source_file = b.path("gdzig_bindgen/main.zig"),
        .link_libc = true,
        .imports = &.{
            .{ .name = "bbcodez", .module = dep_bbcodez.module("bbcodez") },
            .{ .name = "build_options", .module = bindgen_options.createModule() },
            .{ .name = "case", .module = dep_case.module("case") },
            .{ .name = "gdextension", .module = gdextension_mod },
            .{ .name = "temp", .module = dep_temp.module("temp") },
        },
    });

    const bindgen_exe = b.addExecutable(.{
        .name = "gdzig-bindgen",
        .root_module = bindgen_mod,
    });

    const bindgen_install = b.addInstallArtifact(bindgen_exe, .{});

    //
    // Bindings
    //

    const bindings_files = b.addWriteFiles();
    const bindings_mixins = bindings_files.addCopyDirectory(b.path("gdzig"), "input", .{
        .include_extensions = &.{".mixin.zig"},
    });

    const bindings_run = b.addRunArtifact(bindgen_exe);
    bindings_run.expectExitCode(0);
    bindings_run.addDirectoryArg(headers_root);
    bindings_run.addDirectoryArg(bindings_mixins);

    const bindings_output = bindings_run.addOutputDirectoryArg("bindings");
    bindings_run.addArg(precision);
    bindings_run.addArg(architecture);
    bindings_run.addArg(if (b.verbose) "verbose" else "quiet");

    const bindings_install = b.addInstallDirectory(.{
        .source_dir = bindings_output,
        .install_dir = .{ .custom = "../" },
        .install_subdir = "gdzig",
    });

    //
    // Library
    //

    const gdzig_files = b.addWriteFiles();
    const gdzig_combined = gdzig_files.addCopyDirectory(b.path("gdzig"), "gdzig", .{
        .exclude_extensions = &.{".mixin.zig"},
    });
    _ = gdzig_files.addCopyDirectory(bindings_output, "gdzig", .{});

    const gdzig_options = b.addOptions();
    gdzig_options.addOption([]const u8, "architecture", architecture);
    gdzig_options.addOption([]const u8, "precision", precision);

    const gdzig_mod = b.addModule("gdzig", .{
        .root_source_file = gdzig_combined.path(b, "gdzig.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "build_options", .module = gdzig_options.createModule() },
            .{ .name = "case", .module = dep_case.module("case") },
            .{ .name = "gdextension", .module = gdextension_mod },
            .{ .name = "oopz", .module = dep_oopz.module("oopz") },
        },
    });

    const gdzig_lib = b.addLibrary(.{
        .name = "gdzig",
        .root_module = gdzig_mod,
        .linkage = .static,
        .use_llvm = true,
    });

    //
    // Tests
    //

    const tests_bindgen = b.addTest(.{ .root_module = bindgen_mod });
    const tests_gdzig = b.addTest(.{ .root_module = gdzig_mod });
    const tests_bindgen_run = b.addRunArtifact(tests_bindgen);
    const tests_gdzig_run = b.addRunArtifact(tests_gdzig);

    const tests_integration_run = gdzig_test.addTestCases(b, .{
        .root_dir = b.path("tests"),
        .godot = godot_path,
        .gdzig = gdzig_mod,
        .target = target,
        .optimize = optimize,
    });

    //
    // Docs
    //
    const docs_install = b.addInstallDirectory(.{
        .source_dir = gdzig_lib.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "docs",
    });

    //
    // Steps
    //

    b.step("build-bindgen", "Build the gdzig_bindgen executable").dependOn(&bindgen_install.step);
    b.step("run-bindgen", "Run bindgen to generate builtin/class code").dependOn(&bindings_install.step);
    b.step("docs", "Install docs into zig-out/docs").dependOn(&docs_install.step);
    b.step("check", "Check the build without installing artifacts").dependOn(&gdzig_lib.step);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&tests_bindgen_run.step);
    test_step.dependOn(&tests_gdzig_run.step);
    test_step.dependOn(&tests_integration_run.step);

    const test_integration_step = b.step("test-integration", "Run integration tests");
    test_integration_step.dependOn(&tests_integration_run.step);

    //
    // Default build
    //

    b.default_step.dependOn(&gdzig_lib.step);
    b.installArtifact(bindgen_exe);
    b.installDirectory(.{
        .source_dir = gdzig_lib.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "docs",
    });
}

const std = @import("std");
const Build = std.Build;
const Step = std.Build.Step;
const gdzig_test = @import("gdzig_test/build.zig");
