pub const BuildOptions = struct {
    headers: Build.LazyPath,
    target: Build.ResolvedTarget,
    optimize: OptimizeMode = .Debug,
    /// For web builds, the Emscripten version whose sysroot is used when
    /// translating the gdextension header.
    emsdk_version: []const u8 = "4.0.20",
};

pub fn build(b: *Build, options: BuildOptions) *Build.Module {
    if (options.target.result.cpu.arch.isWasm()) {
        const sdk = emsdk.get(b, .{ .version = options.emsdk_version }) orelse
            return placeholderModule(b, options);
        return translate_c.translateC(b, .{
            .name = "gdextension_interface",
            .c_source_file = options.headers.path(b, "gdextension_interface.h"),
            .target = options.target,
            .optimize = options.optimize,
            .system_include_paths = &.{sdk.sysroot_include},
            .step_deps = &.{sdk.activate_step},
        }).mod;
    }

    return translate_c.translateC(b, .{
        .name = "gdextension_interface",
        .c_source_file = options.headers.path(b, "gdextension_interface.h"),
        .target = options.target,
        .optimize = options.optimize,
    }).mod;
}

/// Stand-in module used on wasm while the lazy emsdk dependency is being
/// fetched (pass 1 of the two-pass configure). gdzig's build() must not
/// return early: downstream projects do `dep.module("gdzig")` during pass 1
/// and would panic on the missing module. Pass 1 never reaches the make
/// phase, so the placeholder is never compiled; pass 2 builds the real graph.
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

const emsdk = @import("emsdk.zig");
const translate_c = @import("translate_c.zig");
