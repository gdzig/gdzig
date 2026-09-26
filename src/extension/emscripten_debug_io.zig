//! Minimal `std.Io` implementation used as `std_options_debug_io` for
//! wasm32-emscripten builds on Zig 0.16.x.
//!
//! Works around ziglang/zig#31849
//! (https://codeberg.org/ziglang/zig/issues/31849): in Zig 0.16.0,
//! `std.os.emscripten.W.STOPSIG` has the wrong return type, and it is
//! analyzed through the default `std.Options.debug_io`, so anything
//! referencing `std.Io.Threaded` fails to compile for wasm32-emscripten.
//! Fixed upstream by ziglang/zig#31850 (master, backported to the 0.16.x
//! branch), so this is only needed for 0.16.x releases.
//!
//! Everything behaves like `std.Io.failing` except stderr, which is written
//! to fd 2 through libc; emscripten forwards it to the browser console. This
//! keeps `std.log`, `std.debug.print`, and the default panic handler working
//! in web builds.
//!
// TODO(zig 0.16.0): remove this entire workaround module once support for
// 0.16.x is dropped (upstream fix ziglang/zig#31850 is in 0.17).
/// Whether the workaround applies to the current target and compiler.
pub const needed = builtin.os.tag == .emscripten and
    builtin.zig_version.major == 0 and
    builtin.zig_version.minor == 16;

pub const io: std.Io = .{
    .userdata = null,
    .vtable = &vtable,
};

const vtable: std.Io.VTable = blk: {
    var vt = std.Io.failing.vtable.*;
    vt.swapCancelProtection = swapCancelProtection;
    vt.checkCancel = checkCancel;
    vt.lockStderr = lockStderr;
    vt.tryLockStderr = tryLockStderr;
    vt.unlockStderr = unlockStderr;
    vt.operate = operate;
    break :blk vt;
};

var stderr_writer: File.Writer = undefined;
var stderr_writer_initialized = false;

fn lockStderr(userdata: ?*anyopaque, terminal_mode: ?Terminal.Mode) Cancelable!LockedStderr {
    _ = userdata;
    if (!stderr_writer_initialized) {
        stderr_writer = .initStreaming(.stderr(), io, &.{});
        stderr_writer_initialized = true;
    }
    return .{
        .file_writer = &stderr_writer,
        .terminal_mode = terminal_mode orelse .no_color,
    };
}

fn tryLockStderr(userdata: ?*anyopaque, terminal_mode: ?Terminal.Mode) Cancelable!?LockedStderr {
    return try lockStderr(userdata, terminal_mode);
}

fn unlockStderr(userdata: ?*anyopaque) void {
    _ = userdata;
    if (stderr_writer.err == null) stderr_writer.interface.flush() catch {};
    stderr_writer.err = null;
    stderr_writer.interface.end = 0;
    stderr_writer.interface.buffer = &.{};
}

fn swapCancelProtection(userdata: ?*anyopaque, new: CancelProtection) CancelProtection {
    _ = userdata;
    return new;
}

fn checkCancel(userdata: ?*anyopaque) Cancelable!void {
    _ = userdata;
}

fn operate(userdata: ?*anyopaque, operation: Operation) Cancelable!Operation.Result {
    switch (operation) {
        .file_write_streaming => |op| {
            if (op.file.handle != std.posix.STDERR_FILENO) {
                return .{ .file_write_streaming = error.NoSpaceLeft };
            }
            var written: usize = 0;
            written += writeStderr(op.header) catch |err| {
                return .{ .file_write_streaming = err };
            };
            for (op.data, 0..) |bytes, i| {
                const count = if (i == op.data.len - 1) op.splat else 1;
                for (0..count) |_| {
                    written += writeStderr(bytes) catch |err| {
                        return .{ .file_write_streaming = err };
                    };
                }
            }
            return .{ .file_write_streaming = written };
        },
        else => return std.Io.failingOperate(userdata, operation),
    }
}

fn writeStderr(bytes: []const u8) Operation.FileWriteStreaming.Error!usize {
    var rest = bytes;
    while (rest.len > 0) {
        const n = std.c.write(std.posix.STDERR_FILENO, rest.ptr, rest.len);
        if (n <= 0) return error.InputOutput;
        rest = rest[@intCast(n)..];
    }
    return bytes.len;
}

const std = @import("std");
const builtin = @import("builtin");

const File = std.Io.File;
const Terminal = std.Io.Terminal;

const Cancelable = std.Io.Cancelable;
const CancelProtection = std.Io.CancelProtection;
const LockedStderr = std.Io.LockedStderr;
const Operation = std.Io.Operation;
