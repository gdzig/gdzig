fn callableClosureFunc(userdata: ?*anyopaque, args: [*c]const c.GDExtensionConstVariantPtr, arg_count: c.GDExtensionInt, ret: c.GDExtensionVariantPtr, err: [*c]c.GDExtensionCallError) callconv(.c) void {
    _ = userdata; // autofix
    _ = args; // autofix
    _ = arg_count; // autofix
    _ = ret; // autofix
    _ = err; // autofix

}

const CallableUserdata = struct {
    obj: *Object,
    function_ptr: *anyopaque,
};

pub fn fromClosure(p_instance: anytype, p_function_ptr: anytype) Callable {
    const userdata = heap.general_allocator.create(CallableUserdata) catch @panic("Failed to allocate CallableUserdata");
    userdata.* = .{
        .obj = object.asObject(p_instance),
        .function_ptr = @ptrCast(@constCast(p_function_ptr)),
    };

    var custom_info: c.GDExtensionCallableCustomInfo2 = .{
        .token = interface.library,
        .call_func = &callableClosureFunc,
        .callable_userdata = @ptrCast(@constCast(userdata)),
    };

    var callable: Callable = undefined;
    interface.callableCustomCreate2(@ptrCast(&callable), &custom_info);

    return callable;
}

const interface = gdzig.interface;
const Object = bindings.class.Object;
const Callable = bindings.builtin.Callable;

const heap = @import("heap.zig");
const bindings = @import("gdzig_bindings");
const object = @import("object.zig");
const c = @import("gdextension");
const gdzig = @import("gdzig.zig");
