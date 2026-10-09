const Generated = struct {
    run: *Build.Step.Run,
    candidate: Build.LazyPath,
    reports: []const Build.LazyPath,
};

const Generator = struct {
    b: *Build,
    extractor: *Build.Step.Compile,
    merger: *Build.Step.Compile,
    extracted: std.StringHashMapUnmanaged(Build.LazyPath) = .empty,

    fn extract(self: *Generator, comptime owner: type, version: []const u8) ?Build.LazyPath {
        if (self.extracted.get(version)) |path| return path;
        const b = self.b;
        const api = if (std.mem.eql(u8, version, cached.current.version))
            b.path("vendor/extension_api.json")
        else blk: {
            const godot_versions = b.lazyImport(owner, "godot_versions") orelse return null;
            const headers = godot_versions.headers(b, b.graph.host, .{ .version = version });
            break :blk headers.path(b, "extension_api.json");
        };
        const run = b.addRunArtifact(self.extractor);
        run.addPrefixedFileArg("--api=", api);
        run.addArg(b.fmt("--version={s}", .{version}));
        const result = run.addPrefixedOutputFileArg("--output=", "records.zon");
        self.extracted.put(b.allocator, version, result) catch @panic("OOM");
        return result;
    }

    fn generate(
        self: *Generator,
        comptime owner: type,
        versions: []const []const u8,
        expect: ?Build.LazyPath,
    ) ?Generated {
        const b = self.b;
        const current = self.extract(owner, cached.current.version) orelse return null;
        var previous: ?Build.LazyPath = null;
        var last: ?*Build.Step.Run = null;
        var reports: std.ArrayList(Build.LazyPath) = .empty;
        for (versions, 0..) |version, index| {
            const old = self.extract(owner, version) orelse return null;
            const run = b.addRunArtifact(self.merger);
            if (previous) |path| {
                run.addArg("--mode=append");
                run.addPrefixedFileArg("--input=", path);
            } else {
                run.addArg("--mode=overwrite");
            }
            run.addPrefixedFileArg("--current=", current);
            run.addPrefixedFileArg("--old=", old);
            previous = run.addPrefixedOutputFileArg("--output=", "compatibility.zon");
            const report = run.addPrefixedOutputFileArg("--report=", b.fmt("{s}.json", .{version}));
            reports.append(b.allocator, report) catch @panic("OOM");
            if (expect) |path| {
                if (index + 1 == versions.len) {
                    run.addPrefixedFileArg("--expect=", path);
                    run.has_side_effects = true;
                }
            }
            last = run;
        }
        return .{
            .run = last.?,
            .candidate = previous.?,
            .reports = reports.toOwnedSlice(b.allocator) catch @panic("OOM"),
        };
    }
};

/// Add independently cached extraction, canonical merge, preview and maintenance.
pub fn add(b: *Build, comptime asking_build_zig: type) void {
    const casez = b.dependency("casez", .{});
    const common_mod = common.build(b, .{
        .target = b.graph.host,
        .optimize = .debug,
        .casez = casez.module("casez"),
    });
    const compat_mod = b.createModule(.{
        .root_source_file = b.path("pkg/compat/compat.zig"),
        .target = b.graph.host,
        .optimize = .debug,
        .imports = &.{.{ .name = "common", .module = common_mod }},
    });
    const extract_mod = toolModule(b, "pkg/tools/compat_extract/main.zig", common_mod, compat_mod);
    const merge_mod = toolModule(b, "pkg/tools/compat_metadata/main.zig", common_mod, compat_mod);
    const test_step = b.step("test-compat-metadata", "Run optional extraction and merge host tests");
    test_step.dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = compat_mod })).step);
    test_step.dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = extract_mod })).step);
    test_step.dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = merge_mod })).step);
    var generator: Generator = .{
        .b = b,
        .extractor = b.addExecutable(.{ .name = "gdzig-compat-extract", .root_module = extract_mod }),
        .merger = b.addExecutable(.{ .name = "gdzig-compat-metadata", .root_module = merge_mod }),
    };
    const old = b.option([]const u8, "old", "Exact releases: all, a comma list, or all,<extra>");
    const preview = b.step("compat-metadata", "Install cache and per-release reports to zig-out/compat");
    const update = b.step("update-compat-metadata", "Regenerate the full vendored compatibility cache");
    const check = b.step("check-compat-metadata", "Compare full regeneration with the vendored cache");
    const request = old orelse {
        const failure = b.addFail("Metadata maintenance requires -Dold=all or an explicit release list.");
        for ([_]*Build.Step{ preview, update, check }) |step| step.dependOn(&failure.step);
        return;
    };
    const versions = requestedVersions(b, request) catch {
        const failure = b.addFail("old requires exact stable numeric releases or all");
        for ([_]*Build.Step{ preview, update, check }) |step| step.dependOn(&failure.step);
        return;
    };
    const generated = generator.generate(asking_build_zig, versions, null) orelse return;
    preview.dependOn(&b.addInstallFile(generated.candidate, "compat/compatibility.zon").step);
    for (generated.reports, versions) |report, version| {
        preview.dependOn(&b.addInstallFile(report, b.fmt("compat/reports/{s}.json", .{version})).step);
    }
    if (containsCachedTargets(versions)) {
        const copy = b.addUpdateSourceFiles();
        copy.addCopyFileToSource(generated.candidate, "pkg/bindgen/generated/compatibility.zon");
        update.dependOn(&copy.step);
        const verification = generator.generate(
            asking_build_zig,
            versions,
            b.path("pkg/bindgen/generated/compatibility.zon"),
        ) orelse return;
        check.dependOn(&verification.run.step);
    } else {
        const failure = b.addFail(
            "Full maintenance must retain every cached target. " ++
                "Use -Dold=all or -Dold=all,<additional release>.",
        );
        update.dependOn(&failure.step);
        check.dependOn(&failure.step);
    }
}

fn toolModule(
    b: *Build,
    path: []const u8,
    common_mod: *Build.Module,
    compat_mod: *Build.Module,
) *Build.Module {
    return b.createModule(.{
        .root_source_file = b.path(path),
        .target = b.graph.host,
        .optimize = .debug,
        .imports = &.{
            .{ .name = "common", .module = common_mod },
            .{ .name = "compat", .module = compat_mod },
        },
    });
}

fn requestedVersions(b: *Build, request: []const u8) ![]const []const u8 {
    var versions: std.ArrayList([]const u8) = .empty;
    var pieces = std.mem.splitScalar(u8, request, ',');
    while (pieces.next()) |piece| {
        if (std.mem.eql(u8, piece, "all")) {
            inline for (cached.targets) |target| try appendUnique(b, &versions, target.source.version);
        } else {
            const version = try Version.parseStrict(piece);
            const canonical = b.fmt("{d}.{d}.{d}", .{ version.major, version.minor, version.patch });
            if (!std.mem.eql(u8, canonical, piece)) return error.InvalidExactVersion;
            try appendUnique(b, &versions, canonical);
        }
    }
    return versions.toOwnedSlice(b.allocator);
}

fn appendUnique(b: *Build, versions: *std.ArrayList([]const u8), version: []const u8) !void {
    for (versions.items) |previous| {
        if (std.mem.eql(u8, previous, version)) return;
    }
    try versions.append(b.allocator, version);
}

fn containsCachedTargets(versions: []const []const u8) bool {
    inline for (cached.targets) |target| {
        var found = false;
        for (versions) |version| {
            if (std.mem.eql(u8, version, target.source.version)) found = true;
        }
        if (!found) return false;
    }
    return true;
}

const std = @import("std");
const Build = std.Build;

const common = @import("common.zig");
const Version = @import("../pkg/common/Version.zig").Version;
const cached = @import("../pkg/bindgen/generated/compatibility.zon");
