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

const std = @import("std");
const Child = std.meta.Child;

const godot = @import("gdzig.zig");
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
