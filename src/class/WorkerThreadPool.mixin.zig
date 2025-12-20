/// Adds a group task to this WorkerThreadPool instance.
///
/// - **func**: A pointer to a function to run in the thread pool.
/// - **elements**: The number of elements to process.
/// - **tasks**: The number of tasks needed in the group.
/// - **high_priority**: Whether or not this is a high priority task.
/// - **description**: An optional pointer to a String with the task description.
///
/// @see WorkerThreadPool::add_group_task()
///
/// **Since Godot 4.1**
pub inline fn addNativeGroupTask(
    self: *Self,
    comptime func: *const Task(void),
    elements: i32,
    tasks: i32,
    high_priority: bool,
    description: ?*const String,
) void {
    self.addNativeGroupTaskWithUserdata(void, func, null, elements, tasks, high_priority, description);
}

/// Adds a group task to this WorkerThreadPool instance.
///
/// - **Userdata**: The type of the `userdata` passed to func.
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
pub inline fn addNativeGroupTaskWithUserdata(
    self: *Self,
    comptime Userdata: type,
    comptime func: *const Task(Userdata),
    userdata: *Userdata,
    elements: i32,
    tasks: i32,
    high_priority: bool,
    description: ?*const String,
) void {
    raw.workerThreadPoolAddNativeGroupTask(
        self.ptr(),
        &wrapGroupTask(Userdata, func),
        @ptrCast(userdata),
        elements,
        tasks,
        @intFromBool(high_priority),
        if (description) |d| d.constPtr() else null,
    );
}

/// Adds a task to this WorkerThreadPool instance.
///
/// - **func**: A pointer to a function to run in the thread pool.
/// - **high_priority**: Whether or not this is a high priority task.
/// - **description**: An optional pointer to a String with the task description.
///
/// **Since Godot 4.1**
pub inline fn addNativeTask(
    self: *Self,
    comptime func: *const Task(void),
    high_priority: bool,
    description: ?*const String,
) void {
    self.addNativeTaskWithUserdata(void, func, null, high_priority, description);
}

/// Adds a task to this WorkerThreadPool instance.
///
/// - **Userdata**: The type of the `userdata` passed to func.
/// - **func**: A pointer to a function to run in the thread pool.
/// - **userdata**: A pointer to arbitrary data which will be passed to func.
/// - **high_priority**: Whether or not this is a high priority task.
/// - **description**: An optional pointer to a String with the task description.
///
/// **Since Godot 4.1**
pub inline fn addNativeTaskWithUserdata(
    self: *Self,
    comptime Userdata: type,
    comptime func: *const Task(Userdata),
    userdata: *Userdata,
    high_priority: bool,
    description: ?*const String,
) void {
    raw.workerThreadPoolAddNativeTask(
        self.ptr(),
        &wrapTask(Userdata, func),
        @ptrCast(userdata),
        @intFromBool(high_priority),
        if (description) |d| d.constPtr() else null,
    );
}

pub fn GroupTask(comptime Userdata: type) type {
    return if (Userdata != void)
        fn (userdata: *Userdata, index: u32) void
    else
        fn (index: u32) void;
}

fn wrapGroupTask(comptime Userdata: type, comptime original: *const GroupTask(Userdata)) fn (userdata: ?*anyopaque, index: u32) callconv(.c) void {
    return struct {
        fn wrapped(userdata: ?*anyopaque, index: u32) callconv(.c) void {
            if (Userdata != void) {
                const data: *Userdata = @ptrCast(@alignCast(userdata));
                original(data, index);
            } else {
                original(index);
            }
        }
    }.wrapped;
}

pub fn Task(comptime Userdata: type) type {
    return if (Userdata != void)
        fn (userdata: *Userdata) void
    else
        fn () void;
}

fn wrapTask(comptime Userdata: type, comptime original: *const Task(Userdata)) fn (userdata: ?*anyopaque) callconv(.c) void {
    return struct {
        fn wrapped(userdata: ?*anyopaque) callconv(.c) void {
            if (Userdata != void) {
                const data: *Userdata = @ptrCast(@alignCast(userdata));
                original(data);
            } else {
                original();
            }
        }
    }.wrapped;
}

// @mixin stop

const Self = gdzig.class.WorkerThreadPool;

const gdzig = @import("gdzig");
const raw = &gdzig.raw;
const String = gdzig.builtin.String;
