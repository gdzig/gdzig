pub const BuildOptions = struct {
    headers: Build.LazyPath,
    target: Build.ResolvedTarget,
    optimize: OptimizeMode = .Debug,
    /// For web builds, the Emscripten version whose sysroot is used when
    /// translating the gdextension header.
    emsdk_version: []const u8 = "4.0.20",
};

pub fn build(b: *Build, options: BuildOptions) *Build.Module {
    const sdk: ?emsdk.Emsdk = if (options.target.result.cpu.arch.isWasm())
        emsdk.get(b, .{ .version = options.emsdk_version }) orelse
            return placeholderModule(b, options)
    else
        null;

    return translate_c.translateC(b, resolveOptions(b, options, sdk)).mod;
}

/// Builds the translate-c options for the gdextension header. When `sdk` is
/// given (wasm targets), translation additionally uses the emsdk sysroot and
/// runs after the shared emsdk activate step.
fn resolveOptions(b: *Build, options: BuildOptions, sdk: ?emsdk.Emsdk) translate_c.Options {
    var system_include_paths: []const Build.LazyPath = &.{};
    var step_deps: []const *Build.Step = &.{};
    if (sdk) |s| {
        system_include_paths = b.allocator.dupe(Build.LazyPath, &.{s.sysroot_include}) catch @panic("OOM");
        step_deps = b.allocator.dupe(*Build.Step, &.{s.activate_step}) catch @panic("OOM");
    }
    return .{
        .name = "gdextension_interface",
        .c_source_file = options.headers.path(b, "gdextension_interface.h"),
        .target = options.target,
        .optimize = options.optimize,
        .system_include_paths = system_include_paths,
        .step_deps = step_deps,
    };
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
