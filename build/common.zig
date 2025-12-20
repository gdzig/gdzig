pub const BuildOptions = struct {
    casez: *Build.Module,
    target: Build.ResolvedTarget,
    optimize: OptimizeMode = .Debug,
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
const Build = std.Build;
const OptimizeMode = std.builtin.OptimizeMode;
