/// Adds a group task to this WorkerThreadPool instance.
///
/// - **func**: A pointer to a function to run in the thread pool.
/// - **userdata**: A pointer to arbitrary data which will be passed to func.
/// - **elements**: The number of elements to process.
/// - **tasks**: The number of tasks needed in the group.
/// - **high_priority**: Whether or not this is a high priority task.
/// - **description**: An optional pointer to a String with the task description.
///
/// @see WorkerThreadPool::add_group_task()
///
/// **Since Godot 4.1**
pub inline fn addNativeGroupTask(
    self: *WorkerThreadPool,
    func: *const OpaqueWorkerThreadPoolCallback.GroupTask,
    userdata: ?*anyopaque,
    elements: i32,
    tasks: i32,
    high_priority: bool,
    description: ?*const String,
) void {
    raw.workerThreadPoolAddNativeGroupTask(
        self.ptr(),
        func,
        userdata,
        elements,
        tasks,
        @intFromBool(high_priority),
        if (description) |d| d.constPtr() else null,
    );
}

/// Adds a task to this WorkerThreadPool instance.
///
/// - **func**: A pointer to a function to run in the thread pool.
/// - **userdata**: A pointer to arbitrary data which will be passed to func.
/// - **high_priority**: Whether or not this is a high priority task.
/// - **description**: An optional pointer to a String with the task description.
///
/// **Since Godot 4.1**
pub inline fn addNativeTask(
    self: *WorkerThreadPool,
    func: *const OpaqueWorkerThreadPoolCallback.Task,
    userdata: ?*anyopaque,
    high_priority: bool,
    description: ?*const String,
) void {
    raw.workerThreadPoolAddNativeTask(
        self.ptr(),
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

// @mixin stop

const raw: *Interface = &@import("../gdzig_bindings.zig").raw;

const std = @import("std");

const builtin = @import("../builtin.zig");
const String = builtin.String;
const Interface = @import("../Interface.zig");
const WorkerThreadPool = @import("./worker_thread_pool.zig").WorkerThreadPool;
