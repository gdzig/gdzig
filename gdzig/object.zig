pub fn assertIsObject(comptime T: type) void {
    assertIsA(Object, T);
}

pub fn assertIsObjectPtr(comptime T: type) void {
    assertIsA(Object, Child(T));
}

/// Create a Godot object.
pub fn create(comptime T: type) !*T {
    comptime assertIsObject(T);

    // If this is an engine type, just return it.
    if (comptime @typeInfo(T) == .@"opaque") {
        return @ptrCast(godot.interface.classdbConstructObject2(@ptrCast(meta.typeName(T))).?);
    }

    // Assert that we can initialize the user type
    comptime {
        if (!@hasDecl(T, "init")) {
            for (@typeInfo(T).@"struct".fields) |field| {
                if (std.mem.eql(u8, "base", field.name)) continue;
                if (field.default_value_ptr == null) {
                    @compileError("The type '" ++ meta.typeShortName(T) ++ "' should either have an 'fn init(base: *" ++ meta.typeShortName(meta.BaseOf(T)) ++ ") " ++ meta.typeShortName(T) ++ "' function, or a default value for the field '" ++ field.name ++ "', but it has neither.");
                }
            }
        }
    }

    // Construct the base object
    const base_name = meta.typeName(BaseOf(T));
    const base: *BaseOf(T) = @ptrCast(godot.interface.classdbConstructObject2(@ptrCast(base_name)).?);

    // Allocate the user object, and link it to the base object
    const class_name = meta.typeName(T);
    const self: *T = try godot.heap.general_allocator.create(T);
    godot.interface.objectSetInstance(@ptrCast(base), @ptrCast(class_name), @ptrCast(self));
    godot.interface.objectSetInstanceBinding(@ptrCast(base), godot.interface.library, @ptrCast(self), &dummy_callbacks);

    // Initialize the user object
    if (@hasDecl(T, "init")) {
        self.* = T.init(base);
    } else {
        self.* = .{ .base = base };
    }

    return self;
}

/// Recreate a Godot object.
pub fn recreate(comptime T: type, ptr: ?*anyopaque) !*T {
    assertIsObject(T);
    _ = ptr;
    @panic("Extension reloading is not currently supported");
}

/// Destroy a Godot object.
pub fn destroy(instance: anytype) void {
    assertIsObjectPtr(@TypeOf(instance));

    const ptr: *anyopaque = @ptrCast(asObject(instance));
    godot.interface.objectFreeInstanceBinding(ptr, godot.interface.library);
    godot.interface.objectDestroy(ptr);
}

/// Unreference a Godot object.
pub fn unreference(instance: anytype) void {
    if (meta.asRefCounted(instance).unreference()) {
        godot.interface.objectDestroy(@ptrCast(asObject(instance)));
    }
}

pub fn connect(obj: anytype, comptime S: type, callable: Callable) void {
    if (!isClassPtr(obj)) {
        @compileError("pointer type expected for parameter 'obj'");
    }

    const signal_name = comptime meta.signalName(S);

    // TODO: I think this is a memory leak??
    _ = obj.connect(.fromComptimeLatin1(signal_name), callable, .{});
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

    fn instanceBindingCreateCallback(_: ?*anyopaque, _: ?*anyopaque) callconv(.C) ?*anyopaque {
        return null;
    }

    fn instanceBindingFreeCallback(_: ?*anyopaque, _: ?*anyopaque, _: ?*anyopaque) callconv(.C) void {}

    fn instanceBindingReferenceCallback(_: ?*anyopaque, _: ?*anyopaque, _: c.GDExtensionBool) callconv(.C) c.GDExtensionBool {
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
