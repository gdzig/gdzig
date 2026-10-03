//! Shared Emscripten SDK provisioning for web (wasm32-emscripten) builds.
//!
//! Both the gdextension header translation (build/gdextension.zig) and the
//! per-extension web link step (build/api.zig) need an installed, activated
//! emsdk. This helper provisions it exactly once per configure run, so
//! concurrent callers share one install/activate step pair instead of racing
//! duplicate `emsdk install` processes.

pub const Emsdk = struct {
    /// The emsdk root directory.
    path: Build.LazyPath,
    /// The sysroot include directory
    /// (upstream/emscripten/cache/sysroot/include).
    sysroot_include: Build.LazyPath,
    /// Shared step that completes once emsdk is installed and activated.
    activate_step: *Build.Step,
};

const sysroot_include_subpath = "upstream/emscripten/cache/sysroot/include";

pub const Options = struct {
    /// The Emscripten version to install and activate.
    version: []const u8,
    /// User-supplied emsdk root. When given, the lazy `emsdk` dependency is
    /// not resolved.
    path: ?Build.LazyPath = null,
};

/// Returns the shared emsdk provisioning for `options.version`, creating the
/// install/activate steps on first call. `b` must always be the gdzig
/// package builder (dep.builder when gdzig is used as a dependency) so all
/// callers share one top-level step registry.
///
/// Dedup works by registering a named top-level step,
/// `gdzig-emsdk-activate-<version>`, and using the builder's own step
/// registry as the cache: `Build.step()` panics on duplicate names, so the
/// helper does its own get-or-create against `b.top_level_steps`.
///
/// Returns null while the lazy `emsdk` dependency is still being fetched
/// (standard two-pass configure; the caller returns early and zig re-runs
/// the configure phase).
pub fn get(b: *Build, options: Options) ?Emsdk {
    const emsdk_path = if (options.path) |p| p else blk: {
        const emsdk_dep = b.lazyDependency("emsdk", .{}) orelse return null;
        break :blk emsdk_dep.path("");
    };

    const name = b.fmt("gdzig-emsdk-activate-{s}", .{options.version});
    if (b.top_level_steps.get(name)) |tls| {
        return .{
            .path = emsdk_path,
            .sysroot_include = emsdk_path.path(b, sysroot_include_subpath),
            .activate_step = &tls.step,
        };
    }

    const emsdk_script = if (b.graph.host.result.os.tag == .windows) "emsdk.bat" else "emsdk";

    const install_emsdk = b.addSystemCommand(&.{compat.lazyPathString(b, emsdk_path.path(b, emsdk_script))});
    install_emsdk.addArgs(&.{ "install", options.version });

    const activate_emsdk = b.addSystemCommand(&.{compat.lazyPathString(b, emsdk_path.path(b, emsdk_script))});
    activate_emsdk.addArgs(&.{ "activate", options.version });
    activate_emsdk.step.dependOn(&install_emsdk.step);

    const step = b.step(name, b.fmt("Install and activate emsdk {s}", .{options.version}));
    step.dependOn(&activate_emsdk.step);

    return .{
        .path = emsdk_path,
        .sysroot_include = emsdk_path.path(b, sysroot_include_subpath),
        .activate_step = step,
    };
}

const std = @import("std");
const Build = std.Build;

const compat = @import("compat.zig");
