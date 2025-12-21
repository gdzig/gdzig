/// Initialization level for GDExtension.
pub const InitializationLevel = enum {
    core,
    servers,
    scene,
    editor,
};

/// Options for creating a GDExtension.
pub const ExtensionOptions = struct {
    /// The extension module. Must export `pub fn register(r: *godot.extension.Registry) void`.
    root_module: *Build.Module,
    /// The symbol name for the extension entry point.
    entry_symbol: []const u8 = "gdextension_entry",
    /// The minimum initialization level for the extension.
    minimum_initialization_level: InitializationLevel = .scene,
    target: Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    /// For web builds, the Emscripten SDK path (optional, auto-fetched if not provided).
    emsdk_path: ?Build.LazyPath = null,
    /// For web builds, the Emscripten version to use.
    emsdk_version: []const u8 = "4.0.20",
};

/// A GDExtension build artifact.
///
/// Handles both native and web (wasm32-emscripten) targets automatically.
/// For web builds, runs emscripten to produce the final .wasm file.
pub const Extension = struct {
    /// The step to depend on for building this extension.
    step: *Step,
    /// The underlying compile step.
    compile: *Build.Step.Compile,
    /// The output file (.so/.dylib/.dll for native, .wasm for web).
    output: Build.LazyPath,
    /// The output filename.
    filename: []const u8,
};

/// Creates a GDExtension from a user module.
///
/// Handles both native and web (wasm32-emscripten) targets automatically.
/// For web builds, uses emscripten to produce a .wasm file.
///
/// Returns an ExtensionStep, or null if waiting for lazy dependencies.
pub fn addExtension(b: *Build, options: ExtensionOptions) ?*Extension {
    const dep = getSelfDependency(b);
    const is_wasm = options.target.result.cpu.arch.isWasm();

    const build_options = b.addOptions();
    build_options.addOption([]const u8, "entry_symbol", options.entry_symbol);
    build_options.addOption(InitializationLevel, "minimum_initialization_level", options.minimum_initialization_level);

    const mod = b.createModule(.{
        .root_source_file = dep.path("src/extension/entrypoint.zig"),
        .target = options.target,
        .optimize = options.optimize,
        .imports = &.{
            .{ .name = "gdzig", .module = dep.module("gdzig") },
            .{ .name = "extension", .module = options.root_module },
            .{ .name = "options", .module = build_options.createModule() },
        },
    });

    if (is_wasm) {
        return addExtensionWeb(b, dep, mod, options);
    } else {
        const lib = b.addLibrary(.{
            .linkage = .dynamic,
            .name = "extension",
            .root_module = mod,
            .use_llvm = true,
        });

        const ext = b.allocator.create(Extension) catch @panic("OOM");
        ext.* = .{
            .step = &lib.step,
            .compile = lib,
            .output = lib.getEmittedBin(),
            .filename = lib.out_filename,
        };
        return ext;
    }
}

fn addExtensionWeb(
    b: *Build,
    dep: *Build.Dependency,
    mod: *Build.Module,
    options: ExtensionOptions,
) ?*Extension {
    const emsdk_path = if (options.emsdk_path) |p| p else blk: {
        const emsdk_dep = dep.builder.lazyDependency("emsdk", .{}) orelse return null;
        break :blk emsdk_dep.path("");
    };

    mod.pic = true;
    mod.strip = false;

    const lib = b.addLibrary(.{
        .linkage = .static,
        .name = "extension",
        .root_module = mod,
    });

    // Install and activate emsdk
    const emsdk_script = if (b.graph.host.result.os.tag == .windows) "emsdk.bat" else "emsdk";
    const install_emsdk = b.addSystemCommand(&.{emsdk_path.path(b, emsdk_script).getPath(b)});
    install_emsdk.addArgs(&.{ "install", options.emsdk_version });

    const activate_emsdk = b.addSystemCommand(&.{emsdk_path.path(b, emsdk_script).getPath(b)});
    activate_emsdk.addArgs(&.{ "activate", options.emsdk_version });
    activate_emsdk.step.dependOn(&install_emsdk.step);

    lib.step.dependOn(&activate_emsdk.step);
    lib.addSystemIncludePath(emsdk_path.path(b, "upstream/emscripten/cache/sysroot/include"));

    // Run emcc to produce final .wasm
    const optimize = options.optimize;
    const single_threaded = mod.single_threaded orelse false;

    const run_emcc = b.addSystemCommand(&.{emsdk_path.path(b, "upstream/emscripten/emcc").getPath(b)});
    run_emcc.addArtifactArg(lib);

    run_emcc.addArgs(&.{
        "-sSIDE_MODULE=1",
        "-sWASM_BIGINT",
        "-sSUPPORT_LONGJMP='wasm'",
    });

    if (!single_threaded) {
        run_emcc.addArg("-sUSE_PTHREADS=1");
    }

    run_emcc.addArgs(switch (optimize) {
        .Debug => &.{
            "-O0",
            "-g3",
            "-fsanitize=undefined",
        },
        .ReleaseSafe => &.{
            "-O3",
            "-fsanitize=undefined",
            "-fsanitize-minimal-runtime",
        },
        .ReleaseFast => &.{"-O3"},
        .ReleaseSmall => &.{"-Oz"},
    });

    if (optimize != .Debug) {
        run_emcc.addArgs(&.{
            "-flto",
            "--closure",
            "1",
        });
    }

    run_emcc.addArg("-o");
    const wasm_filename = b.fmt("lib{s}.wasm", .{lib.name});
    const wasm_output = run_emcc.addOutputFileArg(wasm_filename);

    const ext = b.allocator.create(Extension) catch @panic("OOM");
    ext.* = .{
        .step = &run_emcc.step,
        .compile = lib,
        .output = wasm_output,
        .filename = wasm_filename,
    };
    return ext;
}

/// Options for adding a Godot test.
pub const TestOptions = struct {
    /// Name for this test (used in output paths).
    name: []const u8 = "test",
    /// The module to test. Tests are discovered from `test {}` blocks in this module.
    root_module: *Build.Module,
    /// Build target.
    target: Build.ResolvedTarget,
    /// Optimization mode.
    optimize: std.builtin.OptimizeMode,
    /// Initialization level for the test extension.
    initialization_level: InitializationLevel = .scene,
};

/// Add a Godot integration test to the build.
///
/// Tests are discovered from `test {}` blocks in the provided module.
/// A minimal Godot project is generated automatically.
pub fn addTest(b: *Build, options: TestOptions) *Step.Run {
    const dep = getSelfDependency(b);
    return addTestImpl(b, .{ .b = b, .dep = dep }, options);
}

pub fn addTestImpl(b: *Build, paths: Resolver, options: TestOptions) *Step.Run {
    const gdzig_mod = paths.module("gdzig");

    const entry_options = b.addOptions();
    entry_options.addOption([]const u8, "entry_symbol", "gdextension_entry");
    entry_options.addOption(InitializationLevel, "minimum_initialization_level", options.initialization_level);

    const mod = b.createModule(.{
        .root_source_file = options.root_module.root_source_file,
        .target = options.target,
        .optimize = options.optimize,
        .pic = true,
    });
    mod.import_table = options.root_module.import_table.clone(b.allocator) catch @panic("OOM");
    mod.addImport("gdzig", gdzig_mod);
    mod.addImport("options", entry_options.createModule());

    const obj = b.addTest(.{
        .name = options.name,
        .root_module = mod,
        .test_runner = .{ .path = paths.path("src/testing/harness.zig"), .mode = .simple },
        .emit_object = true,
        .use_llvm = true,
    });
    obj.entry = .disabled;

    const lib = b.addLibrary(.{
        .name = options.name,
        .linkage = .dynamic,
        .root_module = b.createModule(.{ .target = options.target, .optimize = options.optimize }),
    });
    lib.addObject(obj);

    const install_subdir = b.fmt("test/{s}", .{options.name});
    const install_ext = b.addInstallArtifact(lib, .{
        .dest_dir = .{ .override = .{ .custom = install_subdir } },
    });

    const project_files = b.addWriteFiles();
    _ = project_files.add("test_extension.gdextension", generateGdextension(b, lib.out_filename));
    _ = project_files.add("project.godot", generateProjectGodot(b, options.name));

    const install_project = b.addInstallDirectory(.{
        .source_dir = project_files.getDirectory(),
        .install_dir = .{ .custom = install_subdir },
        .install_subdir = "",
    });
    install_project.step.dependOn(&install_ext.step);

    const runner_options = b.addOptions();
    runner_options.addOption([]const []const u8, "test_folders", &.{
        b.fmt("{s}/{s}", .{ b.install_path, install_subdir }),
    });
    runner_options.addOptionPath("godot_exe", paths.namedLazyPath("godot"));

    const coordinator = b.addExecutable(.{
        .name = b.fmt("test-{s}", .{options.name}),
        .root_module = b.createModule(.{
            .root_source_file = paths.path("src/testing/coordinator.zig"),
            .target = b.graph.host,
            .optimize = .Debug,
            .imports = &.{
                .{ .name = "runner_options", .module = runner_options.createModule() },
            },
        }),
    });

    const run = b.addRunArtifact(coordinator);
    run.enableTestRunnerMode();
    run.step.dependOn(&install_project.step);
    return run;
}

// ============================================================================
// Internal helpers
// ============================================================================

/// Resolves paths and modules from either the current build (when building gdzig itself)
/// or from a dependency (when gdzig is used as a dependency by downstream projects).
pub const Resolver = struct {
    b: *Build,
    dep: ?*Build.Dependency,

    pub fn path(self: Resolver, sub_path: []const u8) Build.LazyPath {
        if (self.dep) |d| {
            return d.path(sub_path);
        }
        return self.b.path(sub_path);
    }

    pub fn namedLazyPath(self: Resolver, name: []const u8) Build.LazyPath {
        if (self.dep) |d| {
            return d.namedLazyPath(name);
        }
        return self.b.named_lazy_paths.get(name).?;
    }

    pub fn module(self: Resolver, name: []const u8) *Build.Module {
        if (self.dep) |d| {
            return d.module(name);
        }
        return self.b.modules.get(name).?;
    }
};

/// Find the gdzig dependency from a downstream project's build context.
fn getSelfDependency(b: *Build) *Build.Dependency {
    const build_runner = @import("root");
    const deps = build_runner.dependencies;
    const build_zig = @import("../build.zig");

    inline for (@typeInfo(deps.packages).@"struct".decls) |decl| {
        const pkg_hash = decl.name;
        const pkg = @field(deps.packages, pkg_hash);
        if (@hasDecl(pkg, "build_zig") and pkg.build_zig == build_zig) {
            for (b.available_deps) |available| {
                if (std.mem.eql(u8, available[1], pkg_hash)) {
                    const build_root = pkg.build_root;
                    var it = b.graph.dependency_cache.iterator();
                    while (it.next()) |entry| {
                        if (std.mem.eql(u8, entry.key_ptr.build_root_string, build_root)) {
                            return entry.value_ptr.*;
                        }
                    }
                    @panic("gdzig dependency not initialized. Call b.dependency(\"gdzig\", ...) before using gdzig build functions");
                }
            }
        }
    }

    @panic("Could not find gdzig as dependency");
}

fn generateProjectGodot(b: *Build, name: []const u8) []const u8 {
    return b.fmt(
        \\; Minimal Godot project for gdzig tests
        \\config_version=5
        \\
        \\[application]
        \\config/name="{s}"
        \\
        \\[rendering]
        \\renderer/rendering_method="gl_compatibility"
        \\
    , .{name});
}

fn generateGdextension(b: *Build, lib_name: []const u8) []const u8 {
    return b.fmt(
        \\[configuration]
        \\entry_symbol = "gdextension_entry"
        \\compatibility_minimum = "4.2"
        \\
        \\[libraries]
        \\linux.debug.x86_64 = "res://{s}"
        \\linux.release.x86_64 = "res://{s}"
        \\windows.debug.x86_64 = "res://{s}"
        \\windows.release.x86_64 = "res://{s}"
        \\macos.debug.arm64 = "res://{s}"
        \\macos.release.arm64 = "res://{s}"
        \\macos.debug.x86_64 = "res://{s}"
        \\macos.release.x86_64 = "res://{s}"
    , .{ lib_name, lib_name, lib_name, lib_name, lib_name, lib_name, lib_name, lib_name });
}

const std = @import("std");
const Build = std.Build;
const Step = std.Build.Step;
