pub fn fromClosure(p_instance: anytype, p_function_ptr: anytype) Callable {
    // find the method on `p_instance` by pointer
    const T = comptime std.meta.Child(@TypeOf(p_instance));
    const decls = comptime std.meta.declarations(T);

    var method_name: ?[:0]const u8 = null;

    inline for (decls) |decl| {
        const field = @field(T, decl.name);
        const p_func_ptr: *const anyopaque = @ptrCast(p_function_ptr);
        const decl_func_ptr: *const anyopaque = @ptrCast(&field);

        if (p_func_ptr == decl_func_ptr) {
            method_name = decl.name;
            break;
        }
    }

    if (method_name == null) {
        std.debug.panic("Func pointer is not a method of the instance", .{});
    }

    var method_string_name: StringName = .fromLatin1(method_name.?);
    defer method_string_name.deinit();

    return .initObjectMethod(oopz.upcast(*Object, p_instance), method_string_name);
}
// @mixin stop

const Callable = @import("callable.zig").Callable;
const StringName = @import("string_name.zig").StringName;
const Object = @import("../class/object.zig").Object;

const std = @import("std");
const oopz = @import("oopz");
