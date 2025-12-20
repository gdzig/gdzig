pub fn runEmsdk(b: *Build, emsdk_path: Build.LazyPath) *Build.Step.Run {
    const emsdk_script = if (b.graph.host.result.os.tag == .windows) "emsdk.bat" else "emsdk";
    return b.addSystemCommand(&.{emsdk_path.path(b, emsdk_script).getPath(b)});
}

pub fn emsdkInstall(b: *Build, emsdk_path: Build.LazyPath, version: []const u8) *Build.Step.Run {
    const run_emsdk_install = runEmsdk(b, emsdk_path);
    run_emsdk_install.addArgs(&.{ "install", version });
    return run_emsdk_install;
}

pub fn emsdkActivate(b: *Build, emsdk_path: Build.LazyPath, version: []const u8) *Build.Step.Run {
    const run_emsdk_activate = runEmsdk(b, emsdk_path);
    run_emsdk_activate.addArgs(&.{ "activate", version });
    return run_emsdk_activate;
}

pub fn runEmcc(b: *Build, emsdk_path: Build.LazyPath) *Build.Step.Run {
    return b.addSystemCommand(&.{emsdk_path.path(b, "upstream/emscripten/emcc").getPath(b)});
}

const std = @import("std");
const Build = std.Build;
