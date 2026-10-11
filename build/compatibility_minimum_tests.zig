//! Build startup fixtures without introducing a Python or historical-input dependency.
/// Add real-engine startup, isolated entrypoint and optimized ABI witnesses.
pub fn add(
    b: *Build,
    gdzig: *Build.Module,
    target: Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    godot: Build.LazyPath,
    minimum: ?[]const u8,
) void {
    // Only explicit minima have a compile-time ABI worth inspecting.
    if (minimum != null) {
        const witness_mod = b.createModule(.{
            .root_source_file = b.path("test/compatibility_minimum/abi_witness.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{.{ .name = "gdzig", .module = gdzig }},
        });
        const witness = b.addLibrary(.{
            .name = "compatibility_minimum_abi",
            .linkage = .dynamic,
            .root_module = witness_mod,
            .use_llvm = true,
        });
        const install_ir = b.addInstallFile(
            witness.getEmittedLlvmIr(),
            "evidence/compatibility-minimum-abi.ll",
        );
        b.step(
            "compatibility-minimum-abi-ir",
            "Emit representative public shim LLVM IR (use ReleaseFast)",
        ).dependOn(&install_ir.step);
    }

    // Share the selected identity with normal, host-counter and installed IPC fixtures.
    const fixture_options = b.addOptions();
    fixture_options.addOption([]const u8, "compatibility_minimum", minimum orelse "none");
    const fixture_options_mod = fixture_options.createModule();
    const options = b.addOptions();
    options.addOption([]const u8, "entry_symbol", "gdextension_entry");
    options.addOption(api.InitializationLevel, "minimum_initialization_level", .scene);
    const options_mod = options.createModule();
    const state = b.createModule(.{
        .root_source_file = b.path("test/compatibility_minimum/entrypoint_state.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "runtime", .module = gdzig }},
    });
    const fake = b.createModule(.{
        .root_source_file = b.path("test/compatibility_minimum/entrypoint_fake.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "runtime", .module = gdzig },
            .{ .name = "state", .module = state },
        },
    });
    const host_entry = b.createModule(.{
        .root_source_file = b.path("src/extension/entrypoint.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "gdzig", .module = fake },
            .{ .name = "extension", .module = state },
            .{ .name = "options", .module = options_mod },
        },
    });
    const harness_options = b.addOptions();
    harness_options.addOption([]const u8, "entry_symbol", "gdzig_compatibility_minimum_harness_entry");
    harness_options.addOption(api.InitializationLevel, "minimum_initialization_level", .scene);
    harness_options.addOption(api.TestStartup, "startup", .initialization);
    const host_harness = b.createModule(.{
        .root_source_file = b.path("src/testing/harness.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "gdzig", .module = fake },
            .{ .name = "options", .module = harness_options.createModule() },
        },
    });
    const host_mod = b.createModule(.{
        .root_source_file = b.path("test/compatibility_minimum/entrypoint_host.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "runtime", .module = gdzig },
            .{ .name = "state", .module = state },
            .{ .name = "entrypoint", .module = host_entry },
            .{ .name = "harness", .module = host_harness },
            .{ .name = "fixture_options", .module = fixture_options_mod },
        },
    });
    host_mod.link_libc = true;
    host_mod.addImport("host_fixture", host_mod);
    const host_test = b.addTest(.{
        .root_module = host_mod,
        .test_runner = .{
            .path = b.path("test/compatibility_minimum/entrypoint_runner.zig"),
            .mode = .simple,
        },
    });
    const host_run = b.addRunArtifact(host_test);
    host_run.has_side_effects = true;
    host_run.removeEnvironmentVariable("GDZIG_TEST_MODE");
    b.step(
        "test-compatibility-minimum-entrypoint",
        "Check real normal and IPC entrypoint ordering with isolated host counters",
    ).dependOn(&host_run.step);
    b.top_level_steps.get("test").?.step.dependOn(&host_run.step);

    // Compile the real normal entrypoint and install its minimal Godot project in cache.
    const fixture = b.createModule(.{
        .root_source_file = b.path("test/compatibility_minimum/extension.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "gdzig", .module = gdzig },
            .{ .name = "fixture_options", .module = fixture_options_mod },
        },
    });
    const entry = b.createModule(.{
        .root_source_file = b.path("src/extension/entrypoint.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "gdzig", .module = gdzig },
            .{ .name = "extension", .module = fixture },
            .{ .name = "options", .module = options_mod },
        },
    });
    const lib = b.addLibrary(.{
        .name = "compatibility_minimum_init",
        .linkage = .dynamic,
        .root_module = entry,
        .use_llvm = true,
    });
    const files = b.addWriteFiles();
    _ = files.addCopyFile(lib.getEmittedBin(), lib.out_filename);
    for ([_][]const u8{
        "main.gd", "project.godot", "main.tscn", "compatibility_minimum_init.gdextension",
    }) |name| {
        _ = files.addCopyFile(b.path(b.fmt("test/compatibility_minimum/{s}", .{name})), name);
    }
    _ = files.addCopyFile(
        b.path("test/compatibility_minimum/extension_list.cfg"),
        ".godot/extension_list.cfg",
    );

    // A finite native checker owns process identity, deadlines and observable assertions.
    const checker_module = b.createModule(.{
        .root_source_file = b.path("test/compatibility_minimum/check.zig"),
        .target = b.graph.host,
        .optimize = .debug,
        .imports = &.{.{ .name = "common", .module = gdzig.import_table.get("common").? }},
    });
    const checker = b.addExecutable(.{
        .name = "check-compatibility-minimum",
        .root_module = checker_module,
    });
    const checker_run = b.addRunArtifact(b.addTest(.{ .root_module = checker_module }));
    b.top_level_steps.get("test").?.step.dependOn(&checker_run.step);
    b.step(
        "test-compatibility-minimum-checker",
        "Run bounded startup checker assertions",
    ).dependOn(&checker_run.step);
    const run = b.addRunArtifact(checker);
    run.addPrefixedFileArg("--godot=", godot);
    run.addPrefixedDirectoryArg("--project=", files.getDirectory());
    run.addPrefixedFileArg("--library=", lib.getEmittedBin());
    run.addArg(b.fmt("--compatibility-minimum={s}", .{minimum orelse "none"}));
    run.has_side_effects = true;
    b.step(
        "test-compatibility-minimum-init",
        "Check normal entrypoint acceptance or rejection with a bounded real engine",
    ).dependOn(&run.step);
}

const std = @import("std");
const Build = std.Build;

const api = @import("api.zig");
