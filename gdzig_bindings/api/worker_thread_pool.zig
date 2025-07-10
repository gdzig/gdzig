const raw: *Interface = &@import("../../gdzig_bindings.zig").raw;

/// Adds a group task to an instance of WorkerThreadPool.
///
/// @param pool A pointer to a WorkerThreadPool object.
/// @param func A pointer to a function to run in the thread pool.
/// @param userdata A pointer to arbitrary data which will be passed to func.
/// @param elements The number of elements to process.
/// @param tasks The number of tasks needed in the group.
/// @param high_priority Whether or not this is a high priority task.
/// @param description An optional pointer to a String with the task description.
///
/// @see WorkerThreadPool::add_group_task()
///
/// @since 4.1
pub inline fn workerThreadPoolAddNativeGroupTask(
    pool: *WorkerThreadPool,
    func: *const OpaqueWorkerThreadPoolCallback.GroupTask,
    userdata: ?*anyopaque,
    elements: i32,
    tasks: i32,
    high_priority: bool,
    description: ?*const String,
) void {
    raw.workerThreadPoolAddNativeGroupTask(
        pool.ptr(),
        func,
        userdata,
        elements,
        tasks,
        @intFromBool(high_priority),
        if (description) |d| d.constPtr() else null,
    );
}

/// Adds a task to an instance of WorkerThreadPool.
///
/// @param pool A pointer to a WorkerThreadPool object.
/// @param func A pointer to a function to run in the thread pool.
/// @param userdata A pointer to arbitrary data which will be passed to func.
/// @param high_priority Whether or not this is a high priority task.
/// @param description An optional pointer to a String with the task description.
///
/// @since 4.1
pub inline fn workerThreadPoolAddNativeTask(
    pool: *WorkerThreadPool,
    func: *const OpaqueWorkerThreadPoolCallback.Task,
    userdata: ?*anyopaque,
    high_priority: bool,
    description: ?*const String,
) void {
    raw.workerThreadPoolAddNativeTask(
        pool.ptr(),
        func,
        userdata,
        @intFromBool(high_priority),
        if (description) |d| d.constPtr() else null,
    );
}

pub const OpaqueWorkerThreadPoolCallback = WorkerThreadPoolCallback(anyopaque);

pub inline fn WorkerThreadPoolCallback(comptime Userdata: type) type {
    return struct {
        pub const GroupTask = if (Userdata != void)
            fn (userdata: *Userdata, index: u32) void
        else
            fn (index: u32) void;

        pub const Task = if (Userdata != void)
            fn (userdata: *Userdata) void
        else
            fn () void;

        fn wrapGroupTask(comptime original: *const GroupTask) fn (userdata: ?*anyopaque, index: u32) callconv(.C) void {
            return struct {
                fn wrapped(userdata: ?*anyopaque, index: u32) callconv(.C) void {
                    if (Userdata != void) {
                        const data = @as(*Userdata, @ptrCast(@alignCast(userdata)));
                        original(data, index);
                    } else {
                        original(index);
                    }
                }
            }.wrapped;
        }

        fn wrapTask(comptime original: *const Task) fn (userdata: ?*anyopaque) callconv(.C) void {
            return struct {
                fn wrapped(userdata: ?*anyopaque) callconv(.C) void {
                    if (Userdata != void) {
                        const data = @as(*Userdata, @ptrCast(@alignCast(userdata)));
                        original(data);
                    } else {
                        original();
                    }
                }
            }.wrapped;
        }
    };
}

const std = @import("std");

const builtin = @import("../builtin.zig");
const String = builtin.String;
const class = @import("../class.zig");
const WorkerThreadPool = class.WorkerThreadPool;
const Interface = @import("../Interface.zig");
