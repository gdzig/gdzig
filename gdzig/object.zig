pub fn assertIsObject(comptime T: type) void {
    assertIsA(Object, T);
}

pub fn assertIsObjectPtr(comptime T: type) void {
    assertIsA(Object, Child(T));
}

pub fn connect(obj: anytype, comptime S: type, callable: Callable) void {
    var signal_name: StringName = .fromComptimeLatin1(comptime meta.signalName(S));
    defer signal_name.deinit();

    _ = obj.connect(signal_name, callable, .{});
}

/// Downcast a value to a child type in the class hierarchy. Has some compile time checks, but returns null at runtime if the cast fails.
///
/// Expects pointer types, e.g `*Node` or `*MyClass`, not `Node` or `MyClass`.
pub fn downcast(comptime T: type, value: anytype) blk: {
    const U = @TypeOf(value);

    if (!isClassPtr(T)) {
        @compileError("downcast expects a class pointer type as the target type, found '" ++ @typeName(T) ++ "'");
    }
    if (!isClassPtr(U)) {
        @compileError("downcast expects a class pointer type as the source value, found '" ++ @typeName(U) ++ "'");
    }

    assertIsA(Child(U), Child(T));

    break :blk ?*Child(T);
} {
    const U = @TypeOf(value);

    if (@typeInfo(U) == .optional and value == null) {
        return null;
    }

    const name = typeName(Child(T));
    const tag = godot.interface.classdbGetClassTag(@ptrCast(name));
    const result = godot.interface.objectCastTo(@ptrCast(value), tag);

    if (result) |ptr| {
        if (isOpaqueClassPtr(T)) {
            return @ptrCast(@alignCast(ptr));
        } else {
            const obj: *anyopaque = godot.interface.objectGetInstanceBinding(ptr, godot.interface.library, null) orelse return null;
            return @ptrCast(@alignCast(obj));
        }
    } else {
        return null;
    }
}

/// Returns true if a type is a reference counted type.
///
/// Expects a class type, e.g. `Node` or `MyClass`, not `*Node` or `*MyClass`.
pub fn isRefCounted(comptime T: type) bool {
    return isA(RefCounted, T);
}

/// Returns true if a type is a pointer to a reference counted type.
///
/// Expects a pointer type, e.g. `*Node` or `*MyClass`, not `Node` or `MyClass`.
pub fn isRefCountedPtr(comptime T: type) bool {
    return isA(RefCounted, Child(T));
}

/// Upcasts a pointer to an object type.
///
/// Expects a pointer type, e.g. `*Node` or `*MyClass`, not `Node` or `MyClass`.
pub fn asObject(value: anytype) *Object {
    return upcast(*Object, value);
}

/// Upcasts a pointer to a reference counted type.
///
/// Expects a pointer type, e.g. `*Node` or `*MyClass`, not `Node` or `MyClass`.
pub fn asRefCounted(value: anytype) RefCounted {
    return upcast(*RefCounted, value);
}

pub const PropertyBuilder = struct {
    allocator: Allocator,
    properties: std.ArrayListUnmanaged(PropertyInfo) = .empty,

    pub fn append(self: *PropertyBuilder, comptime T: type, comptime field_name: [:0]const u8, comptime opt: struct {
        hint: PropertyHint = .property_hint_none,
        hint_string: [:0]const u8 = "",
        usage: PropertyUsageFlags = .property_usage_default,
    }) !void {
        const info = try PropertyInfo.fromField(self.allocator, T, field_name, .{
            .hint = opt.hint,
            .hint_string = opt.hint_string,
            .usage = opt.usage,
        });
        try self.properties.append(self.allocator, info);
    }
};

pub const PropertyInfo = extern struct {
    type: Variant.Tag,
    name: ?*StringName = null,
    class_name: ?*StringName = null,
    hint: PropertyHint = .property_hint_none,
    hint_string: ?*String = null,
    usage: PropertyUsageFlags = .property_usage_default,

    pub fn init(allocator: Allocator, comptime tag: Variant.Tag, comptime field_name: [:0]const u8) !PropertyInfo {
        const name = try allocator.create(StringName);
        name.* = StringName.fromComptimeLatin1(field_name);

        return .{
            .name = name,
            .type = tag,
        };
    }

    pub fn fromField(allocator: Allocator, comptime T: type, comptime field_name: [:0]const u8, comptime opt: struct {
        hint: PropertyHint = .property_hint_none,
        hint_string: [:0]const u8 = "",
        usage: PropertyUsageFlags = .property_usage_default,
    }) !PropertyInfo {
        // This double allocation is dumb, but the API expects *String and *StringName
        const name = try allocator.create(StringName);
        name.* = StringName.fromComptimeLatin1(field_name);

        const hint_string = try allocator.create(String);
        hint_string.* = String.fromLatin1(opt.hint_string);

        return .{
            .class_name = meta.typeName(T),
            .name = name,
            .type = Variant.Tag.forType(@FieldType(T, field_name)),
            .hint_string = hint_string,
            .hint = opt.hint,
            .usage = opt.usage,
        };
    }

    pub fn deinit(self: *PropertyInfo, allocator: Allocator) void {
        allocator.free(self.name);
        allocator.free(self.hint_string);
    }
};

pub var dummy_callbacks = struct {
    const dummy_callbacks = c.GDExtensionInstanceBindingCallbacks{
        .create_callback = instanceBindingCreateCallback,
        .free_callback = instanceBindingFreeCallback,
        .reference_callback = instanceBindingReferenceCallback,
    };

    fn instanceBindingCreateCallback(_: ?*anyopaque, _: ?*anyopaque) callconv(.c) ?*anyopaque {
        return null;
    }

    fn instanceBindingFreeCallback(_: ?*anyopaque, _: ?*anyopaque, _: ?*anyopaque) callconv(.c) void {}

    fn instanceBindingReferenceCallback(_: ?*anyopaque, _: ?*anyopaque, _: c.GDExtensionBool) callconv(.c) c.GDExtensionBool {
        return 1;
    }
}.dummy_callbacks;

fn assertCanInitialize(comptime T: type) void {
    comptime {
        if (@hasDecl(T, "init")) return;
        for (@typeInfo(T).@"struct".fields) |field| {
            if (std.mem.eql(u8, "base", field.name)) continue;
            if (field.default_value_ptr == null) {
                @compileError("The type '" ++ meta.typeShortName(T) ++ "' should either have an 'fn init(base: *" ++ meta.typeShortName(meta.BaseOf(T)) ++ ") " ++ meta.typeShortName(T) ++ "' function, or a default value for the field '" ++ field.name ++ "', but it has neither.");
            }
        }
    }
}

pub fn VTable(comptime T: type, comptime method_names: anytype) type {
    return struct {
        const map: std.StaticStringMap(CallVirtual(T)) = .initComptime(blk: {
            var kvs: [method_names.len]struct { []const u8, CallVirtual(T) } = undefined;
            for (method_names, 0..) |name, i| {
                kvs[i] = .{ name, makeWrapper(name) };
            }
            break :blk &kvs;
        });

        pub fn has(name: []const u8) bool {
            return map.has(name);
        }

        pub fn get(name: []const u8) ?CallVirtual(T) {
            return map.get(name);
        }

        pub fn extend(comptime Derived: type, comptime override_names: anytype) type {
            return VTable(Derived, combineNames(override_names));
        }

        fn combineNames(comptime override_names: anytype) [][]const u8 {
            var combined_names: [method_names.len + override_names.len][]const u8 = undefined;
            var i = 0;
            @memcpy(combined_names[0..method_names.len], method_names);
            outer: inline for (override_names) |override_name| {
                inline for (method_names) |method_name| {
                    if (std.mem.eql(u8, override_name, method_name)) {
                        continue :outer;
                    }
                }
                combined_names[method_names.len + i] = override_name;
                i += 1;
            }
            return combined_names[0 .. method_names.len + i];
        }

        fn makeWrapper(comptime method_name: []const u8) CallVirtual(T) {
            inline for (selfAndAncestorsOf(T)) |Owner| {
                if (@hasDecl(Owner, method_name)) {
                    const method = @field(Owner, method_name);
                    const FnType = @TypeOf(method);
                    const fn_info = @typeInfo(FnType).@"fn";
                    const ReturnType = fn_info.return_type orelse void;

                    return struct {
                        fn call(p_instance: *T, p_args: [*]const *const anyopaque, p_ret: *anyopaque) void {
                            const instance: *Owner = if (Owner == T) p_instance else upcast(*Owner, p_instance);

                            var args: std.meta.ArgsTuple(FnType) = undefined;
                            args[0] = instance;

                            inline for (1..fn_info.params.len) |j| {
                                const Arg = fn_info.params[j].type.?;
                                args[j] = @as(*const Arg, @ptrCast(@alignCast(p_args[j - 1]))).*;
                            }

                            if (ReturnType == void) {
                                @call(.always_inline, method, args);
                            } else {
                                const result = @call(.always_inline, method, args);
                                const ret: *ReturnType = @ptrCast(@alignCast(p_ret));
                                ret.* = result;
                            }
                        }
                    }.call;
                }
            }
            @compileError("Method '" ++ method_name ++ "' not found on " ++ @typeName(T) ++ " or any ancestor");
        }
    };
}

const std = @import("std");
const Allocator = std.mem.Allocator;

const oopz = @import("oopz");
pub const assertIsA = oopz.assertIsA;
pub const assertIsAny = oopz.assertIsAny;
pub const isClass = oopz.isClass;
pub const isOpaqueClass = oopz.isOpaqueClass;
pub const isStructClass = oopz.isStructClass;
pub const isClassPtr = oopz.isClassPtr;
pub const isOpaqueClassPtr = oopz.isOpaqueClassPtr;
pub const isStructClassPtr = oopz.isStructClassPtr;
pub const BaseOf = oopz.BaseOf;
pub const depthOf = oopz.depthOf;
pub const ancestorsOf = oopz.ancestorsOf;
pub const selfAndAncestorsOf = oopz.selfAndAncestorsOf;
pub const isA = oopz.isA;
pub const isAny = oopz.isAny;
pub const upcast = oopz.upcast;

const godot = @import("gdzig.zig");
const CallVirtual = godot.classdb.CallVirtual;
const Child = godot.meta.RecursiveChild;
const c = godot.c;
const meta = godot.meta;
const PropertyHint = godot.global.PropertyHint;
const PropertyUsageFlags = godot.global.PropertyUsageFlags;
const typeName = meta.typeName;
const Object = godot.class.Object;
const RefCounted = godot.class.RefCounted;
const Callable = godot.builtin.Callable;
const String = godot.builtin.String;
const StringName = godot.builtin.StringName;
const Variant = godot.builtin.Variant;
