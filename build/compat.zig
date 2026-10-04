//! Compatibility shims for zig build-script APIs that changed shape
//! between the pinned stable release and zig master. Runtime-code shims
//! live in src/compat.zig. See docs/adr/0001-zig-version-compat.md.
//!
//! Gates probe API *shape* (comptime `@hasDecl`/`@hasField`/return-type
//! probes), not version numbers, so they keep working across future
//! releases until the old-shape branch is deleted. Discover all gates with:
//! `git grep -E "comptime !?@has(Decl|Field)"`.

const std = @import("std");
const Build = std.Build;

/// Resolves a `LazyPath` to a filesystem path string during the configure
/// phase. Only source paths and dependency paths are supported — generated
/// paths have no configure-time string.
pub fn lazyPathString(b: *Build, lp: Build.LazyPath) []const u8 {
    return switch (lp) {
        .src_path => |sp| sp.owner.root.joinString(b.graph.arena, sp.sub_path) catch @panic("OOM"),
        .dependency => |d| d.dependency.builder.root.joinString(b.graph.arena, d.sub_path) catch @panic("OOM"),
        else => @panic("unsupported lazy path for configure-time resolution"),
    };
}
