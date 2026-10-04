//! Path utilities for build scripts.

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
