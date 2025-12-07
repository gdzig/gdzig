/// build the gdzig Godot-Zig binding library
pub fn build(b: *Build) !void {
    const godot_path = b.option([]const u8, "godot", "Path to Godot engine binary [default: `godot`]") orelse "godot";
    const godot_version = b.option([]const u8, "godot_version", "Version string for target Godot version [defaults to version of godot exe provided]") orelse getGodotVersion(b, godot_path);

    if (godot_version.len <= 0) {
        std.debug.print("no godot_version provided and unable to execute godot command {s}\n", .{godot_path});

        return;
    }

    const vendor_path = b.path("vendor");

    // Options
    const opt: Options = .{
        .target = b.standardTargetOptions(.{}),
        .optimize = b.standardOptimizeOption(.{}),
        .godot_path = godot_path,
        .godot_version = godot_version,
        .version_root = vendor_path.path(b, godot_version),
        .precision = b.option([]const u8, "precision", "Floating point precision, either `float` or `double` [default: `float`]") orelse "float",
        .architecture = b.option([]const u8, "arch", "32") orelse "64",
    };

    // Targets
    const bbcodez = buildBbcodez(b);
    const case = buildCase(b);
    const oopz = buildOopz(b);
    const temp = buildTemp(b);

    setupVendorFolders(b, opt) catch |err| {
        std.debug.print("unable to create vendor folder structure: {s}\n", .{opt.version_root.getPath(b)});

        return err;
    };

    const godot_header = generateHeader(b, opt) catch |err| {
        std.debug.print("{}: unable to locate/generate godot headers for version {s} in {s}\n", .{ err, opt.godot_version, opt.version_root.getPath(b) });

        return err;
    };

    const gdextension = buildGdExtension(b, opt, godot_header);
    const gdzig_bindgen = buildBindgen(b, opt);
    const generated = buildGenerated(b, opt, gdzig_bindgen.exe) catch |err| {
        std.debug.print("{}: error running gdzig_bindgen\n", .{err});

        return err;
    };

    const gdzig = buildGdzig(b, opt, generated.output);
    const docs = buildDocs(b, gdzig.lib);
    const tests = buildTests(b, gdzig.mod, gdzig_bindgen.mod);

    // Dependencies
    gdzig_bindgen.mod.addImport("bbcodez", bbcodez.mod);
    gdzig_bindgen.mod.addImport("case", case.mod);
    gdzig_bindgen.mod.addImport("gdextension", gdextension.mod);
    gdzig_bindgen.mod.addImport("temp", temp.mod);

    gdzig.mod.addImport("gdextension", gdextension.mod);
    gdzig.mod.addImport("oopz", oopz.mod);
    gdzig.mod.addImport("case", case.mod);

    // Steps
    b.step("bindgen", "Build the gdzig_bindgen executable").dependOn(&gdzig_bindgen.install.step);
    b.step("generated", "Run bindgen to generate builtin/class code").dependOn(&generated.run.step);
    b.step("docs", "Install docs into zig-out/docs").dependOn(docs.step);

    gdzig.lib.step.dependOn(&generated.run.step);

    const test_ = b.step("test", "Run tests");
    test_.dependOn(&tests.bindgen.step);
    test_.dependOn(&tests.module.step);

    // Install
    b.installArtifact(gdzig_bindgen.exe);
    b.installArtifact(gdzig.lib);
}

const Options = struct {
    target: Target,
    optimize: Optimize,
    godot_path: []const u8,
    godot_version: []const u8,
    version_root: Build.LazyPath,
    precision: []const u8,
    architecture: []const u8,
};

const GdzDependency = struct {
    dep: *Dependency,
    mod: *Module,
};

// Dependency: bbcodez
fn buildBbcodez(
    b: *Build,
) GdzDependency {
    const dep = b.dependency("bbcodez", .{});
    const mod = dep.module("bbcodez");

    return .{ .dep = dep, .mod = mod };
}

// Dependency: case
fn buildCase(
    b: *Build,
) GdzDependency {
    const dep = b.dependency("case", .{});
    const mod = dep.module("case");

    return .{ .dep = dep, .mod = mod };
}

// Dependency: oopz
fn buildOopz(
    b: *Build,
) GdzDependency {
    const dep = b.dependency("oopz", .{});
    const mod = dep.module("oopz");

    return .{ .dep = dep, .mod = mod };
}

// Dependency: temp
fn buildTemp(
    b: *Build,
) GdzDependency {
    const dep = b.dependency("temp", .{});
    const mod = dep.module("temp");

    return .{ .dep = dep, .mod = mod };
}

// Get the version string for the current Godot executable.
fn getGodotVersion(
    b: *Build,
    godot_path: []const u8,
) []const u8 {
    const argv = [_][]const u8{ godot_path, "--version" };
    const output = b.run(&argv);

    return std.mem.trim(u8, output, "\r\n");
}

// Vendor folder structure

fn setupVendorFolders(
    b: *Build,
    opt: Options,
) !void {
    const bd = b.build_root.handle;
    const vrd = try bd.makeOpenPath("vendor", .{});
    const vd = try vrd.makeOpenPath(opt.godot_version, .{});
    try vd.makePath("generated");
}

// GDExtension Headers
fn generateHeader(
    b: *Build,
    opt: Options,
) !Build.LazyPath {
    const header_path = opt.version_root.path(b, "gdextension_interface.h");

    if (fileExists(&header_path, b)) {
        return header_path;
    }

    std.debug.print("re-generating {s}\n", .{header_path.getPath(b)});

    const argv = [_][]const u8{
        opt.godot_path,
        "--dump-extension-api-with-docs",
        "--dump-gdextension-interface",
        "--headless",
    };

    var proc = std.process.Child.init(&argv, b.allocator);

    proc.stdin_behavior = .Ignore;
    proc.stdout_behavior = .Ignore;
    proc.stderr_behavior = .Ignore;
    proc.cwd = opt.version_root.getPath(b);

    try proc.spawn();

    const rc = try proc.wait();

    if (rc.Exited != 0) {
        return error.ExitCode;
    }

    return header_path;
}

// GDExtension
fn buildGdExtension(
    b: *Build,
    opt: Options,
    header: Build.LazyPath,
) struct {
    mod: *Module,
    source: *Step.TranslateC,
} {
    const source = b.addTranslateC(.{
        .link_libc = true,
        .optimize = opt.optimize,
        .target = opt.target,
        .root_source_file = header,
    });

    const mod = b.createModule(.{
        .root_source_file = source.getOutput(),
        .optimize = opt.optimize,
        .target = opt.target,
        .link_libc = true,
    });

    return .{
        .mod = mod,
        .source = source,
    };
}

// Binding Generator
fn buildBindgen(
    b: *Build,
    opt: Options,
) struct {
    install: *Step.InstallArtifact,
    mod: *Module,
    exe: *Step.Compile,
} {
    const mod = b.addModule("gdzig_bindgen", .{
        .target = opt.target,
        .optimize = opt.optimize,
        .root_source_file = b.path("gdzig_bindgen/main.zig"),
        .link_libc = true,
    });

    const options = b.addOptions();
    options.addOption([]const u8, "architecture", opt.architecture);
    options.addOption([]const u8, "precision", opt.precision);
    mod.addOptions("build_options", options);

    const exe = b.addExecutable(.{
        .name = "gdzig-bindgen",
        .root_module = mod,
    });

    const install = b.addInstallArtifact(exe, .{});

    return .{ .install = install, .mod = mod, .exe = exe };
}

// Bindgen
fn buildGenerated(b: *Build, opt: Options, bindgen: *Step.Compile) !struct {
    run: *Step.Run,
    output: Build.LazyPath,
} {
    const files = b.addWriteFiles();
    const input = files.addCopyDirectory(b.path("gdzig"), "input", .{
        .include_extensions = &.{".mixin.zig"},
    });

    const run = b.addRunArtifact(bindgen);
    run.expectExitCode(0);

    run.addDirectoryArg(opt.version_root);
    run.addDirectoryArg(input);
    const output = try opt.version_root.join(b.allocator, "generated");
    run.addDirectoryArg(output);
    run.addArg(opt.precision);
    run.addArg(opt.architecture);
    run.addArg(if (b.verbose) "verbose" else "quiet");

    return .{ .run = run, .output = output };
}

// gdzig
fn buildGdzig(
    b: *Build,
    opt: Options,
    generated: Build.LazyPath,
) struct {
    lib: *Step.Compile,
    mod: *Module,
} {
    const files = b.addWriteFiles();
    const combined = files.addCopyDirectory(b.path("gdzig"), "gdzig", .{
        .exclude_extensions = &.{".mixin.zig"},
    });
    _ = files.addCopyDirectory(generated, "gdzig", .{});

    const mod = b.addModule("gdzig", .{
        .root_source_file = combined.path(b, "gdzig.zig"),
        .target = opt.target,
        .optimize = opt.optimize,
    });

    const lib = b.addLibrary(.{
        .name = "gdzig",
        .root_module = mod,
        .linkage = .static,
        .use_llvm = true,
    });

    const options = b.addOptions();
    options.addOption([]const u8, "architecture", opt.architecture);
    options.addOption([]const u8, "precision", opt.precision);
    mod.addOptions("build_options", options);

    return .{ .lib = lib, .mod = mod };
}

// Tests
fn buildTests(
    b: *Build,
    godot_module: *Module,
    bindgen_module: *Module,
) struct {
    bindgen: *Step.Run,
    module: *Step.Run,
} {
    const bindgen_tests = b.addTest(.{
        .root_module = bindgen_module,
    });
    const module_tests = b.addTest(.{
        .root_module = godot_module,
    });

    const bindgen_run = b.addRunArtifact(bindgen_tests);
    const module_run = b.addRunArtifact(module_tests);

    return .{
        .bindgen = bindgen_run,
        .module = module_run,
    };
}

// Docs
fn buildDocs(
    b: *Build,
    lib: *Step.Compile,
) struct {
    step: *Step,
} {
    const install = b.addInstallDirectory(.{
        .source_dir = lib.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "docs",
    });

    return .{
        .step = &install.step,
    };
}

fn fileExists(lazy_path: *const Build.LazyPath, b: *Build) bool {
    fs.accessAbsolute(lazy_path.getPath(b), .{}) catch {
        return false;
    };

    return true;
}

const std = @import("std");
const fs = std.fs;
const Build = std.Build;
const Dependency = std.Build.Dependency;
const Module = std.Build.Module;
const Optimize = std.builtin.OptimizeMode;
const Step = std.Build.Step;
const Tag = std.meta.Tag;
const Target = std.Build.ResolvedTarget;
