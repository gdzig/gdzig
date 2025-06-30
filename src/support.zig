pub inline fn bindBuiltinMethod(
    comptime T: type,
    comptime name: [:0]const u8,
    comptime hash: comptime_int,
) BuiltinMethod {
    const callback = struct {
        fn callback(string_name: core.StringName) BuiltinMethod {
            return core.variantGetPtrBuiltinMethod(@intFromEnum(godot.Variant.Tag.forType(T)), @ptrCast(&string_name), hash).?;
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
        fn callback(string_name: core.StringName) ClassMethod {
            const class_name = godot.meta.getNamePtr(T);
            return core.classdbGetMethodBind(@ptrCast(class_name), @ptrCast(@constCast(&string_name)), hash).?;
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
            return core.variantGetPtrConstructor(@intFromEnum(godot.Variant.Tag.forType(T)), index).?;
        }
    }.callback;

    return bind(null, callback);
}

pub inline fn bindDestructor(
    comptime T: type,
) Destructor {
    const callback = struct {
        fn callback() Destructor {
            return core.variantGetPtrDestructor(@intFromEnum(godot.Variant.Tag.forType(T))).?;
        }
    }.callback;

    return bind(null, callback);
}

pub inline fn bindFunction(
    comptime name: [:0]const u8,
    comptime hash: comptime_int,
) Function {
    const callback = struct {
        fn callback(string_name: core.StringName) Function {
            return core.variantGetPtrUtilityFunction(@ptrCast(@constCast(&string_name)), hash).?;
        }
    }.callback;

    return bind(name, callback);
}

pub inline fn bindVariantFrom(comptime @"type": godot.Variant.Tag) VariantFrom {
    const callback = struct {
        fn callback() VariantFrom {
            return core.getVariantFromTypeConstructor(@intFromEnum(@"type")).?;
        }
    }.callback;

    return bind(null, callback);
}

pub inline fn bindVariantTo(comptime @"type": godot.Variant.Tag) VariantTo {
    const callback = struct {
        fn callback() VariantTo {
            return core.getVariantToTypeConstructor(@intFromEnum(@"type")).?;
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
            Binding.function = callback(core.StringName.fromComptimeLatin1(name_));
        } else {
            Binding.function = callback();
        }
    }

    return Binding.function.?;
}

const std = @import("std");
const Child = std.meta.Child;

const godot = @import("root.zig");
const c = godot.c;
const core = godot.core;

const BuiltinMethod = Child(c.GDExtensionPtrBuiltInMethod);
const ClassMethod = Child(c.GDExtensionMethodBindPtr);
const Constructor = Child(c.GDExtensionPtrConstructor);
const Destructor = Child(c.GDExtensionPtrDestructor);
const Function = Child(c.GDExtensionPtrUtilityFunction);
const VariantFrom = Child(c.GDExtensionVariantFromTypeConstructorFunc);
const VariantTo = Child(c.GDExtensionTypeFromVariantConstructorFunc);
