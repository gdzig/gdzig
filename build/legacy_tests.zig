/// Exercise generated legacy ranges, unchanged refAllDecls and call-site omission.
pub fn add(b: *std.Build, bindgen: *std.Build.Step.Compile) *std.Build.Step {
    const step = b.step("test-legacy-bindings", "Check generated old-layout binding ranges");
    const tool_module = b.createModule(.{
        .root_source_file = b.path("pkg/bindgen/legacy_fixture.zig"),
        .target = b.graph.host,
        .optimize = .debug,
        .link_libc = true,
    });
    var imports = bindgen.root_module.import_table.iterator();
    while (imports.next()) |entry| {
        tool_module.addImport(entry.key_ptr.*, entry.value_ptr.*);
    }
    const tool = b.addExecutable(.{ .name = "legacy-fixture", .root_module = tool_module });
    const generate = b.addRunArtifact(tool);
    const directory = generate.addOutputDirectoryArg("legacy");

    // Real writer output keeps default and above-range refAllDecls unchanged.
    for ([_][]const u8{
        "default-ref.zig",
        "minimum-ref.zig",
        "dispatch-ref.zig",
        "adapter-inside.zig",
        "adapter-above.zig",
    }) |name| {
        const tests = b.addTest(.{
            .root_module = fixtureModule(b, directory.path(b, name), bindgen),
        });
        step.dependOn(&b.addRunArtifact(tests).step);
    }

    // Inside-range calls exercise their own old hash and its lazy cache.
    for ([_][]const u8{
        "default-valid.zig",
        "minimum-valid.zig",
        "default-rejected.zig",
        "dispatch-panic.zig",
        "dispatch-modern.zig",
        "dispatch-above.zig",
        "adapter-default.zig",
        "adapter-inside.zig",
        "adapter-above.zig",
    }) |name| {
        const executable = b.addExecutable(.{
            .name = name,
            .root_module = fixtureModule(b, directory.path(b, name), bindgen),
        });
        const run = b.addRunArtifact(executable);
        if (std.mem.eql(u8, name, "default-rejected.zig")) {
            run.addCheck(.{ .expect_term = .{ .signal = .ABRT } });
            run.expectStdErrMatch(
                "Probe.probe_4_6_legacy is only valid on Godot [4.6.0, 4.7.0); running 4.7.2",
            );
        } else if (std.mem.eql(u8, name, "dispatch-panic.zig")) {
            run.addCheck(.{ .expect_term = .{ .signal = .ABRT } });
            run.expectStdErrMatch(missing_shim_message);
        }
        step.dependOn(&run.step);
    }

    // The above-range member and its storage are absent, not filtered out of tests.
    const rejected = b.addExecutable(.{
        .name = "minimum-missing",
        .root_module = fixtureModule(b, directory.path(b, "minimum-missing.zig"), bindgen),
    });
    rejected.expect_errors = .{ .contains = "has no member named 'probe_4_6_legacy'" };
    step.dependOn(&rejected.step);

    // A missing adapter only breaks callers inside its measured minimum range.
    const missing = b.addExecutable(.{
        .name = "dispatch-missing",
        .root_module = fixtureModule(b, directory.path(b, "dispatch-missing.zig"), bindgen),
    });
    missing.expect_errors = .{ .contains = missing_shim_message };
    step.dependOn(&missing.step);

    // Opaque hash observation prevents the optimized witness from disappearing.
    for ([_]u32{ 6, 7 }) |minor| {
        const name = b.fmt("dispatch-ir-{d}", .{minor});
        const source = directory.path(b, b.fmt("{s}.zig", .{name}));
        const module = fixtureModule(b, source, bindgen);
        module.optimize = .fast;
        const object = b.addObject(.{ .name = name, .root_module = module });
        const check = b.addCheckFile(object.getEmittedLlvmIr(), .{
            .expected_matches = &.{
                "dispatchWitness",
                b.fmt("@observeHash(i64 {d})", .{@as(u32, if (minor == 6) 111 else 222)}),
            },
        });
        step.dependOn(&check.step);
    }
    return step;
}

fn fixtureModule(
    b: *std.Build,
    source: std.Build.LazyPath,
    bindgen: *std.Build.Step.Compile,
) *std.Build.Module {
    const module = b.createModule(.{
        .root_source_file = source,
        .target = b.graph.host,
        .optimize = .debug,
    });
    module.addImport("common", bindgen.root_module.import_table.get("common").?);
    return module;
}

const missing_shim_message = "Probe.probe: Godot 4.6.0 layout is incompatible (fixture) " ++
    "and has no shim; add probe_4_6 or build with -Dgodot_compatibility_minimum=4.7.0";

const std = @import("std");
