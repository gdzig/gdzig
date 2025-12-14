pub fn fromClosure(p_instance: anytype, comptime p_function_ptr: anytype) Callable {
    // find the method on `p_instance` by pointer
    const T = comptime std.meta.Child(@TypeOf(p_instance));
    const decls = comptime std.meta.declarations(T);

    comptime var method_name: ?[:0]const u8 = null;

    inline for (decls) |decl| {
        const field = @field(T, decl.name);
        const p_func_ptr: *const anyopaque = @ptrCast(p_function_ptr);
        const decl_func_ptr: *const anyopaque = @ptrCast(&field);

        if (comptime p_func_ptr == decl_func_ptr) {
            method_name = decl.name;
            break;
        }
    }

    if (method_name == null) {
        std.debug.panic("Func pointer is not a method of the instance", .{});
    }

    var method_string_name: StringName = .fromComptimeLatin1(method_name.?);
    defer method_string_name.deinit();

    const obj = oopz.upcast(*Object, p_instance);

    if (!obj.hasMethod(method_string_name)) {
        std.debug.panic("Method '{s}' is not registered on type '{s}'. Did you forget to call godot.registerMethod?", .{ method_name.?, @typeName(T) });
    }

    return .initObjectMethod(obj, method_string_name);
}
// @mixin stop

const Self = gdzig.builtin.Callable;

const std = @import("std");

const gdzig = @import("gdzig");
const Callable = gdzig.builtin.Callable;
const StringName = gdzig.builtin.StringName;
const Object = gdzig.class.Object;

const oopz = @import("oopz");
