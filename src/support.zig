pub inline fn bindBuiltinMethod(
    comptime T: type,
    comptime name: [:0]const u8,
    comptime hash: comptime_int,
) BuiltinMethod {
    const callback = struct {
        fn callback(string_name: godot.builtin.StringName) BuiltinMethod {
            return godot.interface.variantGetPtrBuiltinMethod(@intFromEnum(Variant.Tag.forType(T)), @ptrCast(&string_name), hash).?;
        }
    }.callback;

    return bind(name, callback);
}

pub inline fn bindClassMethod(
    comptime T: type,
    comptime name: [:0]const u8,
    comptime hash: comptime_int,
) ClassMethod {
    const callback = struct {
        fn callback(string_name: godot.builtin.StringName) ClassMethod {
            const class_name = godot.meta.getNamePtr(T);
            return godot.interface.classdbGetMethodBind(@ptrCast(class_name), @ptrCast(@constCast(&string_name)), hash).?;
        }
    }.callback;

    return bind(name, callback);
}

pub inline fn bindConstructor(
    comptime T: type,
    comptime index: comptime_int,
) Constructor {
    const callback = struct {
        fn callback() Constructor {
            return godot.interface.variantGetPtrConstructor(@intFromEnum(Variant.Tag.forType(T)), index).?;
        }
    }.callback;

    return bind(null, callback);
}

pub inline fn bindDestructor(
    comptime T: type,
) Destructor {
    const callback = struct {
        fn callback() Destructor {
            return godot.interface.variantGetPtrDestructor(@intFromEnum(Variant.Tag.forType(T))).?;
        }
    }.callback;

    return bind(null, callback);
}

pub inline fn bindFunction(
    comptime name: [:0]const u8,
    comptime hash: comptime_int,
) Function {
    const callback = struct {
        fn callback(string_name: godot.builtin.StringName) Function {
            return godot.interface.variantGetPtrUtilityFunction(@ptrCast(@constCast(&string_name)), hash).?;
        }
    }.callback;

    return bind(name, callback);
}

pub inline fn bindVariantFrom(comptime @"type": Variant.Tag) VariantFrom {
    const callback = struct {
        fn callback() VariantFrom {
            return godot.interface.getVariantFromTypeConstructor(@intFromEnum(@"type")).?;
        }
    }.callback;

    return bind(null, callback);
}

pub inline fn bindVariantTo(comptime @"type": Variant.Tag) VariantTo {
    const callback = struct {
        fn callback() VariantTo {
            return godot.interface.getVariantToTypeConstructor(@intFromEnum(@"type")).?;
        }
    }.callback;

    return bind(null, callback);
}

pub inline fn bindVariantOperator(comptime op: Variant.Operator, comptime lhs: Variant.Tag, comptime rhs: ?Variant.Tag) VariantOperatorEvaluator {
    const callback = struct {
        fn callback() VariantOperatorEvaluator {
            return godot.interface.variantGetPtrOperatorEvaluator(
                @intFromEnum(op),
                @intFromEnum(lhs),
                if (rhs) |tag| @intFromEnum(tag) else null,
            ).?;
        }
    }.callback;

    return bind(null, callback);
}

inline fn bind(
    comptime name: ?[:0]const u8,
    comptime callback: anytype,
) @typeInfo(@TypeOf(callback)).@"fn".return_type.? {
    // building all elements into the struct ensures that the binding is generated
    // for every unique type
    const T = @typeInfo(@TypeOf(callback)).@"fn".return_type.?;
    const Binding = struct {
        var _ = .{ name, callback };
        var function: ?T = null;
    };

    if (Binding.function == null) {
        if (name) |name_| {
            Binding.function = callback(godot.builtin.StringName.fromComptimeLatin1(name_));
        } else {
            Binding.function = callback();
        }
    }

    return Binding.function.?;
}

pub fn MethodBinderT(comptime MethodType: type) type {
    return struct {
        pub const ReturnType = @typeInfo(MethodType).@"fn".return_type;
        pub const ArgCount = @typeInfo(MethodType).@"fn".params.len;
        pub const ArgsTuple = std.meta.fields(std.meta.ArgsTuple(MethodType));
        pub var arg_properties: [ArgCount + 1]c.GDExtensionPropertyInfo = undefined;
        pub var arg_metadata: [ArgCount + 1]c.GDExtensionClassMethodArgumentMetadata = undefined;
        pub var method_name: StringName = undefined;
        pub var method_info: c.GDExtensionClassMethodInfo = undefined;

        pub fn bindCall(p_method_userdata: ?*anyopaque, p_instance: c.GDExtensionClassInstancePtr, p_args: [*c]const c.GDExtensionConstVariantPtr, p_argument_count: c.GDExtensionInt, p_return: c.GDExtensionVariantPtr, p_error: [*c]c.GDExtensionCallError) callconv(.C) void {
            _ = p_error;
            const method: *MethodType = @ptrCast(@alignCast(p_method_userdata));
            if (ArgCount == 0) {
                if (ReturnType == void or ReturnType == null) {
                    @call(.auto, method, .{});
                } else {
                    @as(*Variant, @ptrCast(p_return)).* = Variant.init(@call(.auto, method, .{}));
                }
            } else {
                var variants: [ArgCount - 1]Variant = undefined;
                var args: std.meta.ArgsTuple(MethodType) = undefined;
                args[0] = @ptrCast(@alignCast(p_instance));
                inline for (0..ArgCount - 1) |i| {
                    if (i < p_argument_count) {
                        godot.interface.variantNewCopy(@ptrCast(&variants[i]), @ptrCast(p_args[i]));
                    }

                    args[i + 1] = variants[i].as(ArgsTuple[i + 1].type);
                }
                if (ReturnType == void or ReturnType == null) {
                    @call(.auto, method, args);
                } else {
                    @as(*Variant, @ptrCast(p_return)).* = Variant.init(@call(.auto, method, args));
                }
            }
        }

        fn ptrToArg(comptime T: type, p_arg: c.GDExtensionConstTypePtr) T {
            // TODO: I think this does not increment refcount on user-defined RefCounted types
            if (comptime meta.isRefCounted(T) and meta.isWrappedPointer(T)) {
                const obj = godot.interface.refGetObject(p_arg);
                return @bitCast(Object{ .ptr = obj.? });
            } else if (comptime meta.isObject(T) and meta.isWrappedPointer(T)) {
                return @bitCast(Object{ .ptr = @constCast(p_arg.?) });
            } else {
                return @as(*T, @ptrCast(@constCast(@alignCast(p_arg)))).*;
            }
        }

        pub fn bindPtrcall(p_method_userdata: ?*anyopaque, p_instance: c.GDExtensionClassInstancePtr, p_args: [*c]const c.GDExtensionConstTypePtr, p_return: c.GDExtensionTypePtr) callconv(.C) void {
            const method: *MethodType = @ptrCast(@alignCast(p_method_userdata));
            if (ArgCount == 0) {
                if (ReturnType == void or ReturnType == null) {
                    @call(.auto, method, .{});
                } else {
                    @as(*ReturnType.?, @ptrCast(@alignCast(p_return))).* = @call(.auto, method, .{});
                }
            } else {
                var args: std.meta.ArgsTuple(MethodType) = undefined;
                args[0] = @ptrCast(@alignCast(p_instance));
                inline for (1..ArgCount) |i| {
                    args[i] = ptrToArg(ArgsTuple[i].type, p_args[i - 1]);
                }
                if (ReturnType == void or ReturnType == null) {
                    @call(.auto, method, args);
                } else {
                    @as(*ReturnType.?, @ptrCast(@alignCast(p_return))).* = @call(.auto, method, args);
                }
            }
        }
    };
}

const std = @import("std");
const Child = std.meta.Child;

const godot = @import("gdzig.zig");
const meta = godot.meta;
const Object = godot.class.Object;
const StringName = godot.builtin.StringName;
const Variant = godot.builtin.Variant;
const c = godot.c;

const BuiltinMethod = Child(c.GDExtensionPtrBuiltInMethod);
const ClassMethod = Child(c.GDExtensionMethodBindPtr);
const Constructor = Child(c.GDExtensionPtrConstructor);
const Destructor = Child(c.GDExtensionPtrDestructor);
const Function = Child(c.GDExtensionPtrUtilityFunction);
const VariantFrom = Child(c.GDExtensionVariantFromTypeConstructorFunc);
const VariantTo = Child(c.GDExtensionTypeFromVariantConstructorFunc);
const VariantOperatorEvaluator = Child(c.GDExtensionPtrOperatorEvaluator);
