pub const BuildOptions = struct {
    headers: Build.LazyPath,
    target: Build.ResolvedTarget,
    optimize: OptimizeMode = .Debug,
};

pub fn build(b: *Build, options: BuildOptions) *Build.Module {
    const translate_c = b.addTranslateC(.{
        .root_source_file = options.headers.path(b, "gdextension_interface.h"),
        .optimize = options.optimize,
        .target = options.target,
        .link_libc = true,
    });

    return b.createModule(.{
        .root_source_file = translate_c.getOutput(),
        .optimize = options.optimize,
        .target = options.target,
        .link_libc = true,
    });
}

const std = @import("std");
const Build = std.Build;
const OptimizeMode = std.builtin.OptimizeMode;
