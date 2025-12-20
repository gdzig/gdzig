const default_version = "4.5";

/// Default emscripten verison for web builds. Matches version used by Godot.
const default_godot_emscripten_version = "4.0.20";

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

    const casez = b.dependency("casez", .{});
    const oopz = b.dependency("oopz", .{});

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
    // Bindings
    //

    const bindgen = generateBindings(b, .{
        .version = version,
        .precision = precision,
        .architecture = architecture,
        .api_headers = api_headers,
        .optimize = optimize,
    });

    const bindgen_install = b.addInstallArtifact(bindgen.exe, .{});

    const bindings_install = b.addInstallDirectory(.{
        .source_dir = bindgen.output,
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
    _ = gdzig_files.addCopyDirectory(bindgen.output, "gdzig", .{});

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

    const tests_bindgen = b.addTest(.{ .root_module = bindgen.mod });
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
    b.installArtifact(bindgen.exe);
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

pub const BuildWebOptions = struct {
    name: []const u8,
    root_module: *Build.Module,
    emsdk_path: ?Build.LazyPath = null,
    emsdk_version: []const u8 = default_godot_emscripten_version,
};

/// Build GdExtension for web. Returns LazyPath to wasm library.
pub fn buildWeb(b: *Build, opt: BuildWebOptions) Build.LazyPath {
    const optimize = opt.root_module.optimize orelse b.standardOptimizeOption(.{});
    const emsdk_path = if (opt.emsdk_path) |p| p else blk: {
        // If no emsdk is provided by user, use gdzig emsdk lazy dependency.
        const gdzig_dep = b.dependency("gdzig", .{});
        const emsdk_dep = gdzig_dep.builder.lazyDependency("emsdk", .{}) orelse std.process.exit(0);
        break :blk emsdk_dep.path("");
    };

    const single_threaded = opt.root_module.single_threaded orelse false;

    if (opt.root_module.resolved_target) |target| {
        if (target.result.os.tag != .emscripten or target.result.cpu.arch != .wasm32) {
            std.log.err("Unsupported target for building emscripten, must be wasm32-emscripten", .{});
            b.invalid_user_input = true;
            std.process.exit(1);
        }
    } else {
        std.log.err("Module has unresolved target", .{});
        b.invalid_user_input = true;
        std.process.exit(1);
    }
    opt.root_module.strip = false;
    const lib = b.addLibrary(.{
        .linkage = .static,
        .name = opt.name,
        .root_module = opt.root_module,
    });

    const install_emsdk = build_emscripten.emsdkInstall(b, emsdk_path, opt.emsdk_version);
    const activate_emsdk = build_emscripten.emsdkActivate(b, emsdk_path, opt.emsdk_version);
    activate_emsdk.step.dependOn(&install_emsdk.step);
    lib.step.dependOn(&activate_emsdk.step);
    lib.addSystemIncludePath(emsdk_path.path(b, "upstream/emscripten/cache/sysroot/include"));

    const run_emcc = build_emscripten.runEmcc(b, emsdk_path);

    for (lib.getCompileDependencies(false)) |dep| {
        if (dep.isStaticLibrary()) {
            run_emcc.addArtifactArg(dep);
        }
    }

    run_emcc.addArgs(&.{
        "-sSIDE_MODULE=1",
        "-sWASM_BIGINT",
        "-sSUPPORT_LONGJMP='wasm'",

        // Note: for emscripten <=4.0.13 "-sUSE_OFFSET_CONVERTER" is required for @returnAddress
    });

    run_emcc.addArgs(switch (optimize) {
        .Debug => &.{
            "-O0",
            "-g3", // preserve debug information
            "-fsanitize=undefined", // clang undefined behavior detection
        },
        .ReleaseSafe => &.{
            "-O3",
            "-fsanitize=undefined", // clang undefined behavior detection
            "-fsanitize-minimal-runtime", // use minimal runtime for UBSan
        },
        .ReleaseFast => &.{"-O3"},
        .ReleaseSmall => &.{"-Oz"},
    });

    if (optimize != .Debug) {
        run_emcc.addArgs(&.{
            "-flto", // link time optimization
            // reduce javascript size using closure compiler
            "--closure",
            "1",
        });
    }

    if (!single_threaded) {
        run_emcc.addArg("-sUSE_PTHREADS=1");
    }

    run_emcc.addArg("-o");
    const output = run_emcc.addOutputFileArg(b.fmt("lib{s}.wasm", .{lib.name}));
    return output;
}

const BindGenOptions = struct {
    version: []const u8 = default_version,
    precision: []const u8 = "float",
    architecture: []const u8 = "64",
    api_headers: Build.LazyPath,
    optimize: ?OptimizeMode = null,
};

const BindGenArtifacts = struct {
    mod: *Build.Module,
    exe: *Build.Step.Compile,
    run: *Build.Step.Run,
    output: LazyPath,
};

// Generate bindings on the host target
fn generateBindings(b: *Build, opt: BindGenOptions) BindGenArtifacts {
    const target = b.graph.host;
    const optimize = opt.optimize orelse b.standardOptimizeOption(.{});

    //
    // Dependencies
    //

    const bbcodez = b.dependency("bbcodez", .{
        .target = target,
        .optimize = optimize,
    });
    const casez = b.dependency("casez", .{
        .target = target,
        .optimize = optimize,
    });
    const temp = b.dependency("temp", .{
        .target = target,
        .optimize = optimize,
    });

    // Always use latest interface header (defines all function pointers)
    const latest_headers = godot.headers(b, default_version);
    // Use requested version for API (classes/methods available)
    const api_headers = godot.headers(b, opt.version);

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
    bindgen_options.addOption([]const u8, "architecture", opt.architecture);
    bindgen_options.addOption([]const u8, "precision", opt.precision);
    bindgen_options.addOptionPath("headers", latest_headers);

    const bindgen_mod = b.addModule("gdzig_bindgen", .{
        .target = b.graph.host,
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
    bindings_run.addArg(opt.precision);
    bindings_run.addArg(opt.architecture);
    bindings_run.addArg(if (b.verbose) "verbose" else "quiet");

    return .{
        .mod = bindgen_mod,
        .exe = bindgen_exe,
        .run = bindings_run,
        .output = bindings_output,
    };
}

const std = @import("std");
const OptimizeMode = std.builtin.OptimizeMode;
const Build = std.Build;
const LazyPath = Build.LazyPath;
const Step = std.Build.Step;
const gdzig_test = @import("gdzig_test/build.zig");
const build_emscripten = @import("build_emscripten.zig");

const godot = @import("godot");
