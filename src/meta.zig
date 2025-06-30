/// Returns the base type of T.
pub fn BaseOf(comptime T: type) type {
    if (comptime !@hasField(T, "base")) {
        const message = fmt.comptimePrint("expected a Godot class, found '{0s}'. did you remember to add the 'base' struct field?", @typeName(T));
        @compileError(message);
    }
    return @FieldType(T, "base");
}

/// Returns how many levels of inheritance T has.
pub fn depthOf(comptime T: type) comptime_int {
    comptime var i = 0;
    comptime var Cur = T;
    inline while (@hasField(Cur, "base")) : (i += 1) {
        Cur = BaseOf(Cur);
    }
    return i;
}

/// Returns the type hierarchy of T as an array of types, in ascending order, starting with the parent of T.
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
pub fn selfAndAncestorsOf(comptime T: type) [1 + depthOf(T)]type {
    return [_]type{T} ++ ancestorsOf(T);
}

/// Is U a child of T
pub fn isA(comptime T: type, comptime U: type) bool {
    const Dereffed = Deref(U);

    if (comptime @typeInfo(Dereffed) != .@"struct") {
        return false;
    }
    if (comptime T == U) {
        return true;
    }

    @setEvalBranchQuota(10_000);
    inline for (selfAndAncestorsOf(Dereffed)) |V| {
        if (comptime T == V) {
            return true;
        }
    }
    return false;
}

/// Is U a child of any of the types in types
pub fn isAny(comptime types: anytype, comptime U: type) bool {
    inline for (0..types.len) |i| {
        if (comptime isA(types[i], U)) {
            return true;
        }
    }
    return false;
}

pub fn cast(comptime T: type, value: anytype) ?T {
    const U = if (@TypeOf(value) == type) value else @TypeOf(value);

    if (comptime isA(T, U)) {
        return upcast(T, value);
    } else if (comptime isA(U, T)) {
        return downcast(T, value);
    } else {
        @compileError("cannot cast from '" ++ @typeName(U) ++ "' to " ++ @typeName(T));
    }
}

pub fn upcast(comptime T: type, value: anytype) T {
    const Dereffed = Deref(@TypeOf(value));
    if (comptime Dereffed == T) {
        return value;
    }
    assertIs(T, Dereffed);

    var instances: Tuple(&selfAndAncestorsOf(Dereffed)) = undefined;
    instances[0] = switch (@typeInfo(@TypeOf(value))) {
        .pointer => value.*,
        else => value,
    };
    inline for (1..instances.len) |i| {
        instances[i] = @field(instances[i - 1], "base");
        if (@TypeOf(instances[i]) == T) {
            return instances[i];
        }
    }
}

pub fn downcast(comptime T: type, value: anytype) !T {
    // Compile time type check (can't cast an Animal to a Motorcycle)
    assertIs(@TypeOf(value), T);

    // Runtime cast
    const name = getNamePtr(T);
    const tag = godot.core.classdbGetClassTag(@ptrCast(name));
    const result = godot.core.objectCastTo(asObjectPtr(value), tag);

    return if (result) |ptr|
        return @bitCast(Object{ .ptr = ptr })
    else
        return error.InvalidCast;
}

pub fn isObject(comptime T: type) bool {
    return isA(Object, T);
}

/// This
pub fn isWrappedPointer(comptime T: type) bool {
    return switch (@typeInfo(T)) {
        .@"struct" => |s| s.fields.len == 1 and @typeInfo(s.fields[0].type) == .pointer,
        else => false,
    };
}

pub fn isRefCounted(comptime T: type) bool {
    return isA(RefCounted, T);
}

pub fn asObject(value: anytype) Object {
    return upcast(Object, value);
}

pub fn asObjectPtr(value: anytype) *anyopaque {
    return upcast(Object, value).ptr;
}

pub fn asRefCounted(value: anytype) RefCounted {
    return upcast(RefCounted, value);
}

pub fn isPathLike(comptime T: type) bool {
    return isAny(.{ godot.core.NodePath, []const u8, [:0]const u8 }, T);
}

pub fn isStringLike(comptime T: type) bool {
    return isAny(.{ godot.core.String, godot.core.StringName, []const u8, [:0]const u8 }, T);
}

pub fn isVariantLike(comptime T: type) bool {
    // TODO: variant types
    return isAny(.{godot.core.Variant}, T);
}

pub fn Deref(comptime T: type) type {
    return switch (@typeInfo(T)) {
        .pointer => |p| Deref(p.child),
        .optional => |p| Deref(p.child),
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

const std = @import("std");
const fmt = std.fmt;
const Tuple = std.meta.Tuple;

const godot = @import("root.zig");
const assertIs = godot.debug.assertIs;
const Object = godot.core.Object;
const RefCounted = godot.core.RefCounted;
const StringName = godot.core.StringName;

const tests = struct {
    const testing = std.testing;
    const Node = godot.core.Node;
    const Node3D = godot.core.Node3D;
    const Resource = godot.core.Resource;

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

        try testing.expect(comptime isA(Object, ?Node));
        try testing.expect(comptime isA(Object, ?*Node));
        try testing.expect(comptime isA(Object, ?*const Node));

        try testing.expect(comptime isA(Object, *RefCounted));
        try testing.expect(comptime isA(Object, *const RefCounted));

        try testing.expect(comptime isA(Object, ?RefCounted));
        try testing.expect(comptime isA(Object, ?*RefCounted));
        try testing.expect(comptime isA(Object, ?*const RefCounted));

        try testing.expect(comptime isA(Node, *Node3D));
        try testing.expect(comptime isA(Node, *const Node3D));

        try testing.expect(comptime isA(Node, ?Node3D));
        try testing.expect(comptime isA(Node, ?*Node3D));
        try testing.expect(comptime isA(Node, ?*const Node3D));

        try testing.expect(comptime isA(RefCounted, *Resource));
        try testing.expect(comptime isA(RefCounted, *const Resource));

        try testing.expect(comptime isA(RefCounted, ?Resource));
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
        const object = Object{ .ptr = @ptrCast(@constCast(&.{})) };
        const node = Node{ .base = object };
        const node3D = Node3D{ .base = node };
        const ref_counted = RefCounted{ .base = object };
        const resource = Resource{ .base = ref_counted };

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
