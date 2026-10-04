pub const Emsdk = struct {
    path: Build.LazyPath,
    sysroot_include: Build.LazyPath,
    activate_step: *Build.Step,
};

pub const Options = struct {
    version: []const u8,
    path: ?Build.LazyPath = null,
};

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

const sysroot_include_subpath = "upstream/emscripten/cache/sysroot/include";

const std = @import("std");
const Build = std.Build;

const compat = @import("compat.zig");
