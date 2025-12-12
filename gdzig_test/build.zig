pub fn addTestCases(b: *Build, opts: struct {
    root_dir: Build.LazyPath,
    gdzig: *Build.Module,
    godot: []const u8,
    target: ?Build.ResolvedTarget = null,
    optimize: ?OptimizeMode = null,
}) *Build.Step.Run {
    const tests = buildTestCases(b, .{
        .root_dir = opts.root_dir,
        .gdzig = opts.gdzig,
        .target = opts.target,
        .optimize = opts.optimize,
    });

    const runner = b.addExecutable(.{
        .name = "gdzig-test-runner",
        .root_module = b.createModule(.{
            .root_source_file = b.path("gdzig_test/runner.zig"),
            .target = opts.target orelse b.graph.host,
            .optimize = opts.optimize orelse .Debug,
        }),
    });

    const run = b.addRunArtifact(runner);
    run.addArg(b.fmt("--godot={s}", .{opts.godot}));

    for (tests) |t| {
        run.addArg("--test");
        run.addArg(t.name);
        run.addDirectoryArg(t.project_dir);
        if (t.script) |script| {
            run.addArg("--script");
            run.addArg(script);
        }
    }

    run.enableTestRunnerMode();

    return run;
}

const TestCase = struct {
    name: []const u8,
    project_dir: Build.LazyPath,
    script: ?[]const u8,
};

fn buildTestCases(b: *Build, opts: struct {
    root_dir: Build.LazyPath,
    gdzig: *Build.Module,
    target: ?Build.ResolvedTarget = null,
    optimize: ?OptimizeMode = null,
}) []const TestCase {
    const gdzig_test_mod = b.createModule(.{
        .root_source_file = b.path("gdzig_test/gdzig_test.zig"),
        .target = opts.target,
        .optimize = opts.optimize,
        .imports = &.{
            .{ .name = "gdzig", .module = opts.gdzig },
        },
    });

    var dir = std.fs.cwd().openDir(opts.root_dir.getPath(b), .{ .iterate = true }) catch return &.{};
    defer dir.close();

    var tests: std.ArrayListUnmanaged(TestCase) = .empty;

    var iter = dir.iterate();
    while (iter.next() catch null) |entry| {
        if (entry.kind != .directory) continue;

        const name = b.allocator.dupe(u8, entry.name) catch continue;
        const project = buildTestProject(b, .{
            .name = name,
            .root_dir = opts.root_dir,
            .gdzig = opts.gdzig,
            .gdzig_test = gdzig_test_mod,
            .target = opts.target,
            .optimize = opts.optimize,
        });

        const has_script = unwrapPath(b, opts.root_dir.path(b, b.fmt("{s}/test.gd", .{name}))) != null;

        tests.append(b.allocator, .{
            .name = name,
            .project_dir = project.getDirectory(),
            .script = if (has_script) "res://test.gd" else null,
        }) catch continue;
    }

    return tests.toOwnedSlice(b.allocator) catch &.{};
}

fn buildTestProject(b: *Build, opts: struct {
    name: []const u8,
    root_dir: Build.LazyPath,
    gdzig: *Build.Module,
    gdzig_test: *Build.Module,
    target: ?Build.ResolvedTarget = null,
    optimize: ?OptimizeMode = null,
}) *Build.Step.WriteFile {
    const testcase_mod = b.createModule(.{
        .root_source_file = opts.root_dir.path(b, b.fmt("{s}/test.zig", .{opts.name})),
        .target = opts.target,
        .optimize = opts.optimize,
        .imports = &.{
            .{ .name = "gdzig", .module = opts.gdzig },
            .{ .name = "gdzig_test", .module = opts.gdzig_test },
        },
    });

    const mod = b.createModule(.{
        .root_source_file = generateMain(b),
        .target = opts.target,
        .optimize = opts.optimize,
        .imports = &.{
            .{ .name = "gdzig", .module = opts.gdzig },
            .{ .name = "gdzig_test", .module = opts.gdzig_test },
            .{ .name = "testcase", .module = testcase_mod },
        },
    });

    const lib = b.addLibrary(.{
        .linkage = .dynamic,
        .name = b.fmt("test_{s}", .{opts.name}),
        .root_module = mod,
        .use_llvm = true,
    });

    return generateProject(b, opts.name, opts.root_dir, lib);
}

fn generateMain(b: *Build) Build.LazyPath {
    const files = b.addWriteFiles();
    _ = files.add("main.zig",
        \\const std = @import("std");
        \\const godot = @import("gdzig");
        \\const testing = @import("gdzig_test");
        \\const testcase = @import("testcase");
        \\
        \\comptime {
        \\    godot.entrypoint("gdzig_test_entry", .{
        \\        .init = init,
        \\        .deinit = deinit,
        \\    });
        \\}
        \\
        \\fn init(level: godot.InitializationLevel) void {
        \\    testing.runInit(testcase, level);
        \\}
        \\
        \\fn deinit(level: godot.InitializationLevel) void {
        \\    testing.runDeinit(testcase, level);
        \\}
        \\
    );
    return files.getDirectory().path(b, "main.zig");
}

fn generateProject(
    b: *Build,
    name: []const u8,
    root_dir: Build.LazyPath,
    lib: *Build.Step.Compile,
) *Build.Step.WriteFile {
    const project = b.addWriteFiles();

    _ = project.add("test.gdextension", b.fmt(
        \\[configuration]
        \\compatibility_minimum = "4.2.0"
        \\entry_symbol = "gdzig_test_entry"
        \\
        \\[libraries]
        \\linux.debug.x86_64 = "lib/libtest_{0s}.so"
        \\linux.release.x86_64 = "lib/libtest_{0s}.so"
        \\macos.debug = "lib/libtest_{0s}.dylib"
        \\macos.release = "lib/libtest_{0s}.dylib"
        \\windows.debug.x86_64 = "lib/test_{0s}.dll"
        \\windows.release.x86_64 = "lib/test_{0s}.dll"
        \\
    , .{name}));

    _ = project.add("project.godot", b.fmt(
        \\config_version=5
        \\
        \\[application]
        \\config/name="{s}"
        \\run/main_scene="res://test.tscn"
        \\
        \\[native_extensions]
        \\paths=["res://test.gdextension"]
        \\
    , .{name}));

    if (unwrapPath(b, root_dir.path(b, b.fmt("{s}/test.tscn", .{name})))) |path| {
        _ = project.addCopyFile(.{ .cwd_relative = path }, "test.tscn");
    } else {
        _ = project.add("test.tscn",
            \\[gd_scene format=3]
            \\[node name="Test" type="Node"]
            \\
        );
    }

    if (unwrapPath(b, root_dir.path(b, b.fmt("{s}/test.gd", .{name})))) |path| {
        _ = project.addCopyFile(.{ .cwd_relative = path }, "test.gd");
    }

    _ = project.add(".godot/extension_list.cfg", "res://test.gdextension\n");
    _ = project.addCopyFile(lib.getEmittedBin(), b.fmt("lib/libtest_{s}.so", .{name}));

    return project;
}

fn unwrapPath(b: *Build, path: Build.LazyPath) ?[]const u8 {
    const p = path.getPath(b);
    std.fs.cwd().access(p, .{}) catch return null;
    return p;
}

const std = @import("std");
const Build = std.Build;
const OptimizeMode = std.builtin.OptimizeMode;
