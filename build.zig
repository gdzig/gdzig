pub fn build(b: *Build) !void {
    // Options
    const opt: Options = .{
        .target = b.standardTargetOptions(.{}),
        .optimize = b.standardOptimizeOption(.{}),
        .godot_path = b.option([]const u8, "godot", "Path to Godot engine binary [default: `godot`]") orelse "godot",
        .precision = b.option([]const u8, "precision", "Floating point precision, either `float` or `double` [default: `float`]") orelse "float",
        .architecture = b.option([]const u8, "arch", "32") orelse "64",
        .headers = blk: {
            const input = b.option([]const u8, "headers", "Where to source Godot header files. [options: GENERATED, VENDORED, DEPENDENCY, <dir_path>] [default: GENERATED]") orelse "GENERATED";
            const normalized = std.ascii.allocLowerString(b.allocator, input) catch unreachable;
            const tag = std.meta.stringToEnum(Tag(HeadersSource), normalized);
            break :blk if (tag) |t| switch (t) {
                .dependency => .dependency,
                .generated => .generated,
                .vendored => .vendored,
                // edge case if the user uses the literal path "custom"
                .custom => .{ .custom = b.path("custom") },
            } else if (normalized.len == 0)
                .generated
            else
                .{ .custom = b.path(normalized) };
        },
    };

    // Targets
    const case = buildCase(b);
    const mvzr = buildMvzr(b);
    const vector_z = buildVectorZ(b, opt);
    const zimdjson = buildZimdjson(b);
    const bbcodez = buildBbcodez(b);
    const temp = buildTemp(b);

    const headers = installHeaders(b, opt);

    const gdextension = buildGdExtension(b, opt, headers.header);
    const bindgen = buildBindgen(b, opt);
    const bindings = buildBindings(b, opt, bindgen.exe, headers.root);

    const gdzig = buildLibrary(b, opt, bindings.path);
    const docs = buildDocs(b, gdzig.lib);
    const tests = buildTests(b, gdzig.mod, bindgen.mod);

    // Dependencies
    bindgen.mod.addImport("gdextension", gdextension.mod);
    bindgen.mod.addImport("case", case.mod);
    bindgen.mod.addImport("mvzr", mvzr.mod);
    bindgen.mod.addImport("zimdjson", zimdjson.mod);
    bindgen.mod.addImport("bbcodez", bbcodez.mod);
    bindgen.mod.addImport("temp", temp.mod);

    gdzig.mod.addImport("gdextension", gdextension.mod);
    gdzig.mod.addImport("vector", vector_z.mod);

    // Steps
    b.step("bindgen", "Build the bindgen executable").dependOn(&bindgen.install.step);
    b.step("bindings", "Generate bindings").dependOn(&bindings.install.step);
    b.step("docs", "Install docs into zig-out/docs").dependOn(docs.step);

    const test_ = b.step("test", "Run tests");
    test_.dependOn(&tests.bindgen.step);
    test_.dependOn(&tests.module.step);

    // Install
    b.installArtifact(bindgen.exe);
    b.installArtifact(gdzig.lib);
}

const HeadersSource = union(enum) {
    dependency: void,
    vendored: void,
    generated: void,
    custom: Build.LazyPath,
};

const Options = struct {
    target: Target,
    optimize: Optimize,
    godot_path: []const u8,
    precision: []const u8,
    architecture: []const u8,
    headers: HeadersSource,
};

const GdzDependency = struct {
    dep: *Dependency,
    mod: *Module,
};

// Dependency: case
fn buildCase(
    b: *Build,
) GdzDependency {
    const dep = b.dependency("case", .{});
    const mod = dep.module("case");

    return .{ .dep = dep, .mod = mod };
}

// Dependency: vector_z
fn buildVectorZ(
    b: *Build,
    opt: Options,
) GdzDependency {
    const dep = b.dependency("vector_z", .{ .precision = opt.precision });
    const mod = dep.module("vector_z");

    return .{ .dep = dep, .mod = mod };
}

// Dependency: mvzr
fn buildMvzr(
    b: *Build,
) GdzDependency {
    const dep = b.dependency("mvzr", .{});
    const mod = dep.module("mvzr");

    return .{ .dep = dep, .mod = mod };
}

// Dependency: zimdjson
fn buildZimdjson(
    b: *Build,
) GdzDependency {
    const dep = b.dependency("zimdjson", .{});
    const mod = dep.module("zimdjson");

    return .{ .dep = dep, .mod = mod };
}

// Dependency: bbcodez
fn buildBbcodez(
    b: *Build,
) GdzDependency {
    const dep = b.dependency("bbcodez", .{});
    const mod = dep.module("bbcodez");

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

// GDExtension Headers
fn installHeaders(
    b: *Build,
    opt: Options,
) struct {
    root: Build.LazyPath,
    api: Build.LazyPath,
    header: Build.LazyPath,
} {
    const files = b.addWriteFiles();
    const out = switch (opt.headers) {
        .dependency => b.dependency("godot_cpp", .{}).path("gdextension"),
        .generated => blk: {
            const tmp = b.addWriteFiles();
            const out = tmp.getDirectory();
            const dump = b.addSystemCommand(&.{
                opt.godot_path,
                "--dump-extension-api-with-docs",
                "--dump-gdextension-interface",
                "--headless",
            });
            dump.setCwd(out);
            _ = dump.captureStdOut();
            _ = dump.captureStdErr();
            files.step.dependOn(&dump.step);
            break :blk out;
        },
        .vendored => b.path("vendor"),
        .custom => |root| root,
    };

    return .{
        .root = files.getDirectory(),
        .api = files.addCopyFile(out.path(b, "extension_api.json"), "extension_api.json"),
        .header = files.addCopyFile(out.path(b, "gdextension_interface.h"), "gdextension_interface.h"),
    };
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
    const mod = b.addModule("bindgen", .{
        .target = opt.target,
        .optimize = opt.optimize,
        .root_source_file = b.path("bindgen/main.zig"),
        .link_libc = true,
    });

    const options = b.addOptions();
    options.addOption([]const u8, "architecture", opt.architecture);
    options.addOption([]const u8, "precision", opt.precision);
    mod.addOptions("build_options", options);

    const exe = b.addExecutable(.{
        .name = "bindgen",
        .root_module = mod,
    });

    const install = b.addInstallArtifact(exe, .{});

    return .{ .install = install, .mod = mod, .exe = exe };
}

// Bindgen
fn buildBindings(
    b: *Build,
    opt: Options,
    bindgen: *Step.Compile,
    headers: Build.LazyPath,
) struct {
    run: *Step.Run,
    install: *Step.InstallDir,
    path: Build.LazyPath,
} {
    const run = b.addRunArtifact(bindgen);
    run.addDirectoryArg(headers);
    const path = run.addOutputDirectoryArg(b.path("bindings").getPath(b));
    run.addArg(opt.precision);
    run.addArg(opt.architecture);
    run.addArg(if (b.verbose) "verbose" else "quiet");

    const install = b.addInstallDirectory(.{
        .source_dir = path,
        .install_dir = .prefix,
        .install_subdir = "bindings",
    });

    return .{ .install = install, .run = run, .path = path };
}

// Godot
fn buildLibrary(
    b: *Build,
    opt: Options,
    bindings: Build.LazyPath,
) struct {
    lib: *Step.Compile,
    mod: *Module,
} {
    const tmp = b.addWriteFiles();
    const src = tmp.addCopyDirectory(b.path("src"), "./", .{});
    _ = tmp.addCopyDirectory(bindings, "./bindings", .{});

    const root = b.addModule("gdzig", .{
        .root_source_file = src.path(b, "root.zig"),
        .target = opt.target,
        .optimize = opt.optimize,
    });

    const options = b.addOptions();
    options.addOption([]const u8, "architecture", opt.architecture);
    options.addOption([]const u8, "precision", opt.precision);
    root.addOptions("build_options", options);

    const lib = b.addLibrary(.{
        .name = "gdzig",
        .root_module = root,
        .linkage = .dynamic,
    });

    return .{ .lib = lib, .mod = root };
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

const std = @import("std");
const Build = std.Build;
const Dependency = std.Build.Dependency;
const Module = std.Build.Module;
const Optimize = std.builtin.OptimizeMode;
const Step = std.Build.Step;
const Tag = std.meta.Tag;
const Target = std.Build.ResolvedTarget;
