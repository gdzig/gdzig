pub fn build(b: *Build) !void {
    //
    // Options
    //

    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const precision = b.option([]const u8, "precision", "Floating point precision, either `float` or `double` [default: `float`]") orelse "float";
    const architecture = b.option([]const u8, "arch", "32") orelse "64";
    const godot_path = b.option([]const u8, "godot-path", "Path to a Godot executable");
    const regenerate_interface = b.option(bool, "regenerate-interface", "Regenerate the vendored GDExtension interface header (requires Python)") orelse false;

    //
    // Steps
    //

    const check_step = b.step("check", "Check the build without installing artifacts");
    const docs_step = b.step("docs", "Generate API documentation");
    const test_step = b.step("test", "Run unit tests");

    //
    // Dependencies
    //

    const casez = b.dependency("casez", .{});
    const oopz = b.dependency("oopz", .{});

    //
    // Godot
    //

    const godot_cpp = b.dependency("godot_cpp", .{});
    const interface_header: Build.LazyPath = if (regenerate_interface) blk: {
        const python = b.findProgram(&.{ "python3", "python" }, &.{}) catch @panic("Python is required to regenerate gdextension_interface.h");
        const generate_header = b.addSystemCommand(&.{python});
        generate_header.addArgs(&.{
            "-c",
            \\import importlib.util, sys
            \\out_path, script_path, source_path = sys.argv[1:4]
            \\spec = importlib.util.spec_from_file_location("make_interface_header", script_path)
            \\module = importlib.util.module_from_spec(spec)
            \\spec.loader.exec_module(module)
            \\module.generate_gdextension_interface_header(out_path, source_path)
        });
        const generated_header = generate_header.addOutputFileArg("gdextension_interface.h");
        generate_header.addFileArg(godot_cpp.path("make_interface_header.py"));
        generate_header.addFileArg(godot_cpp.path("gdextension/gdextension_interface.json"));
        break :blk generated_header;
    } else b.path("vendor/gdextension_interface.h");
    const extension_api = b.path("vendor/extension_api.json");

    const headers_write = b.addWriteFiles();
    _ = headers_write.addCopyFile(interface_header, "gdextension_interface.h");
    _ = headers_write.addCopyFile(extension_api, "extension_api.json");
    const headers = headers_write.getDirectory();

    // Godot executable for integration tests and examples.
    const godot_exe: Build.LazyPath = blk: {
        if (godot_path) |p| {
            break :blk .{ .cwd_relative = p };
        }
        if (b.findProgram(&.{"godot"}, &.{}) catch null) |p| {
            break :blk .{ .cwd_relative = p };
        }
        @panic("Godot executable not found. Install godot on PATH or pass -Dgodot-path=<path>");
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
        .optimize = .Debug,
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
    var tests_gdzig_run: ?*Build.Step.Run = null;
    var tests_common_run: ?*Build.Step.Run = null;

    if (!target.result.cpu.arch.isWasm()) { // Do not add test for web targets.
        const tests_gdzig = b.addTest(.{ .root_module = gdzig_mod });
        const tests_common = b.addTest(.{ .root_module = common_mod });
        tests_gdzig_run = b.addRunArtifact(tests_gdzig);
        tests_common_run = b.addRunArtifact(tests_common);

        var tests_dir = try Dir.cwd().openDir(b.graph.io, b.path("test").getPath2(b, null), .{ .iterate = true });
        defer tests_dir.close(b.graph.io);

        var iter = tests_dir.iterate();
        while (iter.next(b.graph.io) catch null) |entry| {
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
    }

    //
    // Step dependencies
    //

    check_step.dependOn(&gdzig_lib.step);
    if (tests_gdzig_run) |r| test_step.dependOn(&r.step);
    if (tests_common_run) |r| test_step.dependOn(&r.step);

    //
    // Default step
    //

    const install_bindings = b.addInstallDirectory(.{
        .source_dir = bindings,
        .install_dir = .{ .custom = "../" },
        .install_subdir = "src",
    });
    install_bindings.step.dependOn(&gdzig_lib.step);
    b.getInstallStep().dependOn(&install_bindings.step);
    b.installArtifact(bindgen_exe);
    const install_docs = b.addInstallDirectory(.{
        .source_dir = gdzig_lib.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "docs",
    });
    install_docs.step.dependOn(&gdzig_lib.step);
    docs_step.dependOn(&install_docs.step);
    b.getInstallStep().dependOn(&install_docs.step);
    b.installDirectory(.{
        .source_dir = headers,
        .install_dir = .prefix,
        .install_subdir = "vendor",
    });
}

const std = @import("std");
const Build = std.Build;
const Io = std.Io;
const Dir = Io.Dir;

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
