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
    return translate(b, toolchain, options);
}

/// The memoized nested-build step that produces the translate-c exe and the
/// c_builtins/helpers module roots. Consumers of a Translated module must
/// depend on it.
pub fn nestedBuildStep(b: *Build) *Build.Step {
    return nestedToolchain(b).step;
}

// The pin for the running toolchain. Pins live in ZON configs so per-branch
// bumps are data edits and a foreign-branch config is inert data (ZON import
// is comptime deserialization; nothing foreign is ever analyzed). The master
// pin tracks `main` best effort per ADR 0001; CI's master leg catches drift.
const pin = switch (builtin.zig_version.minor) {
    17 => @import("translate_c_0_17.zon"),
    else => @import("translate_c_main.zon"),
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

/// Argument plumbing ported from the zig-0.17.x branch Translator.initInner
/// (identical shape on main; order matters; probe-validated at the CLI with
/// the real 2.0.0 exe for wasm32-emscripten).
fn translate(b: *Build, toolchain: Toolchain, options: Options) Translated {
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
