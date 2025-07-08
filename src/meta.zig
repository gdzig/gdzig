const std = @import("std");
const fmt = std.fmt;
const Tuple = std.meta.Tuple;

const godot = @import("gdzig.zig");
const assertIs = godot.debug.assertIs;
const Object = godot.class.Object;
const RefCounted = godot.class.RefCounted;
const StringName = godot.builtin.StringName;

/// Returns true if the type is a Godot "class" type.
///
/// Expects the underlying type, e.g `Node` or `MyClass`, not `*Node` or `*MyClass`.
pub fn isClassType(comptime T: type) bool {
    return comptime switch (@typeInfo(T)) {
        .@"struct" => @hasField(T, "base") and isClassPtr(@FieldType(T, "base")),
        .@"opaque" => T == Object or @hasDecl(T, "Base") and isClassType(T.Base),
        else => false,
    };
}

/// Returns true if a type is an official class from Godot (versus a class defined by this extension).
///
/// Expects a class type, e.g. `Node` or `MyClass`, not `*Node` or `*MyClass`.
pub fn isGodotClassType(comptime T: type) bool {
    return switch (@typeInfo(T)) {
        .@"opaque" => isClassType(T),
        else => false,
    };
}

/// Returns true if a type is a class defined by this extension (versus an official class from Godot).
///
/// Expects a class type, e.g. `Node` or `MyClass`, not `*Node` or `*MyClass`.
pub fn isExtensionClassType(comptime T: type) bool {
    return switch (@typeInfo(T)) {
        .@"struct" => isClassType(T),
        else => false,
    };
}

/// Returns true if the type is pointer to a Godot "class" type.
///
/// Expects a pointer type, e.g. `*Node` or `*MyClass`, not `Node` or `MyClass`.
pub fn isClassPtr(comptime T: type) bool {
    return comptime sw: switch (@typeInfo(T)) {
        .optional => |info| continue :sw @typeInfo(info.child),
        .pointer => |info| isClassType(info.child),
        else => false,
    };
}

/// Returns true if a type is a pointer to an official class from Godot (versus a class defined by this extension).
///
/// Expects a pointer type, e.g. `*Node` or `*MyClass`, not `Node` or `MyClass`.
pub fn isGodotClassPtr(comptime T: type) bool {
    return comptime sw: switch (@typeInfo(T)) {
        .optional => |info| continue :sw @typeInfo(info.child),
        .pointer => |info| isGodotClassType(info.child),
        else => false,
    };
}

/// Returns true if a type is a pointer to a class defined by this extension (versus an official class from Godot).
///
/// Expects a pointer type, e.g. `*Node` or `*MyClass`, not `Node` or `MyClass`.
pub fn isExtensionClassPtr(comptime T: type) bool {
    return comptime sw: switch (@typeInfo(T)) {
        .optional => |info| continue :sw @typeInfo(info.child),
        .pointer => |info| isExtensionClassType(info.child),
        else => false,
    };
}

/// Returns the base type of T.
///
/// Expects a class type, e.g `Node` or `MyClass`, not `*Node` or `*MyClass`.
pub fn BaseOf(comptime T: type) type {
    if (comptime !isClassType(T)) {
        if (comptime isClassPtr(T)) {
            @compileError("expected a Godot class type, found '" ++ @typeName(T) ++ "'. did you mean '" ++ @typeName(Child(T)) ++ "'?");
        }
        @compileError("expected a Godot class type, found '" ++ @typeName(T) ++ "'. did you remember to add the 'base' struct field?");
    }

    return comptime switch (@typeInfo(T)) {
        .@"struct" => Child(@FieldType(T, "base")),
        .@"opaque" => T.Base,
        else => unreachable,
    };
}

/// Returns how many levels of inheritance T has.
///
/// Expects a class type, e.g `Node` or `MyClass`, not `*Node` or `*MyClass`.
pub fn depthOf(comptime T: type) comptime_int {
    comptime var i = 0;
    comptime var Cur = T;
    inline while (isClassType(Cur) and Cur != Object) : (i += 1) {
        Cur = BaseOf(Cur);
    }
    return i;
}

/// Returns the type hierarchy of T as an array of types, in ascending order, starting with the parent of T.
///
/// Expects a class type, e.g `Node` or `MyClass`, not `*Node` or `*MyClass`.
pub fn ancestorsOf(comptime T: type) [depthOf(T)]type {
    if (comptime depthOf(T) == 0) {
        return [0]type{};
    }

    comptime var hierarchy: [depthOf(T)]type = undefined;
    inline for (0..depthOf(T)) |i| {
        hierarchy[i] = BaseOf(if (i == 0) T else hierarchy[i - 1]);
    }
    return hierarchy;
}

/// Returns the type hierarchy of T as an array of types, in ascending order. starting with T.
///
/// Expects a class type, e.g `Node` or `MyClass`, not `*Node` or `*MyClass`.
pub fn selfAndAncestorsOf(comptime T: type) [1 + depthOf(T)]type {
    return [_]type{T} ++ ancestorsOf(T);
}

/// Is U a child of T
///
/// Expects class types, e.g `Node` or `MyClass`, not `*Node` or `*MyClass`.
pub fn isA(comptime T: type, comptime U: type) bool {
    if (isClassPtr(T) or isClassPtr(U)) {
        @compileError("isA expects a class type, not a pointer type; found '" ++ @typeName(T) ++ "' and '" ++ @typeName(U) ++ "'");
    }
    if (!isClassType(T) or !isClassType(U)) {
        return false;
    }
    if (comptime T == U) {
        return true;
    }

    @setEvalBranchQuota(10_000);
    inline for (selfAndAncestorsOf(T)) |Ancestor| {
        if (comptime T == Ancestor) {
            return true;
        }
    }

    return false;
}

/// Is U a child of any of the types in types
///
/// Expects class types, e.g `Node` or `MyClass`, not `*Node` or `*MyClass`.
pub fn isAny(comptime types: anytype, comptime U: type) bool {
    inline for (0..types.len) |i| {
        if (comptime isA(types[i], U)) {
            return true;
        }
    }
    return false;
}

/// Upcast a value to a parent type in the class hierarchy with compile time guaranteed success.
///
/// Expects pointer types, e.g `*Node` or `*MyClass`, not `Node` or `MyClass`.
///
/// Supports optional pointers when both arguments are optional pointer types.
pub inline fn upcast(comptime T: type, value: anytype) blk: {
    const U = @TypeOf(value);

    if (!isClassPtr(T)) {
        @compileError("upcast expects a class pointer type as the target type, found '" ++ @typeName(T) ++ "'");
    }
    if (!isClassPtr(U)) {
        @compileError("upcast expects a class pointer type as the source value, found '" ++ @typeName(U) ++ "'");
    }
    if (@typeInfo(T) == .optional and @typeInfo(U) != .optional or @typeInfo(T) != .optional and @typeInfo(U) == .optional) {
        @compileError("upcast expects that if one argument is an optional pointer, the other is an optional pointer. found '" ++ @typeName(T) ++ "' and '" ++ @typeName(U) ++ "'");
    }

    assertIs(Child(T), Child(U));

    break :blk T;
} {
    const U = @TypeOf(value);

    if (@typeInfo(U) == .optional and value == null) {
        return null;
    }

    var opaque_ptr: *anyopaque = @ptrCast(value);

    // Walk up the inheritance hierarchy from child to parent
    inline for (selfAndAncestorsOf(Child(U))) |CurrentType| {
        // Found our target type - return the properly typed pointer
        if (comptime CurrentType == Child(T)) {
            return @ptrCast(@alignCast(opaque_ptr));
        }

        // Move to the next level up in the hierarchy
        opaque_ptr = switch (@typeInfo(CurrentType)) {
            .@"struct" => @ptrCast(@field(@as(*CurrentType, @ptrCast(@alignCast(opaque_ptr))), "base")),
            .@"opaque" => @ptrCast(opaque_ptr),
            else => unreachable,
        };
    }

    unreachable;
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

    assertIs(Child(U), Child(T));

    break :blk ?*Child(T);
} {
    const U = @TypeOf(value);

    if (@typeInfo(U) == .optional and value == null) {
        return null;
    }

    const name = getNamePtr(Child(T));
    const tag = godot.interface.classdbGetClassTag(@ptrCast(name));
    const result = godot.interface.objectCastTo(@ptrCast(value), tag);

    if (result) |ptr| {
        if (isGodotClassPtr(T)) {
            return @ptrCast(@alignCast(ptr));
        } else {
            const object: *anyopaque = godot.interface.objectGetInstanceBinding(ptr, godot.interface.library, null) orelse return null;
            return @ptrCast(@alignCast(object));
        }
    } else {
        return null;
    }
}

/// Returns true if a type is a reference counted type.
///
/// Expects a class type, e.g. `Node` or `MyClass`, not `*Node` or `*MyClass`.
pub fn isRefCountedType(comptime T: type) bool {
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

/// Recursively dereferences a type to its base; e.g. `Child(?*?*?*T)` returns `T`.
pub fn Child(comptime T: type) type {
    return switch (@typeInfo(T)) {
        .optional => |info| Child(info.child),
        .pointer => |info| Child(info.child),
        else => T,
    };
}

pub fn getTypeShortName(comptime T: type) [:0]const u8 {
    const full = @typeName(T);
    const pos = std.mem.lastIndexOfScalar(u8, full, '.') orelse return full;
    return full[pos + 1 ..];
}

pub fn getNamePtr(comptime T: type) *StringName {
    const Static = struct {
        comptime {
            _ = T;
        }

        pub var name: StringName = undefined;
    };
    return &Static.name;
}

const tests = struct {
    const testing = std.testing;
    const Node = godot.class.Node;
    const Node3D = godot.class.Node3D;
    const Resource = godot.class.Resource;

    test "BaseOf" {
        try testing.expectEqual(Object, BaseOf(Node));
        try testing.expectEqual(Node, BaseOf(Node3D));

        try testing.expectEqual(Object, BaseOf(RefCounted));
        try testing.expectEqual(RefCounted, BaseOf(Resource));
    }

    test "depthOf" {
        try testing.expectEqual(0, depthOf(Object));
        try testing.expectEqual(1, depthOf(Node));
        try testing.expectEqual(2, depthOf(Node3D));
        try testing.expectEqual(1, depthOf(RefCounted));
        try testing.expectEqual(2, depthOf(Resource));
    }

    test "ancestorsOf" {
        comptime try testing.expectEqualSlices(type, &.{}, &ancestorsOf(Object));
        comptime try testing.expectEqualSlices(type, &.{Object}, &ancestorsOf(Node));
        comptime try testing.expectEqualSlices(type, &.{Object}, &ancestorsOf(RefCounted));
        comptime try testing.expectEqualSlices(type, &.{ Node, Object }, &ancestorsOf(Node3D));
        comptime try testing.expectEqualSlices(type, &.{ RefCounted, Object }, &ancestorsOf(Resource));
    }

    test "selfAndAncestorsOf" {
        comptime try testing.expectEqualSlices(type, &.{Object}, &selfAndAncestorsOf(Object));
        comptime try testing.expectEqualSlices(type, &.{ Node, Object }, &selfAndAncestorsOf(Node));
        comptime try testing.expectEqualSlices(type, &.{ RefCounted, Object }, &selfAndAncestorsOf(RefCounted));
        comptime try testing.expectEqualSlices(type, &.{ Node3D, Node, Object }, &selfAndAncestorsOf(Node3D));
        comptime try testing.expectEqualSlices(type, &.{ Resource, RefCounted, Object }, &selfAndAncestorsOf(Resource));
    }

    test "isA" {
        try testing.expect(comptime isA(Object, Object));
        try testing.expect(comptime isA(Node, Node));
        try testing.expect(comptime isA(RefCounted, RefCounted));
        try testing.expect(comptime isA(Node3D, Node3D));
        try testing.expect(comptime isA(Resource, Resource));

        try testing.expect(comptime isA(Object, Node));
        try testing.expect(comptime isA(Object, RefCounted));
        try testing.expect(comptime isA(Node, Node3D));
        try testing.expect(comptime isA(RefCounted, Resource));

        try testing.expect(comptime isA(Object, Node));
        try testing.expect(comptime isA(Object, RefCounted));
        try testing.expect(comptime isA(Object, Node3D));
        try testing.expect(comptime isA(Object, Resource));

        try testing.expect(comptime !isA(RefCounted, Node));
        try testing.expect(comptime !isA(RefCounted, Node3D));
        try testing.expect(comptime !isA(Node, RefCounted));
        try testing.expect(comptime !isA(Node, Resource));
        try testing.expect(comptime !isA(Node3D, RefCounted));
        try testing.expect(comptime !isA(Node3D, Resource));

        try testing.expect(comptime isA(Object, *Node));
        try testing.expect(comptime isA(Object, *const Node));

        try testing.expect(comptime isA(Object, ?*Node));
        try testing.expect(comptime isA(Object, ?*const Node));

        try testing.expect(comptime isA(Object, *RefCounted));
        try testing.expect(comptime isA(Object, *const RefCounted));

        try testing.expect(comptime isA(Object, ?*RefCounted));
        try testing.expect(comptime isA(Object, ?*const RefCounted));

        try testing.expect(comptime isA(Node, *Node3D));
        try testing.expect(comptime isA(Node, *const Node3D));

        try testing.expect(comptime isA(Node, ?*Node3D));
        try testing.expect(comptime isA(Node, ?*const Node3D));

        try testing.expect(comptime isA(RefCounted, *Resource));
        try testing.expect(comptime isA(RefCounted, *const Resource));

        try testing.expect(comptime isA(RefCounted, ?*Resource));
        try testing.expect(comptime isA(RefCounted, ?*const Resource));
    }

    test "isAny" {
        try testing.expect(isAny(.{ Node, RefCounted }, Node));
        try testing.expect(isAny(.{ Node, RefCounted }, RefCounted));
        try testing.expect(isAny(.{ Node, RefCounted }, Node3D));
        try testing.expect(isAny(.{ Node, RefCounted }, Resource));

        try testing.expect(!isAny(.{ Node3D, Node }, Resource));
    }

    test "upcast" {
        const object: *Object = @ptrFromInt(0xAAAAAAAAAAAAAAAA);
        const node: *Node = @ptrFromInt(0xAAAAAAAAAAAAAAAA);
        const node3D: *Node3D = @ptrFromInt(0xAAAAAAAAAAAAAAAA);
        const ref_counted: *RefCounted = @ptrFromInt(0xAAAAAAAAAAAAAAAA);
        const resource: *Resource = @ptrFromInt(0xAAAAAAAAAAAAAAAA);

        try testing.expectEqual(object, upcast(Object, object));
        try testing.expectEqual(object, upcast(Object, node));
        try testing.expectEqual(object, upcast(Object, node3D));
        try testing.expectEqual(object, upcast(Object, ref_counted));
        try testing.expectEqual(object, upcast(Object, resource));

        try testing.expectEqual(node, upcast(Node, node));
        try testing.expectEqual(node, upcast(Node, node3D));

        try testing.expectEqual(ref_counted, upcast(RefCounted, ref_counted));
        try testing.expectEqual(ref_counted, upcast(RefCounted, resource));

        try testing.expectEqual(node3D, upcast(Node3D, node3D));

        try testing.expectEqual(resource, upcast(Resource, resource));
    }
};

comptime {
    _ = tests;
}
