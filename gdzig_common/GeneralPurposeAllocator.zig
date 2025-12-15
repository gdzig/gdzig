//! A wrapper around multiple allocator implementations based on the build target.
//!
//! | Target                         | Implementation            |
//! | ------------------------------ | ------------------------- |
//! | Testing                        | `std.testing.allocator`   |
//! | WebAssembly                    | `std.heap.WasmAllocator`  |
//! | `.ReleaseSafe`/`.Debug`        | `std.heap.DebugAllocator` |
//! | `.ReleaseFast`/`.ReleaseSmall` | Passthrough               |
//!
//! ## Usage
//!
//! ```zig
//! var gpa: GeneralPurposeAllocator = .init(godot.engine_allocator);
//! const allocator = gpa.allocator();
//! ```
//!

const GeneralPurposeAllocator = @This();

const Strategy = enum { testing, wasm, safe, fast };
const strategy: Strategy = if (builtin.is_test)
    .testing
else if (builtin.target.cpu.arch.isWasm())
    .wasm
else switch (builtin.mode) {
    .ReleaseSafe, .Debug => .safe,
    .ReleaseFast, .ReleaseSmall => .fast,
};

impl: switch (strategy) {
    .testing => *@TypeOf(std.testing.allocator_instance),
    .wasm => WasmAllocator,
    .safe => DebugAllocator(.{}),
    .fast => Allocator,
},

pub fn init(backing_allocator: ?Allocator) GeneralPurposeAllocator {
    return .{
        .impl = switch (strategy) {
            .testing => &std.testing.allocator_instance,
            .wasm => .{},
            .safe => .{
                .backing_allocator = backing_allocator orelse std.heap.page_allocator,
            },
            .fast => backing_allocator orelse std.heap.page_allocator,
        },
    };
}

pub fn allocator(self: *GeneralPurposeAllocator) Allocator {
    return switch (strategy) {
        .fast => self.impl,
        else => self.impl.allocator(),
    };
}

pub fn deinit(self: *GeneralPurposeAllocator) std.heap.Check {
    return switch (strategy) {
        .safe => self.impl.deinit(),
        else => .ok,
    };
}

const std = @import("std");
const Allocator = std.mem.Allocator;
const DebugAllocator = std.heap.DebugAllocator;
const WasmAllocator = std.heap.WasmAllocator;
const builtin = @import("builtin");
