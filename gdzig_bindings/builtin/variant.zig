pub const ObjectId = enum(u64) { _ };

pub const Variant = extern struct {
    comptime {
        const expected = if (std.mem.eql(u8, precision, "double")) 40 else 24;
        const actual = @sizeOf(Variant);
        if (expected != actual) {
            const message = std.fmt.comptimePrint("Expected Variant to be {d} bytes, but it is {d}", .{ expected, actual });
            @compileError(message);
        }
    }

    pub const nil: Variant = .{ .tag = .nil, .data = .{ .nil = {} } };

    tag: Tag align(8),
    data: Data align(8),

    pub fn init(value: anytype) Variant {
        const T = @TypeOf(value);

        const tag = comptime Tag.forType(T);
        const variantFromType = getVariantFromTypeConstructor(tag);

        var result: Variant = undefined;
        if (tag == .object) {
            variantFromType(@ptrCast(&result), @ptrCast(@constCast(&oopz.upcast(*Object, value))));
        } else if (@typeInfo(T) == .pointer) {
            variantFromType(@ptrCast(&result), @ptrCast(@constCast(value)));
        } else {
            variantFromType(@ptrCast(&result), @ptrCast(@constCast(&value)));
        }

        return result;
    }

    pub fn deinit(self: Variant) void {
        // TODO: what happens when you deinit an extension class contained in a Variant?
        raw.variantDestroy(@ptrCast(@constCast(&self)));
    }

    pub fn as(self: Variant, comptime T: type) ?T {
        const tag = comptime Tag.forType(T);

        if (tag != self.tag) {
            return null;
        }

        const variantToType = getVariantToTypeConstructor(tag);

        if (tag != .object) {
            var result: T = undefined;
            variantToType(@ptrCast(&result), @ptrCast(@constCast(&self)));
            return result;
        } else {
            var object: ?*Object = null;
            variantToType(@ptrCast(&object), @ptrCast(@constCast(&self)));
            if (oopz.isOpaqueClassPtr(T)) {
                return @ptrCast(@alignCast(object));
            } else {
                const instance: *anyopaque = raw.objectGetInstanceBinding(object, raw.library, null) orelse return null;
                return @ptrCast(@alignCast(instance));
            }
        }
    }

    pub const Tag = enum(u32) {
        aabb = 16,
        array = 28,
        basis = 17,
        bool = 1,
        callable = 25,
        color = 20,
        dictionary = 27,
        float = 3,
        int = 2,
        nil = 0,
        node_path = 22,
        object = 24,
        packed_byte_array = 29,
        packed_color_array = 37,
        packed_float32_array = 32,
        packed_float64_array = 33,
        packed_int32_array = 30,
        packed_int64_array = 31,
        packed_string_array = 34,
        packed_vector2_array = 35,
        packed_vector3_array = 36,
        plane = 14,
        projection = 19,
        quaternion = 15,
        rect2 = 7,
        rect2i = 8,
        rid = 23,
        signal = 26,
        string = 4,
        string_name = 21,
        transform2d = 11,
        transform3d = 18,
        vector2 = 5,
        vector2i = 6,
        vector3 = 9,
        vector3i = 10,
        vector4 = 12,
        vector4i = 13,

        pub fn forValue(value: anytype) Tag {
            return forType(@TypeOf(value));
        }

        pub fn forType(comptime T: type) Tag {
            const tag: ?Tag = comptime switch (T) {
                AABB => .aabb,
                Array => .array,
                Basis => .basis,
                bool => .bool,
                Callable => .callable,
                Color => .color,
                Dictionary => .dictionary,
                f64 => .float,
                i64 => .int,
                NodePath => .node_path,
                PackedByteArray => .packed_byte_array,
                PackedColorArray => .packed_color_array,
                PackedFloat32Array => .packed_float32_array,
                PackedFloat64Array => .packed_float64_array,
                PackedInt32Array => .packed_int32_array,
                PackedInt64Array => .packed_int64_array,
                PackedStringArray => .packed_string_array,
                PackedVector2Array => .packed_vector2_array,
                PackedVector3Array => .packed_vector3_array,
                Plane => .plane,
                Projection => .projection,
                Quaternion => .quaternion,
                Rect2 => .rect2,
                Rect2i => .rect2i,
                RID => .rid,
                Signal => .signal,
                String => .string,
                StringName => .string_name,
                Transform2D => .transform2d,
                Transform3D => .transform3d,
                Vector2 => .vector2,
                Vector2i => .vector2i,
                Vector3 => .vector3,
                Vector3i => .vector3i,
                Vector4 => .vector4,
                Vector4i => .vector4i,
                void => .nil,
                inline else => switch (@typeInfo(T)) {
                    .@"enum" => .int,
                    .@"struct" => |info| if (info.backing_integer != null) .int else null,
                    .pointer => |ptr| if (oopz.isClassPtr(T)) .object else forType(ptr.child),
                    else => null,
                },
            };

            return tag orelse @compileError("Cannot construct a 'Variant' from type '" ++ @typeName(T) ++ "'");
        }
    };

    pub const Data = extern union {
        aabb: *AABB,
        array: *Array,
        basis: *Basis,
        bool: bool,
        callable: Callable,
        color: Color,
        dictionary: *Dictionary,
        float: if (mem.eql(u8, precision, "double")) f64 else f32,
        int: i64,
        nil: void,
        node_path: NodePath,
        object: extern struct { id: ObjectId, object: *Object },
        packed_byte_array: extern struct { refs: Atomic(u32), array: *PackedByteArray },
        packed_color_array: extern struct { refs: Atomic(u32), array: *PackedColorArray },
        packed_float32_array: extern struct { refs: Atomic(u32), array: *PackedFloat32Array },
        packed_float64_array: extern struct { refs: Atomic(u32), array: *PackedFloat64Array },
        packed_int32_array: extern struct { refs: Atomic(u32), array: *PackedInt32Array },
        packed_int64_array: extern struct { refs: Atomic(u32), array: *PackedInt64Array },
        packed_string_array: extern struct { refs: Atomic(u32), array: *PackedStringArray },
        packed_vector2_array: extern struct { refs: Atomic(u32), array: *PackedVector2Array },
        packed_vector3_array: extern struct { refs: Atomic(u32), array: *PackedVector3Array },
        plane: Plane,
        projection: *Projection,
        quaternion: Quaternion,
        rect2: Rect2,
        rect2i: Rect2i,
        rid: RID,
        signal: Signal,
        string: String,
        string_name: StringName,
        transform2d: *Transform2D,
        transform3d: *Transform3D,
        vector2: Vector2,
        vector2i: Vector2i,
        vector3: Vector3,
        vector3i: Vector3i,
        vector4: Vector4,
        vector4i: Vector4i,
        // max = 38,
    };

    pub const Operator = enum(u32) {
        equal = 0,
        not_equal = 1,
        less = 2,
        less_equal = 3,
        greater = 4,
        greater_equal = 5,
        add = 6,
        subtract = 7,
        multiply = 8,
        divide = 9,
        negate = 10,
        positive = 11,
        module = 12,
        power = 13,
        shift_left = 14,
        shift_right = 15,
        bit_and = 16,
        bit_or = 17,
        bit_xor = 18,
        bit_negate = 19,
        @"and" = 20,
        @"or" = 21,
        xor = 22,
        not = 23,
        in = 24,
        max = 25,
    };
};

inline fn getVariantFromTypeConstructor(comptime tag: Variant.Tag) Child(c.GDExtensionVariantFromTypeConstructorFunc) {
    const function = &struct {
        var _ = .{tag};
        var function: c.GDExtensionVariantFromTypeConstructorFunc = null;
    }.function;

    if (function.* == null) {
        function.* = raw.getVariantFromTypeConstructor(@intFromEnum(tag));
    }

    return function.*.?;
}

inline fn getVariantToTypeConstructor(comptime tag: Variant.Tag) Child(c.GDExtensionTypeFromVariantConstructorFunc) {
    const function = &struct {
        var _ = .{tag};
        var function: c.GDExtensionTypeFromVariantConstructorFunc = null;
    }.function;

    if (function.* == null) {
        function.* = raw.getVariantToTypeConstructor(@intFromEnum(tag));
    }

    return function.*.?;
}

test "forType" {
    const pairs = .{
        .{ .aabb, AABB },
        .{ .array, Array },
        .{ .basis, Basis },
        .{ .callable, Callable },
        .{ .color, Color },
        .{ .dictionary, Dictionary },
        .{ .node_path, NodePath },
        .{ .object, Object },
        .{ .packed_byte_array, PackedByteArray },
        .{ .packed_color_array, PackedColorArray },
        .{ .packed_float32_array, PackedFloat32Array },
        .{ .packed_float64_array, PackedFloat64Array },
        .{ .packed_int32_array, PackedInt32Array },
        .{ .packed_int64_array, PackedInt64Array },
        .{ .packed_string_array, PackedStringArray },
        .{ .packed_vector2_array, PackedVector2Array },
        .{ .packed_vector3_array, PackedVector3Array },
        .{ .plane, Plane },
        .{ .projection, Projection },
        .{ .quaternion, Quaternion },
        .{ .rid, RID },
        .{ .rect2, Rect2 },
        .{ .rect2i, Rect2i },
        .{ .signal, Signal },
        .{ .string, String },
        .{ .string_name, StringName },
        .{ .transform2d, Transform2D },
        .{ .transform3d, Transform3D },
        .{ .vector2, Vector2 },
        .{ .vector2i, Vector2i },
        .{ .vector3, Vector3 },
        .{ .vector3i, Vector3i },
        .{ .vector4, Vector4 },
        .{ .vector4i, Vector4i },

        .{ .nil, void },
        .{ .bool, bool },
        .{ .int, i32 },
        .{ .int, i64 },
        .{ .int, u32 },
        .{ .int, u64 },
        .{ .float, f32 },
        .{ .float, f64 },
        .{ .int, enum(u32) {} },
    };

    inline for (pairs) |pair| {
        const tag = pair[0];
        const T = pair[1];

        try testing.expectEqual(tag, Variant.Tag.forType(T));
        try testing.expectEqual(tag, Variant.Tag.forType(*T));
        try testing.expectEqual(tag, Variant.Tag.forType(*const T));
        try testing.expectEqual(tag, Variant.Tag.forType(?*T));
        try testing.expectEqual(tag, Variant.Tag.forType(?*const T));
    }
}

const raw = &@import("../gdzig_bindings.zig").raw;

const std = @import("std");
const Atomic = std.atomic.Value;
const Child = std.meta.Child;
const mem = std.mem;
const testing = std.testing;

const c = @import("gdextension");
const oopz = @import("oopz");
const precision = @import("options").precision;

const builtin = @import("../builtin.zig");
const AABB = builtin.AABB;
const Array = builtin.Array;
const Basis = builtin.Basis;
const Callable = builtin.Callable;
const Color = builtin.Color;
const Dictionary = builtin.Dictionary;
const NodePath = builtin.NodePath;
const PackedByteArray = builtin.PackedByteArray;
const PackedColorArray = builtin.PackedColorArray;
const PackedFloat32Array = builtin.PackedFloat32Array;
const PackedFloat64Array = builtin.PackedFloat64Array;
const PackedInt32Array = builtin.PackedInt32Array;
const PackedInt64Array = builtin.PackedInt64Array;
const PackedStringArray = builtin.PackedStringArray;
const PackedVector2Array = builtin.PackedVector2Array;
const PackedVector3Array = builtin.PackedVector3Array;
const Plane = builtin.Plane;
const Projection = builtin.Projection;
const Quaternion = builtin.Quaternion;
const Rect2 = builtin.Rect2;
const Rect2i = builtin.Rect2i;
const RID = builtin.RID;
const Signal = builtin.Signal;
const String = builtin.String;
const StringName = builtin.StringName;
const Transform2D = builtin.Transform2D;
const Transform3D = builtin.Transform3D;
const Vector2 = builtin.Vector2;
const Vector2i = builtin.Vector2i;
const Vector3 = builtin.Vector3;
const Vector3i = builtin.Vector3i;
const Vector4 = builtin.Vector4;
const Vector4i = builtin.Vector4i;
const class = @import("../class.zig");
const Object = class.Object;
