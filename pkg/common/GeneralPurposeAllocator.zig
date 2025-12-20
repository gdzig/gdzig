//! A wrapper around multiple allocator implementations based on the build target.
//!
//! | Target                         | Implementation            |
//! | ------------------------------ | ------------------------- |
//! | Testing                        | `std.heap.DebugAllocator` |
//! | WebAssembly                    | `std.heap.c_allocator`    |
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
    .testing => DebugAllocator(.{
        .stack_trace_frames = if (std.debug.sys_can_stack_trace) 10 else 0,
        .resize_stack_traces = true,
        // A unique value so that when a default-constructed
        // GeneralPurposeAllocator is incorrectly passed to testing allocator, or
        // vice versa, panic occurs.
        .canary = @truncate(0x2731e675c3a701ba),
    }),
    .safe => DebugAllocator(.{}),
    .fast, .wasm => Allocator,
},

pub fn init(backing_allocator: ?Allocator) GeneralPurposeAllocator {
    return .{
        .impl = switch (strategy) {
            .testing, .safe => .{
                .backing_allocator = backing_allocator orelse std.heap.page_allocator,
            },
            .wasm => std.heap.c_allocator,
            .fast => backing_allocator orelse std.heap.page_allocator,
        },
    };
}

pub fn allocator(self: *GeneralPurposeAllocator) Allocator {
    return switch (strategy) {
        .fast => self.impl,
        .wasm => std.heap.c_allocator,
        .testing, .safe => self.impl.allocator(),
    };
}

pub fn deinit(self: *GeneralPurposeAllocator) std.heap.Check {
    return switch (strategy) {
        .safe => self.impl.deinit(),
        inline else => .ok,
    };
}

const std = @import("std");
const Allocator = std.mem.Allocator;
const DebugAllocator = std.heap.DebugAllocator;
const builtin = @import("builtin");
