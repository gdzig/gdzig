/// Find a program by name candidates on PATH, compatible with Zig 0.16.0
/// and zig master (0.17). Returns null when not found.
pub fn findProgram(b: *Build, names: []const []const u8) ?[]const u8 {
    // TODO(zig 0.16.0): zig master replaced `findProgram(names, paths)` with
    // `findProgram(.{ .names = ... })`, returning optional instead of error.
    return if (comptime builtin.zig_version.minor == 16)
        b.findProgram(names, &.{}) catch null
    else
        b.findProgram(.{ .names = names });
}

// TODO(zig 0.16.0): zig master renamed the `OptimizeMode` variants to
// lowercase (`Debug` → `debug`, `ReleaseSafe` → `safe`, `ReleaseFast` →
// `fast`, `ReleaseSmall` → `small`).
pub const optimize_debug: OptimizeMode = if (builtin.zig_version.minor == 16) .Debug else .debug;
pub const optimize_safe: OptimizeMode = if (builtin.zig_version.minor == 16) .ReleaseSafe else .safe;
pub const optimize_fast: OptimizeMode = if (builtin.zig_version.minor == 16) .ReleaseFast else .fast;
pub const optimize_small: OptimizeMode = if (builtin.zig_version.minor == 16) .ReleaseSmall else .small;

pub const BuildOptions = struct {
    casez: *Build.Module,
    target: Build.ResolvedTarget,
    optimize: OptimizeMode = optimize_debug,
};

pub fn build(b: *Build, options: BuildOptions) *Build.Module {
    return b.createModule(.{
        .root_source_file = b.path("pkg/common/common.zig"),
        .target = options.target,
        .optimize = options.optimize,
        .imports = &.{
            .{ .name = "casez", .module = options.casez },
        },
    });
}

const std = @import("std");
const builtin = @import("builtin");
const Build = std.Build;
const OptimizeMode = std.builtin.OptimizeMode;
