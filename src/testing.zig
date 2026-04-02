//! Testing framework for gdzig extensions.
//!
//! This module provides infrastructure for running Zig tests inside Godot.
//! Tests use standard Zig `test {}` blocks and can access the full Godot API.
//!
//! ## Usage in build.zig
//!
//! ```zig
//! const gdzig = @import("gdzig");
//!
//! pub fn build(b: *std.Build) void {
//!     const mod = b.createModule(.{
//!         .root_source_file = b.path("src/my_extension.zig"),
//!         .target = target,
//!         .optimize = optimize,
//!     });
//!     mod.addImport("gdzig", gdzig_dep.module("gdzig"));
//!
//!     const test_step = b.step("test", "Run tests");
//!     test_step.dependOn(&gdzig.addTest(b, .{
//!         .root_module = mod,
//!         .godot_exe = "godot",
//!     }).step);
//! }
//! ```
//!
//! ## Writing tests
//!
//! Tests can be placed directly in your extension source files:
//!
//! ```zig
//! const std = @import("std");
//! const gdzig = @import("gdzig");
//!
//! pub fn register(r: *gdzig.extension.Registry) void {
//!     // ... extension registration
//! }
//!
//! test "node creation" {
//!     const Node = gdzig.class.Node;
//!     const node = Node.init();
//!     defer node.free();
//!
//!     var name = node.getName();
//!     defer name.deinit();
//!
//!     try std.testing.expectEqual(0, name.length());
//! }
//! ```

pub const allocator = allocator_instance.allocator();
pub var allocator_instance: GeneralPurposeAllocator = b: {
    if (!builtin.is_test) @compileError("testing allocator used when not testing");
    break :b .init;
};

pub var registry: Registry = if (builtin.is_test) .init(allocator) else unreachable;

pub fn loadModule(comptime Module: type) void {
    registry.addModule(Module);
    registry.enter(.core);
    registry.enter(.servers);
    registry.enter(.scene);
    registry.enter(.editor);
}

pub fn unloadModule(comptime Module: type) void {
    registry.exit(.editor);
    registry.exit(.scene);
    registry.exit(.servers);
    registry.exit(.core);
    Module.unregister(&registry);
}

const builtin = @import("builtin");

const common = @import("common");
const gdzig = @import("gdzig");
const Registry = gdzig.extension.Registry;
const GeneralPurposeAllocator = gdzig.heap.GeneralPurposeAllocator;
