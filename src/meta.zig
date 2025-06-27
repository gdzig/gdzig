/// Returns the base type of T.
pub fn BaseOf(comptime T: type) type {
    if (!@hasField(T, "base")) {
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
    if (depthOf(T) == 0) {
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
    @setEvalBranchQuota(10_000);
    const Dereffed = Deref(U);
    inline for (selfAndAncestorsOf(Dereffed)) |V| {
        if (T == V) {
            return true;
        }
    }
    return false;
}

/// Is U a child of any of the types in types
pub fn isAny(comptime types: anytype, comptime U: type) bool {
    inline for (0..types.len) |i| {
        if (isA(types[i], U)) {
            return true;
        }
    }
    return false;
}

pub fn cast(comptime T: type, value: anytype) ?T {
    const U = if (@TypeOf(value) == type) value else @TypeOf(value);

    if (isA(T, U)) {
        return upcast(T, value);
    } else if (isA(U, T)) {
        return downcast(T, value);
    } else {
        @compileError("cannot cast from '" ++ @typeName(U) ++ "' to " ++ @typeName(T));
    }
}

pub fn upcast(comptime T: type, value: anytype) T {
    assertIs(T, @TypeOf(value));

    const Dereffed = Deref(@TypeOf(value));

    if (Dereffed == T) {
        return value;
    }

    comptime var instances: Tuple(&selfAndAncestorsOf(Dereffed)) = undefined;
    instances[0] = value;
    inline for (1..instances.len) |i| {
        instances[i] = @field(instances[i - 1], "base");
        if (@TypeOf(instances[i]) == T) {
            return instances[i];
        }
    }
}

pub fn downcast(comptime T: type, value: anytype) T {
    _ = value;
    @panic("todo: fieldParentPtr-based casting");
}

pub fn isObject(value: anytype) bool {
    return isA(Object, @TypeOf(value));
}

pub fn asObject(value: anytype) Object {
    return upcast(Object, value);
}

pub fn asObjectPtr(value: anytype) *anyopaque {
    return upcast(Object, value).ptr;
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

const std = @import("std");
const debug = std.debug;
const fmt = std.fmt;
const mem = std.mem;
const Tuple = std.meta.Tuple;

const godot = @import("root.zig");
const assertIs = godot.debug.assertIs;
const Object = godot.core.Object;

const tests = struct {
    const Any = struct {
        pub const init: @This() = .{};
    };
    const Animal = struct {
        base: Any,
        pub const init: @This() = .{ .base = .init };
    };
    const Feline = struct {
        base: Animal,
        pub const init: @This() = .{ .base = .init };
    };
    const Cat = struct {
        base: Feline,
        pub const init: @This() = .{ .base = .init };
    };
    const Lion = struct {
        base: Feline,
        pub const init: @This() = .{ .base = .init };
    };
    const Canine = struct {
        base: Animal,
        pub const init: @This() = .{ .base = .init };
    };
    const Dog = struct {
        base: Canine,
        pub const init: @This() = .{ .base = .init };
    };
    const Wolf = struct {
        base: Canine,
        pub const init: @This() = .{ .base = .init };
    };
    const Vehicle = struct {
        base: Any,
        pub const init: @This() = .{ .base = .init };
    };

    const testing = std.testing;

    test "BaseOf" {
        try testing.expectEqual(Any, BaseOf(Animal));
        try testing.expectEqual(Animal, BaseOf(Feline));
        try testing.expectEqual(Feline, BaseOf(Cat));
        try testing.expectEqual(Feline, BaseOf(Lion));
        try testing.expectEqual(Animal, BaseOf(Canine));
        try testing.expectEqual(Canine, BaseOf(Dog));
        try testing.expectEqual(Canine, BaseOf(Wolf));
        try testing.expectEqual(Any, BaseOf(Vehicle));
    }

    test "depthOf" {
        try testing.expectEqual(0, depthOf(Any));
        try testing.expectEqual(1, depthOf(Animal));
        try testing.expectEqual(1, depthOf(Vehicle));
        try testing.expectEqual(2, depthOf(Canine));
        try testing.expectEqual(2, depthOf(Feline));
        try testing.expectEqual(3, depthOf(Cat));
        try testing.expectEqual(3, depthOf(Dog));
        try testing.expectEqual(3, depthOf(Lion));
        try testing.expectEqual(3, depthOf(Wolf));
    }

    test "ancestorsOf" {
        comptime {
            try testing.expectEqualSlices(type, &.{}, &ancestorsOf(Any));
            try testing.expectEqualSlices(type, &.{Any}, &ancestorsOf(Animal));
            try testing.expectEqualSlices(type, &.{Any}, &ancestorsOf(Vehicle));
            try testing.expectEqualSlices(type, &.{ Animal, Any }, &ancestorsOf(Feline));
            try testing.expectEqualSlices(type, &.{ Animal, Any }, &ancestorsOf(Canine));
            try testing.expectEqualSlices(type, &.{ Feline, Animal, Any }, &ancestorsOf(Cat));
            try testing.expectEqualSlices(type, &.{ Feline, Animal, Any }, &ancestorsOf(Lion));
            try testing.expectEqualSlices(type, &.{ Canine, Animal, Any }, &ancestorsOf(Dog));
            try testing.expectEqualSlices(type, &.{ Canine, Animal, Any }, &ancestorsOf(Wolf));
        }
    }

    test "selfAndAncestorsOf" {
        comptime {
            try testing.expectEqualSlices(type, &.{Any}, &selfAndAncestorsOf(Any));
            try testing.expectEqualSlices(type, &.{ Animal, Any }, &selfAndAncestorsOf(Animal));
            try testing.expectEqualSlices(type, &.{ Vehicle, Any }, &selfAndAncestorsOf(Vehicle));
            try testing.expectEqualSlices(type, &.{ Feline, Animal, Any }, &selfAndAncestorsOf(Feline));
            try testing.expectEqualSlices(type, &.{ Canine, Animal, Any }, &selfAndAncestorsOf(Canine));
            try testing.expectEqualSlices(type, &.{ Cat, Feline, Animal, Any }, &selfAndAncestorsOf(Cat));
            try testing.expectEqualSlices(type, &.{ Lion, Feline, Animal, Any }, &selfAndAncestorsOf(Lion));
            try testing.expectEqualSlices(type, &.{ Dog, Canine, Animal, Any }, &selfAndAncestorsOf(Dog));
            try testing.expectEqualSlices(type, &.{ Wolf, Canine, Animal, Any }, &selfAndAncestorsOf(Wolf));
        }
    }

    test "isA" {
        {
            try testing.expect(isA(Any, Any));
            try testing.expect(isA(Animal, Animal));
            try testing.expect(isA(Vehicle, Vehicle));
            try testing.expect(isA(Feline, Feline));
            try testing.expect(isA(Canine, Canine));
            try testing.expect(isA(Cat, Cat));
            try testing.expect(isA(Lion, Lion));
            try testing.expect(isA(Dog, Dog));
            try testing.expect(isA(Wolf, Wolf));

            try testing.expect(isA(Any, Animal));
            try testing.expect(isA(Any, Vehicle));
            try testing.expect(isA(Animal, Feline));
            try testing.expect(isA(Animal, Canine));
            try testing.expect(isA(Feline, Cat));
            try testing.expect(isA(Feline, Lion));
            try testing.expect(isA(Canine, Dog));
            try testing.expect(isA(Canine, Wolf));

            try testing.expect(isA(Any, Animal));
            try testing.expect(isA(Any, Vehicle));
            try testing.expect(isA(Any, Feline));
            try testing.expect(isA(Any, Canine));
            try testing.expect(isA(Any, Cat));
            try testing.expect(isA(Any, Lion));
            try testing.expect(isA(Any, Dog));
            try testing.expect(isA(Any, Wolf));

            try testing.expect(!isA(Vehicle, Animal));
            try testing.expect(!isA(Vehicle, Feline));
            try testing.expect(!isA(Vehicle, Canine));
            try testing.expect(!isA(Vehicle, Cat));
            try testing.expect(!isA(Vehicle, Lion));
            try testing.expect(!isA(Vehicle, Dog));
            try testing.expect(!isA(Vehicle, Wolf));

            try testing.expect(isA(Any, *Animal));
            try testing.expect(isA(Any, *const Animal));

            try testing.expect(isA(Any, ?Animal));
            try testing.expect(isA(Any, ?*Animal));
            try testing.expect(isA(Any, ?*const Animal));

            try testing.expect(isA(Any, *Vehicle));
            try testing.expect(isA(Any, *const Vehicle));

            try testing.expect(isA(Any, ?Vehicle));
            try testing.expect(isA(Any, ?*Vehicle));
            try testing.expect(isA(Any, ?*const Vehicle));

            try testing.expect(isA(Animal, *Feline));
            try testing.expect(isA(Animal, *const Feline));

            try testing.expect(isA(Animal, ?Feline));
            try testing.expect(isA(Animal, ?*Feline));
            try testing.expect(isA(Animal, ?*const Feline));

            try testing.expect(isA(Animal, *Canine));
            try testing.expect(isA(Animal, *const Canine));

            try testing.expect(isA(Animal, ?Canine));
            try testing.expect(isA(Animal, ?*Canine));
            try testing.expect(isA(Animal, ?*const Canine));

            try testing.expect(isA(Feline, *Cat));
            try testing.expect(isA(Feline, *const Cat));

            try testing.expect(isA(Feline, ?Cat));
            try testing.expect(isA(Feline, ?*Cat));
            try testing.expect(isA(Feline, ?*const Cat));

            try testing.expect(isA(Feline, *Lion));
            try testing.expect(isA(Feline, *const Lion));

            try testing.expect(isA(Feline, ?Lion));
            try testing.expect(isA(Feline, ?*Lion));
            try testing.expect(isA(Feline, ?*const Lion));

            try testing.expect(isA(Canine, *Dog));
            try testing.expect(isA(Canine, *const Dog));

            try testing.expect(isA(Canine, ?Dog));
            try testing.expect(isA(Canine, ?*Dog));
            try testing.expect(isA(Canine, ?*const Dog));

            try testing.expect(isA(Canine, *Wolf));
            try testing.expect(isA(Canine, *const Wolf));

            try testing.expect(isA(Canine, ?Wolf));
            try testing.expect(isA(Canine, ?*Wolf));
            try testing.expect(isA(Canine, ?*const Wolf));
        }
    }

    test "isAny" {
        comptime {
            try testing.expect(isAny(.{ Animal, Vehicle }, Animal));
            try testing.expect(isAny(.{ Animal, Vehicle }, Vehicle));
            try testing.expect(isAny(.{ Animal, Vehicle }, Feline));
            try testing.expect(isAny(.{ Animal, Vehicle }, Canine));
            try testing.expect(isAny(.{ Animal, Vehicle }, Cat));
            try testing.expect(isAny(.{ Animal, Vehicle }, Lion));
            try testing.expect(isAny(.{ Animal, Vehicle }, Dog));
            try testing.expect(isAny(.{ Animal, Vehicle }, Wolf));

            try testing.expect(!isAny(.{ Feline, Vehicle }, Wolf));
        }
    }

    test "upcast" {
        try testing.expectEqual(Any.init, upcast(Any, Any.init));
        try testing.expectEqual(Any.init, upcast(Any, Animal.init));
        try testing.expectEqual(Any.init, upcast(Any, Canine.init));
        try testing.expectEqual(Any.init, upcast(Any, Wolf.init));

        try testing.expectEqual(Animal.init, upcast(Animal, Animal.init));
        try testing.expectEqual(Animal.init, upcast(Animal, Canine.init));
        try testing.expectEqual(Animal.init, upcast(Animal, Wolf.init));

        try testing.expectEqual(Canine.init, upcast(Canine, Canine.init));
        try testing.expectEqual(Canine.init, upcast(Canine, Wolf.init));

        try testing.expectEqual(Wolf.init, upcast(Wolf, Wolf.init));
    }
};

comptime {
    _ = tests;
}
