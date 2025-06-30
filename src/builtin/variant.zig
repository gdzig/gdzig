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
        const constructor = bindVariantFrom(Tag.forType(@TypeOf(value)));
        var result: Variant = undefined;
        constructor(@ptrCast(&result), @ptrCast(@constCast(&value)));
        return result;
    }

    pub fn deinit(self: Variant) void {
        godot.interface.variantDestroy(@ptrCast(@constCast(&self)));
    }

    pub fn as(self: Variant, comptime T: type) T {
        const tag = comptime Tag.forType(T);

        if (tag == .object) {
            var ptr: ?*anyopaque = null;

            const variantTo = bindVariantTo(tag);
            variantTo(@ptrCast(&ptr), @ptrCast(@constCast(&self)));

            // TODO: GDExtensionInstanceBindingCallbacks?
            const instance: *Object = @ptrCast(@alignCast(godot.interface.objectGetInstanceBinding(ptr, godot.interface.library, null)));

            if (std.meta.Child(T) == Object) {
                return instance;
            } else {
                const class_name = godot.getClassName(std.meta.Child(T));
                const class_tag = godot.interface.classdbGetClassTag(@ptrCast(class_name));
                // TODO: this can return null if its not the right type; return type should be optional depending on T, right? or return error?
                const casted = godot.interface.objectCastTo(meta.asObjectPtr(instance), class_tag);
                const binding = godot.interface.objectGetInstanceBinding(casted, godot.interface.library, null);

                return @ptrCast(@alignCast(binding));
            }
        } else {
            var result: T = undefined;
            const variantTo = bindVariantTo(tag);
            variantTo(@ptrCast(&result), @ptrCast(@constCast(&self)));
            return result;
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

        pub fn forValue(value: anytype) Variant.Tag {
            return forType(@TypeOf(value));
        }

        pub fn forType(comptime T: type) Variant.Tag {
            return switch (meta.Deref(T)) {
                AABB => .aabb,
                Array => .array,
                Basis => .basis,
                Callable => .callable,
                Color => .color,
                Dictionary => .dictionary,
                NodePath => .node_path,
                Object => .object,
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
                RID => .rid,
                Rect2 => .rect2,
                Rect2i => .rect2i,
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
                inline else => |U| switch (@typeInfo(U)) {
                    .void => .nil,
                    .bool => .bool,
                    .int, .@"enum", .comptime_int => .int,
                    .float, .comptime_float => .float,
                    .@"struct" => |i| if (i.backing_integer != null) .int else .object,
                    else => @compileError("Cannot construct variant from " ++ @typeName(T)),
                },
            };
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

const std = @import("std");
const Atomic = std.atomic.Value;
const mem = std.mem;

const precision = @import("build_options").precision;

const godot = @import("../gdzig.zig");
const AABB = godot.builtin.AABB;
const Array = godot.builtin.Array;
const Basis = godot.builtin.Basis;
const bindVariantFrom = godot.support.bindVariantFrom;
const bindVariantTo = godot.support.bindVariantTo;
const Callable = godot.builtin.Callable;
const Color = godot.builtin.Color;
const Dictionary = godot.builtin.Dictionary;
const meta = godot.meta;
const NodePath = godot.builtin.NodePath;
const Object = godot.class.Object;
const PackedByteArray = godot.builtin.PackedByteArray;
const PackedColorArray = godot.builtin.PackedColorArray;
const PackedFloat32Array = godot.builtin.PackedFloat32Array;
const PackedFloat64Array = godot.builtin.PackedFloat64Array;
const PackedInt32Array = godot.builtin.PackedInt32Array;
const PackedInt64Array = godot.builtin.PackedInt64Array;
const PackedStringArray = godot.builtin.PackedStringArray;
const PackedVector2Array = godot.builtin.PackedVector2Array;
const PackedVector3Array = godot.builtin.PackedVector3Array;
const Plane = godot.builtin.Plane;
const Projection = godot.builtin.Projection;
const Quaternion = godot.builtin.Quaternion;
const Rect2 = godot.builtin.Rect2;
const Rect2i = godot.builtin.Rect2i;
const RID = godot.builtin.RID;
const Signal = godot.builtin.Signal;
const String = godot.builtin.String;
const StringName = godot.builtin.StringName;
const Transform2D = godot.builtin.Transform2D;
const Transform3D = godot.builtin.Transform3D;
const Vector2 = godot.builtin.Vector2;
const Vector2i = godot.builtin.Vector2i;
const Vector3 = godot.builtin.Vector3;
const Vector3i = godot.builtin.Vector3i;
const Vector4 = godot.builtin.Vector4;
const Vector4i = godot.builtin.Vector4i;

const tests = struct {
    const Tag = Variant.Tag;
    const testing = std.testing;

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
            .{ .int, godot.global.JoyAxis },
            .{ .int, godot.global.KeyModifierMask },
        };

        inline for (pairs) |pair| {
            const tag = pair[0];
            const T = pair[1];

            try testing.expectEqual(tag, Tag.forType(T));
            try testing.expectEqual(tag, Tag.forType(*T));
            try testing.expectEqual(tag, Tag.forType(*const T));
            try testing.expectEqual(tag, Tag.forType(?T));
            try testing.expectEqual(tag, Tag.forType(?*T));
            try testing.expectEqual(tag, Tag.forType(?*const T));
        }
    }
};

comptime {
    _ = tests;
}
