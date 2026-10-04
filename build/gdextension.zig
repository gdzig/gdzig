pub const BuildOptions = struct {
    headers: Build.LazyPath,
    target: Build.ResolvedTarget,
    optimize: OptimizeMode = .Debug,
    emsdk_version: []const u8 = emsdk.default_version,
};

pub fn build(b: *Build, options: BuildOptions) *Build.Module {
    const tc_dep = b.dependency("translate_c", .{});
    const translator: Translator = .init(tc_dep, .{
        .name = "gdextension_interface",
        .c_source_file = options.headers.path(b, "gdextension_interface.h"),
        .target = options.target,
        .optimize = options.optimize,
        .link_libc = true,
        .default_init = true,
    });

    if (options.target.result.cpu.arch.isWasm()) {
        const sdk = emsdk.get(b, .{ .version = options.emsdk_version }) orelse
            return placeholderModule(b, options);
        translator.addSystemIncludePath(sdk.sysroot_include);
        translator.run.step.dependOn(sdk.activate_step);
    }

    return translator.mod;
}

fn placeholderModule(b: *Build, options: BuildOptions) *Build.Module {
    const root = b.addWriteFiles().add(
        "gdextension_placeholder.zig",
        "// Placeholder while the lazy emsdk dependency is fetched.\n",
    );
    return b.createModule(.{
        .root_source_file = root,
        .target = options.target,
        .optimize = options.optimize,
        .link_libc = true,
    });
}

const std = @import("std");
const Build = std.Build;
const OptimizeMode = std.builtin.OptimizeMode;
const Translator = @import("translate_c").Translator;

const emsdk = @import("emsdk.zig");
