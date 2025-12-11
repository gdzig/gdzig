pub fn runInit(comptime testcase: type, current: godot.InitializationLevel) void {
    const level: godot.InitializationLevel = if (@hasDecl(testcase, "level"))
        testcase.level
    else
        .scene;

    if (current != level) return;

    if (@hasDecl(testcase, "init")) {
        callTestFn(testcase.init) catch |e| fail(e);
    }
    callTestFn(testcase.run) catch |e| fail(e);
}

pub fn runDeinit(comptime testcase: type, current: godot.InitializationLevel) void {
    const level: godot.InitializationLevel = if (@hasDecl(testcase, "level"))
        testcase.level
    else
        .scene;

    if (current != level) return;

    if (@hasDecl(testcase, "deinit")) {
        callTestFn(testcase.deinit) catch |e| fail(e);
    }
    pass();
}

fn callTestFn(comptime func: anytype) !void {
    const ReturnType = @typeInfo(@TypeOf(func)).@"fn".return_type.?;
    if (ReturnType == void) {
        func();
    } else if (@typeInfo(ReturnType) == .error_union) {
        try func();
    } else {
        @compileError("test function must return void or !void");
    }
}

fn pass() noreturn {
    std.process.exit(0);
}

fn fail(err: anyerror) noreturn {
    std.debug.print("{s}\n", .{@errorName(err)});
    std.process.exit(1);
}

const std = @import("std");
pub const FailingAllocator = std.testing.FailingAllocator;
pub const FuzzInputOptions = std.testing.FuzzInputOptions;
pub const Reader = std.testing.Reader;
pub const TmpDir = std.testing.TmpDir;
pub const allocator = std.testing.allocator;
pub const backend_can_print = std.testing.backend_can_print;
pub const checkAllAllocationFailures = std.testing.checkAllAllocationFailures;
pub const expect = std.testing.expect;
pub const expectEqualSentinel = std.testing.expectEqualSentinel;
pub const expectEqualSlices = std.testing.expectEqualSlices;
pub const expectEqualStrings = std.testing.expectEqualStrings;
pub const expectError = std.testing.expectError;
pub const expectFmt = std.testing.expectFmt;
pub const expectStringEndsWith = std.testing.expectStringEndsWith;
pub const expectStringStartsWith = std.testing.expectStringStartsWith;
pub const failing_allocator = std.testing.failing_allocator;
pub const refAllDecls = std.testing.refAllDecls;
pub const refAllDeclsRecursive = std.testing.refAllDeclsRecursive;
pub const tmpDir = std.testing.tmpDir;

const godot = @import("gdzig");
