//! Compatibility shims for zig build-script APIs that changed shape
//! between the pinned stable release and zig master. Runtime-code shims
//! live in src/compat.zig. See docs/adr/0001-zig-version-compat.md.
//!
//! Gates probe API *shape* (comptime `@hasDecl`/`@hasField`/return-type
//! probes), not version numbers, so they keep working across future
//! releases until the old-shape branch is deleted. Discover all gates with:
//! `git grep -E "comptime !?@has(Decl|Field)"`.
//!
// TODO(zig 0.16.0): when 0.16.x support is dropped, delete the old-shape
// branches; each helper reduces to the other branch's plain std call.

const std = @import("std");
const Build = std.Build;
const Io = std.Io;
const OptimizeMode = std.builtin.OptimizeMode;

/// True when `Build.findProgram` returns an optional (new shape) instead
/// of an error union (old shape).
const find_program_returns_optional =
    @typeInfo(@typeInfo(@TypeOf(Build.findProgram)).@"fn".return_type.?) == .optional;

/// Find a program by name candidates on PATH. Returns null when not found.
pub fn findProgram(b: *Build, names: []const []const u8) ?[]const u8 {
    if (comptime find_program_returns_optional) return b.findProgram(.{ .names = names });
    return b.findProgram(names, &.{}) catch null;
}

/// True when `OptimizeMode` variants are lowercase (new shape).
const lowercase_optimize_mode = std.meta.stringToEnum(OptimizeMode, "debug") != null;

/// `OptimizeMode` variants, renamed to lowercase on master.
pub const optimize_debug: OptimizeMode = if (lowercase_optimize_mode) .debug else .Debug;
pub const optimize_safe: OptimizeMode = if (lowercase_optimize_mode) .safe else .ReleaseSafe;
pub const optimize_fast: OptimizeMode = if (lowercase_optimize_mode) .fast else .ReleaseFast;
pub const optimize_small: OptimizeMode = if (lowercase_optimize_mode) .small else .ReleaseSmall;

/// Directory handle for the package build root, for configure-phase
/// directory access (`Build.build_root` was renamed to `Build.root`).
pub fn buildRootDir(b: *Build) Io.Dir {
    if (comptime @hasField(Build, "build_root")) return b.build_root.handle;
    return b.root.root_dir.handle;
}

/// Whether verbose build output was requested (`Build.verbose` moved into
/// `Build.Graph`).
pub fn verbose(b: *Build) bool {
    if (comptime @hasField(Build, "verbose")) return b.verbose;
    return b.graph.verbose;
}

/// Adds a directory path build option (the old-shape `addOptionPath`
/// accepts directories; the new-shape one is file-only and directories
/// need `addOptionPathDirectory`).
pub fn addOptionPathDirectory(options: *Build.Step.Options, name: []const u8, path: Build.LazyPath) void {
    if (comptime @hasDecl(Build.Step.Options, "addOptionPathDirectory")) {
        options.addOptionPathDirectory(name, path);
    } else {
        options.addOptionPath(name, path);
    }
}

/// The install prefix as a path string. Master removed
/// `Build.install_path`; the default install prefix there is
/// `<build_root>/zig-out` (custom `--prefix` values are not reflected here).
pub fn installPath(b: *Build) []const u8 {
    if (comptime @hasField(Build, "install_path")) return b.install_path;
    return "zig-out";
}

/// Resolves a `LazyPath` to a filesystem path string during the configure
/// phase (the old-shape `LazyPath.getPath2`/`getPath` were removed on
/// master). Only source paths and dependency paths are supported —
/// generated paths have no configure-time string on master.
pub fn lazyPathString(b: *Build, lp: Build.LazyPath) []const u8 {
    if (comptime @hasDecl(Build.LazyPath, "getPath2")) return lp.getPath2(b, null);
    return switch (lp) {
        .src_path => |sp| sp.owner.root.joinString(b.graph.arena, sp.sub_path) catch @panic("OOM"),
        .dependency => |d| d.dependency.builder.root.joinString(b.graph.arena, d.sub_path) catch @panic("OOM"),
        else => @panic("unsupported lazy path for configure-time resolution"),
    };
}

/// Declaration names of a container type, public and private (old shape:
/// `Type.Declaration` structs with `.name`; new shape: plain name strings).
pub inline fn declNames(comptime T: type) []const [:0]const u8 {
    if (comptime !@hasField(std.builtin.Type.Struct, "decl_names")) {
        // Old shape: []Type.Declaration.
        return comptime blk: {
            const decls = @typeInfo(T).@"struct".decls;
            var names: [decls.len][:0]const u8 = undefined;
            for (decls, 0..) |decl, i| {
                names[i] = decl.name;
            }
            const final = names;
            break :blk &final;
        };
    }
    // New shape: []const [:0]const u8.
    return @typeInfo(T).@"struct".decl_names;
}

/// Whether a dependency-cache entry key refers to the given package (old
/// shape keys match on `build_root_string`; new shape on `pkg_hash`).
pub inline fn depCacheKeyMatches(key: anytype, build_root: []const u8, pkg_hash: []const u8) bool {
    if (comptime @hasField(std.meta.Child(@TypeOf(key)), "build_root_string")) {
        return std.mem.eql(u8, key.build_root_string, build_root);
    }
    return std.mem.eql(u8, key.pkg_hash, pkg_hash);
}
