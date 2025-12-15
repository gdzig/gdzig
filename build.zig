const test_versions = &.{
    // "4.1",
    // "4.2",
    // "4.3",
    // "4.4",
    "4.5",
};
const default_version = test_versions[test_versions.len - 1];

pub fn build(b: *Build) void {
    //
    // Options
    //

    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const version = b.option([]const u8, "godot", "Which version of Godot to generate bindings for [default: `" ++ default_version ++ "`]") orelse default_version;
    const precision = b.option([]const u8, "precision", "Floating point precision, either `float` or `double` [default: `float`]") orelse "float";
    const architecture = b.option([]const u8, "arch", "32") orelse "64";

    const fetch_godot = b.option(bool, "fetch-godot", "Download Godot binaries for integration tests") orelse false;

    //
    // Steps
    //

    const build_bindgen_step = b.step("build-bindgen", "Build the gdzig_bindgen executable");
    const run_bindgen_step = b.step("run-bindgen", "Run bindgen to generate builtin/class code");

    const check_step = b.step("check", "Check the build without installing artifacts");
    const docs_step = b.step("docs", "Install docs into zig-out/docs");
    const test_step = b.step("test", "Run unit tests");
    const test_integration_step = b.step("test-integration", "Run integration tests");

    //
    // Dependencies
    //

    const bbcodez = b.dependency("bbcodez", .{});
    const casez = b.dependency("casez", .{});
    const oopz = b.dependency("oopz", .{});
    const temp = b.dependency("temp", .{});

    // Always use latest interface header (defines all function pointers)
    const latest_headers = godot.headers(b, default_version);
    // Use requested version for API (classes/methods available)
    const api_headers = godot.headers(b, version);

    //
    // GDExtension
    //

    const gdextension_translate = b.addTranslateC(.{
        .link_libc = true,
        .optimize = optimize,
        .target = target,
        .root_source_file = latest_headers.path(b, "gdextension_interface.h"),
    });

    const gdextension_mod = b.createModule(.{
        .root_source_file = gdextension_translate.getOutput(),
        .optimize = optimize,
        .target = target,
        .link_libc = true,
    });

    //
    // Common
    //

    const gdzig_common_mod = b.addModule("common", .{
        .root_source_file = b.path("gdzig_common/gdzig_common.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "casez", .module = casez.module("casez") },
        },
    });

    //
    // Bindgen
    //

    const bindgen_options = b.addOptions();
    bindgen_options.addOption([]const u8, "architecture", architecture);
    bindgen_options.addOption([]const u8, "precision", precision);
    bindgen_options.addOptionPath("headers", latest_headers);

    const bindgen_mod = b.addModule("gdzig_bindgen", .{
        .target = target,
        .optimize = optimize,
        .root_source_file = b.path("gdzig_bindgen/main.zig"),
        .link_libc = true,
        .imports = &.{
            .{ .name = "bbcodez", .module = bbcodez.module("bbcodez") },
            .{ .name = "build_options", .module = bindgen_options.createModule() },
            .{ .name = "casez", .module = casez.module("casez") },
            .{ .name = "gdextension", .module = gdextension_mod },
            .{ .name = "common", .module = gdzig_common_mod },
            .{ .name = "temp", .module = temp.module("temp") },
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
    bindings_run.addFileArg(latest_headers.path(b, "gdextension_interface.h"));
    bindings_run.addFileArg(api_headers.path(b, "extension_api.json"));
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
            .{ .name = "casez", .module = casez.module("casez") },
            .{ .name = "gdextension", .module = gdextension_mod },
            .{ .name = "common", .module = gdzig_common_mod },
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

    const tests_bindgen = b.addTest(.{ .root_module = bindgen_mod });
    const tests_gdzig = b.addTest(.{ .root_module = gdzig_mod });
    const tests_bindgen_run = b.addRunArtifact(tests_bindgen);
    const tests_gdzig_run = b.addRunArtifact(tests_gdzig);

    if (fetch_godot) {
        if (godot.executable(b, b.graph.host, version)) |godot_exe| {
            const tests = gdzig_test.addTestCases(b, .{
                .root_dir = b.path("tests"),
                .godot_exe = godot_exe,
                .gdzig = gdzig_mod,
                .target = target,
                .optimize = optimize,
            });
            test_integration_step.dependOn(&tests.step);
        }
    }

    //
    // Docs
    //

    const docs_install = b.addInstallDirectory(.{
        .source_dir = gdzig_lib.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "docs",
    });

    //
    // Step dependencies
    //

    build_bindgen_step.dependOn(&bindgen_install.step);
    run_bindgen_step.dependOn(&bindings_install.step);
    docs_step.dependOn(&docs_install.step);
    check_step.dependOn(&gdzig_lib.step);
    test_step.dependOn(&tests_bindgen_run.step);
    test_step.dependOn(&tests_gdzig_run.step);
    test_step.dependOn(test_integration_step);

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
    b.installDirectory(.{
        .source_dir = latest_headers,
        .install_dir = .prefix,
        .install_subdir = "vendor",
    });
}

const std = @import("std");
const Build = std.Build;
const Step = std.Build.Step;
const gdzig_test = @import("gdzig_test/build.zig");

const godot = @import("godot");
