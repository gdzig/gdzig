//! Produces the `gdextension` module by translating `gdextension_interface.h`
//! with the official ZSF translate-c tool
//! (https://codeberg.org/ziglang/translate-c), without declaring it in
//! build.zig.zon.
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
//! pin) into the local cache via `b.addWriteFiles()` and builds it with a
//! nested `zig build` using the same zig binary (`b.graph.zig_exe`). The
//! nested build installs the translate-c exe, the aro resource dir, and the
//! c_builtins/helpers module sources under `<generated>/zig-out/`, all
//! statically known paths.

pub const BuildOptions = struct {
    headers: Build.LazyPath,
    target: Build.ResolvedTarget,
    optimize: OptimizeMode = .Debug,
    /// For web builds, the Emscripten version whose sysroot is used when
    /// translating the gdextension header.
    emsdk_version: []const u8 = "4.0.20",
};

pub fn build(b: *Build, options: BuildOptions) *Build.Module {
    const sdk: ?emsdk.Emsdk = if (options.target.result.cpu.arch.isWasm())
        emsdk.get(b, .{ .version = options.emsdk_version }) orelse
            return placeholderModule(b, options)
    else
        null;

    return translate(b, resolveOptions(b, options, sdk));
}

/// The memoized nested-build step that produces the translate-c exe and the
/// c_builtins/helpers module roots. Consumers of the gdextension module must
/// depend on it.
pub fn toolchainStep(b: *Build) *Build.Step {
    return nestedToolchain(b).step;
}

/// Builds the translate options for the gdextension header. When `sdk` is
/// given (wasm targets), translation additionally uses the emsdk sysroot and
/// runs after the shared emsdk activate step.
fn resolveOptions(b: *Build, options: BuildOptions, sdk: ?emsdk.Emsdk) TranslateOptions {
    var system_include_paths: []const Build.LazyPath = &.{};
    var step_deps: []const *Build.Step = &.{};
    if (sdk) |s| {
        system_include_paths = b.allocator.dupe(Build.LazyPath, &.{s.sysroot_include}) catch @panic("OOM");
        step_deps = b.allocator.dupe(*Build.Step, &.{s.activate_step}) catch @panic("OOM");
    }
    return .{
        .c_source_file = options.headers.path(b, "gdextension_interface.h"),
        .target = options.target,
        .optimize = options.optimize,
        .system_include_paths = system_include_paths,
        .step_deps = step_deps,
    };
}

/// Stand-in module used on wasm while the lazy emsdk dependency is being
/// fetched (pass 1 of the two-pass configure). gdzig's build() must not
/// return early: downstream projects do `dep.module("gdzig")` during pass 1
/// and would panic on the missing module. Pass 1 never reaches the make
/// phase, so the placeholder is never compiled; pass 2 builds the real graph.
fn placeholderModule(b: *Build, options: BuildOptions) *Build.Module {
    const root = b.addWriteFiles().add(
        "gdextension_placeholder.zig",
        "// Placeholder while the lazy emsdk dependency is fetched.\n",
    );
    return b.createModule(.{
        .root_source_file = root,
        .target = options.target,
        .optimize = options.optimize,
        .link_libc = true,
    });
}

const TranslateOptions = struct {
    c_source_file: Build.LazyPath,
    target: Build.ResolvedTarget,
    optimize: OptimizeMode,
    /// Extra system include paths for translation (emsdk sysroot on wasm).
    system_include_paths: []const Build.LazyPath = &.{},
    /// Extra step dependencies for the translate run (emsdk activate on wasm).
    step_deps: []const *Build.Step = &.{},
};

// The translate-c pin. The zig-0.17.x branch is used for ALL supported
// toolchains: it builds and translates correctly on zig master as well
// (verified on 0.18.0-dev.1+a6c6412a8: exe build, header translation, and
// output compilation for native and wasm32-emscripten). This is
// works-today, not supported-by-upstream: if master drift breaks it, CI's
// master leg is the tripwire and the remedy is a second ZON pin on the
// translate-c `main` branch plus a zig_version switch here.
const pin = @import("translate_c_0_17.zon");

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
/// the nested build step; repeat calls reuse them (build() runs twice per
/// configure: root library and bindgen).
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
        \\    .minimum_zig_version = "0.17.0",
        \\    .dependencies = .{{
        \\        .translate_c = .{{
        \\            .url = "{s}",
        \\            .hash = "{s}",
        \\        }},
        \\    }},
        \\    .paths = .{{ "build.zig", "build.zig.zon" }},
        \\}}
        \\
    , .{ pin.url, pin.hash });
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

/// Argument plumbing ported from the zig-0.17.x branch Translator.initInner
/// (identical shape on main; order matters; probe-validated at the CLI with
/// the real 2.0.0 exe for wasm32-emscripten).
fn translate(b: *Build, options: TranslateOptions) *Build.Module {
    const toolchain = nestedToolchain(b);
    const target = options.target;

    const run = Build.Step.Run.create(b, "translate-c gdextension_interface");
    run.addFileArg(toolchain.exe); // argv[0]: the nested-built translate-c exe
    run.step.dependOn(toolchain.step);
    for (options.step_deps) |dep| run.step.dependOn(dep);

    const output_file = run.addPrefixedOutputFileArg("-o=", "gdextension_interface.zig");

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

const std = @import("std");
const Build = std.Build;
const OptimizeMode = std.builtin.OptimizeMode;

const emsdk = @import("emsdk.zig");
