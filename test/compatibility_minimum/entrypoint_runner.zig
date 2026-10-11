//! Simple host-only runner for expected rejection diagnostics.
//! The default Zig runner counts every error log before fixture assertions can
//! validate it. Keep incompatible-engine rejection at error severity for users:
//! the extension cannot load, so this is not a recoverable warning. This runner
//! uses the fixture's strict diagnostic observer without changing runtime logging.
pub const std_options = @import("host_fixture").std_options;

/// Run the actual entrypoint counter tests, failing on assertions or leaks.
pub fn main() !void {
    var passed: usize = 0;
    for (builtin.test_functions) |test_fn| {
        std.testing.allocator_instance = .init(std.heap.page_allocator, .{
            .canary = 0xc3a701ba,
            .check_write_after_free = true,
        });
        const result = test_fn.func();
        const leaks = std.testing.allocator_instance.deinit();
        if (leaks != 0) return error.MemoryLeak;
        try result;
        passed += 1;
        std.debug.print("ENTRYPOINT_TEST_PASSED: {s}\n", .{test_fn.name});
    }
    std.debug.print("ENTRYPOINT_TESTS: {d}/{d} passed\n", .{ passed, builtin.test_functions.len });
}

const std = @import("std");
const builtin = @import("builtin");
