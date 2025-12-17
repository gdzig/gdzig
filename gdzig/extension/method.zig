const std = @import("std");
const DeclEnum = std.meta.DeclEnum;

const gdzig = @import("gdzig");
const class = gdzig.class;
const classdb = gdzig.class.ClassDb;
const StringName = gdzig.builtin.StringName;
const Variant = gdzig.builtin.Variant;

pub fn registerMethod(comptime T: type, comptime name: DeclEnum(T)) void {
    const name_str = @tagName(name);
    var class_name: StringName = .fromType(T);
    var method_name: StringName = .fromMethodName(name_str);

    const MethodType = @TypeOf(@field(T, name_str));
    const fn_info = @typeInfo(MethodType).@"fn";
    const Args = fn_info.params;
    const ReturnType = fn_info.return_type orelse void;
    const arg_count = Args.len - 1;

    const return_value: classdb.PropertyInfo = .{
        .type = .forType(ReturnType),
    };

    const arg_infos: [arg_count]classdb.PropertyInfo = comptime blk: {
        var infos: [arg_count]classdb.PropertyInfo = undefined;
        for (0..arg_count) |i| {
            const ArgType = Args[i + 1].type.?;
            infos[i] = .{ .type = .forType(ArgType) };
        }
        break :blk infos;
    };

    const arg_metas: [arg_count]classdb.MethodArgumentMetadata = comptime blk: {
        var metas: [arg_count]classdb.MethodArgumentMetadata = undefined;
        for (0..arg_count) |i| {
            metas[i] = .none;
        }
        break :blk metas;
    };

    const Callbacks = struct {
        const method = @field(T, name_str);

        fn call(instance: *T, args: []const *const Variant) gdzig.CallError!Variant {
            var call_args: std.meta.ArgsTuple(MethodType) = undefined;
            call_args[0] = instance;
            inline for (1..Args.len) |i| {
                const ArgType = Args[i].type.?;
                if (i - 1 < args.len) {
                    call_args[i] = args[i - 1].as(ArgType) orelse return error.InvalidArgument;
                }
            }
            if (ReturnType == void) {
                @call(.auto, method, call_args);
                return Variant.nil;
            } else {
                const result = @call(.auto, method, call_args);
                return Variant.init(ReturnType, result);
            }
        }

        fn ptrCall(instance: *T, args: [*]const *const anyopaque, ret: ?*anyopaque) void {
            var call_args: std.meta.ArgsTuple(MethodType) = undefined;
            call_args[0] = instance;
            inline for (1..Args.len) |i| {
                const ArgType = Args[i].type.?;
                call_args[i] = ptrToArg(ArgType, args[i - 1]);
            }
            if (ReturnType == void) {
                @call(.auto, method, call_args);
            } else {
                const result = @call(.auto, method, call_args);
                if (ret) |r| {
                    @as(*ReturnType, @ptrCast(@alignCast(r))).* = result;
                }
            }
        }

        fn ptrToArg(comptime ArgType: type, p_arg: *const anyopaque) ArgType {
            if (comptime class.isRefCountedPtr(ArgType) and class.isOpaqueClassPtr(ArgType)) {
                const obj = gdzig.raw.refGetObject(@ptrCast(p_arg));
                return @ptrCast(obj.?);
            } else if (comptime class.isOpaqueClassPtr(ArgType)) {
                return @ptrCast(@constCast(p_arg));
            } else {
                return @as(*const ArgType, @ptrCast(@alignCast(p_arg))).*;
            }
        }
    };

    classdb.registerMethod(T, void, &class_name, .{
        .name = &method_name,
        .return_value_info = if (ReturnType != void) @constCast(&return_value) else null,
        .argument_info = @constCast(&arg_infos),
        .argument_metadata = @constCast(&arg_metas),
    }, .{
        .call = Callbacks.call,
        .ptr_call = Callbacks.ptrCall,
    });
}
