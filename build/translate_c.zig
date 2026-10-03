//! Runs the official ZSF translate-c tool (https://codeberg.org/ziglang/translate-c)
//! to translate C headers, without declaring it in build.zig.zon.
//!
//! Why no zon dependency: the build runner analyzes every *available*
//! dependency's build.zig (the `dependencyInner` inline-for instantiates
//! `runBuild` per package), and "available" means "present in the shared
//! global package cache". The translate-c package maintains a separate
//! branch per Zig version whose build.zig only compiles on that version, so
//! any pin breaks the other toolchains as soon as it lands in the shared
//! cache (probe-verified on 0.16.0 and 0.17.0; see gdzig#260).
//!
//! Instead, this module generates a minimal throwaway package (single zon
//! pin matching the running toolchain) into the local cache via
//! `b.addWriteFiles()` and builds it with a nested `zig build` using the
//! same zig binary (`b.graph.zig_exe`). The nested build installs the
//! translate-c exe, the aro resource dir, and the c_builtins/helpers module
//! sources under `<generated>/zig-out/`, all statically known paths.

pub const Translated = struct {
    /// Module rooted at the translated Zig source, importing c_builtins and
    /// helpers. Consumers' compile steps must depend on `nestedBuildStep(b)`
    /// (wired automatically via the translate run's step dependencies).
    mod: *Build.Module,
    /// The step that runs translate-c.
    run: *Build.Step.Run,
    /// The translated Zig source file.
    output_file: Build.LazyPath,
};

pub const Options = struct {
    name: []const u8,
    c_source_file: Build.LazyPath,
    target: Build.ResolvedTarget,
    optimize: OptimizeMode,
    /// Extra system include paths for translation (emsdk sysroot on wasm).
    system_include_paths: []const Build.LazyPath = &.{},
    /// Extra step dependencies for the translate run (emsdk activate on wasm).
    step_deps: []const *Build.Step = &.{},
};

pub fn translateC(b: *Build, options: Options) Translated {
    const toolchain = nestedToolchain(b);
    // Only the selected prong is analyzed (comptime-known operand), so each
    // branch may use std APIs that only exist on its own toolchain.
    return switch (builtin.zig_version.minor) {
        16 => translate016(b, toolchain, options),
        else => translateModern(b, toolchain, options),
    };
}

/// The memoized nested-build step that produces the translate-c exe and the
/// c_builtins/helpers module roots. Consumers of a Translated module must
/// depend on it.
pub fn nestedBuildStep(b: *Build) *Build.Step {
    return nestedToolchain(b).step;
}

// TODO(zig 0.16.0): when 0.16.x support is dropped, delete the 0.16 pin and
// translate016; the modern branch covers everything else.
//
// Pins are per-Zig-version branches of the ZSF translate-c package, verified
// with `zig fetch`. The master pin tracks `main` (best effort per ADR 0001;
// CI's master leg catches drift).
const pin_url = switch (builtin.zig_version.minor) {
    16 => "git+https://codeberg.org/ziglang/translate-c#6fe0ffc4549f15c5f2d9432c2b4460ba90ff85ac", // zig-0.16.x
    17 => "git+https://codeberg.org/ziglang/translate-c#02ff0c523fb92a38939b04d0145c4a9602a74d56", // zig-0.17.x
    else => "git+https://codeberg.org/ziglang/translate-c#875969d3493e245e01bf5d7860f792d8f3eb9ef5", // main
};
const pin_hash = switch (builtin.zig_version.minor) {
    16 => "translate_c-1.0.0-Q_BUWo_5BgD4flHdUhA31zOz0XvZk9k7lQv1ouzyNXj2",
    17 => "translate_c-2.0.0-Q_BUWltOBwBYABF84EUL208pIFeUIwbBs29FmVBaafN5",
    else => "translate_c-0.0.0-Q_BUWoFOBwAhz77Zd15HCVuhTKzdUKc94kezmCeJ7IC_",
};

const step_name = "gdzig-translate-c-exe";
const pkg_path_name = "gdzig-translate-c-pkg";

const Toolchain = struct {
    exe: Build.LazyPath,
    aro_resource_dir: Build.LazyPath,
    c_builtins_root: Build.LazyPath,
    helpers_root: Build.LazyPath,
    step: *Build.Step,
};

/// Memoized per builder: the first call generates the throwaway package and
/// the nested build step; repeat calls reuse them (gdextension.build runs
/// twice per configure: root library and bindgen).
fn nestedToolchain(b: *Build) Toolchain {
    if (b.top_level_steps.get(step_name)) |tls| {
        const pkg_dir = b.named_lazy_paths.get(pkg_path_name).?;
        return toolchainPaths(b, pkg_dir, &tls.step);
    }

    const wf = b.addWriteFiles();
    _ = wf.add("build.zig.zon", generatedZon(b));
    _ = wf.add("build.zig", generated_build_zig);
    const pkg_dir = wf.getDirectory();
    b.addNamedLazyPath(pkg_path_name, pkg_dir);

    const nested = b.addSystemCommand(&.{ b.graph.zig_exe, "build", "--prefix", "zig-out" });
    nested.setName("nested zig build (translate-c)");
    nested.setCwd(pkg_dir);

    const step = b.step(step_name, "Build the ZSF translate-c tool (nested zig build)");
    step.dependOn(&nested.step);
    return toolchainPaths(b, pkg_dir, step);
}

fn toolchainPaths(b: *Build, pkg_dir: Build.LazyPath, step: *Build.Step) Toolchain {
    const exe_sub_path = if (b.graph.host.result.os.tag == .windows)
        "zig-out/bin/translate-c.exe"
    else
        "zig-out/bin/translate-c";
    return .{
        .exe = pkg_dir.path(b, exe_sub_path),
        .aro_resource_dir = pkg_dir.path(b, "zig-out/aro"),
        .c_builtins_root = pkg_dir.path(b, "zig-out/lib/c_builtins.zig"),
        .helpers_root = pkg_dir.path(b, "zig-out/lib/helpers.zig"),
        .step = step,
    };
}

fn generatedZon(b: *Build) []const u8 {
    return b.fmt(
        \\.{{
        \\    .name = .gdzig_translate_c,
        \\    .version = "0.0.0",
        \\    .fingerprint = 0x7e5c92f9743f2293,
        \\    .minimum_zig_version = "0.16.0",
        \\    .dependencies = .{{
        \\        .translate_c = .{{
        \\            .url = "{s}",
        \\            .hash = "{s}",
        \\        }},
        \\    }},
        \\    .paths = .{{ "build.zig", "build.zig.zon" }},
        \\}}
        \\
    , .{ pin_url, pin_hash });
}

const generated_build_zig =
    \\pub fn build(b: *std.Build) void {
    \\    const tc = b.dependency("translate_c", .{});
    \\    b.installArtifact(tc.artifact("translate-c"));
    \\    const aro = tc.builder.dependency("aro", .{});
    \\    b.installDirectory(.{ .source_dir = aro.path(""), .install_dir = .prefix, .install_subdir = "aro" });
    \\    b.installDirectory(.{ .source_dir = tc.path("lib"), .install_dir = .prefix, .install_subdir = "lib" });
    \\}
    \\
    \\const std = @import("std");
    \\
;

fn makeResultModule(b: *Build, toolchain: Toolchain, options: Options, output_file: Build.LazyPath) *Build.Module {
    const mod = b.createModule(.{
        .root_source_file = output_file,
        .target = options.target,
        .optimize = options.optimize,
        .link_libc = true,
    });
    mod.addImport("c_builtins", b.createModule(.{
        .root_source_file = toolchain.c_builtins_root,
    }));
    mod.addImport("helpers", b.createModule(.{
        .root_source_file = toolchain.helpers_root,
    }));
    for (options.system_include_paths) |p| mod.addSystemIncludePath(p);
    return mod;
}

fn createRun(b: *Build, toolchain: Toolchain, options: Options) *Build.Step.Run {
    const run = Build.Step.Run.create(b, b.fmt("translate-c {s}", .{options.name}));
    run.addFileArg(toolchain.exe); // argv[0]: the nested-built translate-c exe
    run.step.dependOn(toolchain.step);
    for (options.step_deps) |dep| run.step.dependOn(dep);
    return run;
}

/// Argument plumbing ported from the zig-0.16.x branch Translator.initInner
/// (order matters; probe-validated end-to-end on 0.16.0).
fn translate016(b: *Build, toolchain: Toolchain, options: Options) Translated {
    const target = options.target;
    const run = createRun(b, toolchain, options);

    run.addFileArg(options.c_source_file);
    run.addArg("-o");
    const output_file = run.addOutputFileArg(b.fmt("{s}.zig", .{options.name}));
    run.addArgs(&.{ "-MD", "-MV", "-MF" });
    _ = run.addDepFileOutputArg("deps.d");

    if (!target.query.isNative()) {
        const triple = target.query.zigTriple(b.graph.arena) catch @panic("OOM");
        run.addArg(b.fmt("--target={s}", .{triple}));
    }

    // gdextension always links libc. For cross targets (and non-Linux
    // natives) translate-c needs the libc dirs spelled out; for
    // wasm32-emscripten LibCDirs.detect yields empty dirs (zig cannot build
    // emscripten libc), so -nostdlibinc plus the caller's -isystem sysroot
    // is exactly right.
    if (!target.query.isNative() or target.result.os.tag != .linux) {
        run.addArg("-nostdlibinc");
        const libc = std.zig.LibCDirs.detect(
            b.graph.arena,
            b.graph.io,
            b.graph.zig_lib_directory.path orelse ".",
            &target.result,
            target.query.isNativeAbi(),
            true,
            null,
            &b.graph.environ_map,
        ) catch |err| std.debug.panic("failed to locate libc: {s}", .{@errorName(err)});
        for (libc.libc_include_dir_list) |include_dir| {
            run.addArg("-isystem");
            run.addDirectoryArg(.{ .cwd_relative = include_dir });
        }
        for (libc.libc_framework_dir_list) |framework_dir| {
            run.addArg("-iframework");
            run.addDirectoryArg(.{ .cwd_relative = framework_dir });
        }
        const clang_include = b.graph.zig_lib_directory.join(b.graph.arena, &.{"include"}) catch @panic("OOM");
        run.addArg("-idirafter");
        run.addDirectoryArg(.{ .cwd_relative = clang_include });
    }

    if (target.query.isNativeOs() and target.query.isNativeAbi()) {
        const paths = std.zig.system.NativePaths.detect(
            b.graph.arena,
            b.graph.io,
            &target.result,
            &b.graph.environ_map,
        ) catch |err| std.debug.panic("failed to detect native system paths: {s}", .{@errorName(err)});
        for (paths.warnings.items) |warning| {
            std.log.warn("{s}", .{warning});
        }
        for (paths.include_dirs.items) |include_dir| {
            run.addArg("-isystem");
            run.addDirectoryArg(.{ .cwd_relative = include_dir });
        }
        for (paths.framework_dirs.items) |framework_dir| {
            run.addArg("-iframework");
            run.addDirectoryArg(.{ .cwd_relative = framework_dir });
        }
    }

    for (b.search_prefixes.items) |search_prefix| {
        run.addArg("-I");
        run.addDirectoryArg(.{ .cwd_relative = b.pathJoin(&.{ search_prefix, "include" }) });
    }

    run.addArg("-w");
    run.addArg("-fmodule-libs");
    // Match zig's built-in translate-c: struct fields get `= null` defaults
    // (src/extension/class.zig initializes callback structs partially).
    run.addArg("-fdefault-init");
    run.addArg("-resource-dir");
    run.addDirectoryArg(toolchain.aro_resource_dir);

    for (options.system_include_paths) |p| {
        run.addArg("-isystem");
        run.addDirectoryArg(p);
    }

    return .{
        .mod = makeResultModule(b, toolchain, options, output_file),
        .run = run,
        .output_file = output_file,
    };
}

/// Argument plumbing ported from the zig-0.17.x branch Translator.initInner
/// (identical shape on main; order matters; probe-validated at the CLI with
/// the real 2.0.0 exe for wasm32-emscripten).
fn translateModern(b: *Build, toolchain: Toolchain, options: Options) Translated {
    const target = options.target;
    const run = createRun(b, toolchain, options);

    const output_file = run.addPrefixedOutputFileArg("-o=", b.fmt("{s}.zig", .{options.name}));

    if (options.optimize != .debug) {
        run.addArg(b.fmt("-O={t}", .{options.optimize}));
    }

    if (!target.query.isNative()) {
        const triple = target.query.zigTriple(b.graph.arena) catch @panic("OOM");
        const model = target.query.serializeCpuAlloc(b.graph.arena) catch @panic("OOM");
        run.addArg(b.fmt("--target={s}", .{triple}));
        run.addArg(b.fmt("-mcpu={s}", .{model}));
    }

    run.addArg("-lc");
    run.addPrefixedDirectoryArg("--zig-lib=", .zig_lib);
    run.addArg("-fmodule-libs");
    // Match zig's built-in translate-c: struct fields get `= null` defaults
    // (src/extension/class.zig initializes callback structs partially).
    run.addArg("-fdefault-init");

    // Aro arguments follow `--`.
    run.addArg("--");
    for (options.system_include_paths) |p| {
        run.addArg("-isystem");
        run.addDirectoryArg(p);
    }

    run.addFileArg(options.c_source_file);
    run.addArgs(&.{ "-MD", "-MV", "-MF" });
    _ = run.addDepFileOutputArg("deps.d");

    run.addArg("-w");
    run.addArg("-resource-dir");
    run.addDirectoryArg(toolchain.aro_resource_dir);

    return .{
        .mod = makeResultModule(b, toolchain, options, output_file),
        .run = run,
        .output_file = output_file,
    };
}

const std = @import("std");
const builtin = @import("builtin");
const Build = std.Build;
const OptimizeMode = std.builtin.OptimizeMode;
