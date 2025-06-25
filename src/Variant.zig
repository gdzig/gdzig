const std = @import("std");

const godot = @import("root.zig");

const Variant = @This();

const precision = @import("build_options").precision;
const size = if (std.mem.eql(u8, precision, "double")) 40 else 24;

value: [size]u8,

const Type = c_int;
const TYPE_NIL: c_int = 0;
const TYPE_BOOL: c_int = 1;
const TYPE_INT: c_int = 2;
const TYPE_FLOAT: c_int = 3;
const TYPE_STRING: c_int = 4;
const TYPE_VECTOR2: c_int = 5;
const TYPE_VECTOR2I: c_int = 6;
const TYPE_RECT2: c_int = 7;
const TYPE_RECT2I: c_int = 8;
const TYPE_VECTOR3: c_int = 9;
const TYPE_VECTOR3I: c_int = 10;
const TYPE_TRANSFORM2D: c_int = 11;
const TYPE_VECTOR4: c_int = 12;
const TYPE_VECTOR4I: c_int = 13;
const TYPE_PLANE: c_int = 14;
const TYPE_QUATERNION: c_int = 15;
const TYPE_AABB: c_int = 16;
const TYPE_BASIS: c_int = 17;
const TYPE_TRANSFORM3D: c_int = 18;
const TYPE_PROJECTION: c_int = 19;
const TYPE_COLOR: c_int = 20;
const TYPE_STRING_NAME: c_int = 21;
const TYPE_NODE_PATH: c_int = 22;
const TYPE_RID: c_int = 23;
const TYPE_OBJECT: c_int = 24;
const TYPE_CALLABLE: c_int = 25;
const TYPE_SIGNAL: c_int = 26;
const TYPE_DICTIONARY: c_int = 27;
const TYPE_ARRAY: c_int = 28;
const TYPE_PACKED_BYTE_ARRAY: c_int = 29;
const TYPE_PACKED_INT32_ARRAY: c_int = 30;
const TYPE_PACKED_INT64_ARRAY: c_int = 31;
const TYPE_PACKED_FLOAT32_ARRAY: c_int = 32;
const TYPE_PACKED_FLOAT64_ARRAY: c_int = 33;
const TYPE_PACKED_STRING_ARRAY: c_int = 34;
const TYPE_PACKED_VECTOR2_ARRAY: c_int = 35;
const TYPE_PACKED_VECTOR3_ARRAY: c_int = 36;
const TYPE_PACKED_COLOR_ARRAY: c_int = 37;
const TYPE_MAX: c_int = 38;
const Operator = c_int;
const OP_EQUAL: c_int = 0;
const OP_NOT_EQUAL: c_int = 1;
const OP_LESS: c_int = 2;
const OP_LESS_EQUAL: c_int = 3;
const OP_GREATER: c_int = 4;
const OP_GREATER_EQUAL: c_int = 5;
const OP_ADD: c_int = 6;
const OP_SUBTRACT: c_int = 7;
const OP_MULTIPLY: c_int = 8;
const OP_DIVIDE: c_int = 9;
const OP_NEGATE: c_int = 10;
const OP_POSITIVE: c_int = 11;
const OP_MODULE: c_int = 12;
const OP_POWER: c_int = 13;
const OP_SHIFT_LEFT: c_int = 14;
const OP_SHIFT_RIGHT: c_int = 15;
const OP_BIT_AND: c_int = 16;
const OP_BIT_OR: c_int = 17;
const OP_BIT_XOR: c_int = 18;
const OP_BIT_NEGATE: c_int = 19;
const OP_AND: c_int = 20;
const OP_OR: c_int = 21;
const OP_XOR: c_int = 22;
const OP_NOT: c_int = 23;
const OP_IN: c_int = 24;
const OP_MAX: c_int = 25;

var from_type: [@as(usize, godot.c.GDEXTENSION_VARIANT_TYPE_VARIANT_MAX)]godot.c.GDExtensionVariantFromTypeConstructorFunc = undefined;
var to_type: [@as(usize, godot.c.GDEXTENSION_VARIANT_TYPE_VARIANT_MAX)]godot.c.GDExtensionTypeFromVariantConstructorFunc = undefined;

pub fn initBindings() void {
    for (1..TYPE_MAX) |i| {
        from_type[i] = godot.core.getVariantFromTypeConstructor(@intCast(i));
        to_type[i] = godot.core.getVariantToTypeConstructor(@intCast(i));
    }
}

fn getByGodotType(comptime T: type) Type {
    return switch (T) {
        godot.core.AABB => godot.c.GDEXTENSION_VARIANT_TYPE_AABB,
        godot.core.Basis => godot.c.GDEXTENSION_VARIANT_TYPE_BASIS,
        godot.core.Plane => godot.c.GDEXTENSION_VARIANT_TYPE_PLANE,
        godot.core.Projection => godot.c.GDEXTENSION_VARIANT_TYPE_PROJECTION,
        godot.core.Quaternion => godot.c.GDEXTENSION_VARIANT_TYPE_QUATERNION,
        godot.core.Rect2 => godot.c.GDEXTENSION_VARIANT_TYPE_RECT2,
        godot.core.Rect2i => godot.c.GDEXTENSION_VARIANT_TYPE_RECT2I,
        godot.core.String => godot.c.GDEXTENSION_VARIANT_TYPE_STRING,
        godot.core.Transform2D => godot.c.GDEXTENSION_VARIANT_TYPE_TRANSFORM2D,
        godot.core.Transform3D => godot.c.GDEXTENSION_VARIANT_TYPE_TRANSFORM3D,
        godot.Vector2 => godot.c.GDEXTENSION_VARIANT_TYPE_VECTOR2,
        godot.Vector2i => godot.c.GDEXTENSION_VARIANT_TYPE_VECTOR2I,
        godot.Vector3 => godot.c.GDEXTENSION_VARIANT_TYPE_VECTOR3,
        godot.Vector3i => godot.c.GDEXTENSION_VARIANT_TYPE_VECTOR3I,
        godot.Vector4 => godot.c.GDEXTENSION_VARIANT_TYPE_VECTOR4,
        godot.Vector4i => godot.c.GDEXTENSION_VARIANT_TYPE_VECTOR4I,

        godot.core.Array => godot.c.GDEXTENSION_VARIANT_TYPE_ARRAY,
        godot.core.Callable => godot.c.GDEXTENSION_VARIANT_TYPE_CALLABLE,
        godot.core.Color => godot.c.GDEXTENSION_VARIANT_TYPE_COLOR,
        godot.core.Dictionary => godot.c.GDEXTENSION_VARIANT_TYPE_DICTIONARY,
        godot.core.NodePath => godot.c.GDEXTENSION_VARIANT_TYPE_NODE_PATH,
        godot.core.Object => godot.c.GDEXTENSION_VARIANT_TYPE_OBJECT,
        godot.core.RID => godot.c.GDEXTENSION_VARIANT_TYPE_RID,
        godot.core.Signal => godot.c.GDEXTENSION_VARIANT_TYPE_SIGNAL,
        godot.core.StringName => godot.c.GDEXTENSION_VARIANT_TYPE_STRING_NAME,

        godot.core.PackedByteArray => godot.c.GDEXTENSION_VARIANT_TYPE_PACKED_BYTE_ARRAY,
        godot.core.PackedColorArray => godot.c.GDEXTENSION_VARIANT_TYPE_PACKED_COLOR_ARRAY,
        godot.core.PackedFloat32Array => godot.c.GDEXTENSION_VARIANT_TYPE_PACKED_FLOAT32_ARRAY,
        godot.core.PackedFloat64Array => godot.c.GDEXTENSION_VARIANT_TYPE_PACKED_FLOAT64_ARRAY,
        godot.core.PackedInt32Array => godot.c.GDEXTENSION_VARIANT_TYPE_PACKED_INT32_ARRAY,
        godot.core.PackedInt64Array => godot.c.GDEXTENSION_VARIANT_TYPE_PACKED_INT64_ARRAY,
        godot.core.PackedStringArray => godot.c.GDEXTENSION_VARIANT_TYPE_PACKED_STRING_ARRAY,
        godot.core.PackedVector2Array => godot.c.GDEXTENSION_VARIANT_TYPE_PACKED_VECTOR2_ARRAY,
        godot.core.PackedVector3Array => godot.c.GDEXTENSION_VARIANT_TYPE_PACKED_VECTOR3_ARRAY,
        else => godot.c.GDEXTENSION_VARIANT_TYPE_NIL,
    };
}

fn getChildTypeOrSelf(comptime T: type) type {
    const typeInfo = @typeInfo(T);
    return switch (typeInfo) {
        .pointer => |info| info.child,
        .optional => |info| info.child,
        else => T,
    };
}

pub fn getVariantType(comptime T: type) Type {
    const typeInfo = @typeInfo(T);
    if (typeInfo == .pointer and @typeInfo(typeInfo.pointer.child) != .@"struct") {
        @compileError("Init Variant from " ++ @typeName(T) ++ " is not supported");
    }
    const RT = getChildTypeOrSelf(T);

    const ret = comptime getByGodotType(RT);
    if (ret == godot.c.GDEXTENSION_VARIANT_TYPE_NIL) {
        const ret1 = switch (@typeInfo(RT)) {
            .@"struct" => godot.c.GDEXTENSION_VARIANT_TYPE_OBJECT,
            .bool => godot.c.GDEXTENSION_VARIANT_TYPE_BOOL,
            .int, .@"enum", .comptime_int => godot.c.GDEXTENSION_VARIANT_TYPE_INT,
            .float, .comptime_float => godot.c.GDEXTENSION_VARIANT_TYPE_FLOAT,
            .void => godot.c.GDEXTENSION_VARIANT_TYPE_NIL,
            else => @compileError("Cannot construct variant from " ++ @typeName(T)),
        };
        return ret1;
    }
    return ret;
}

pub fn init() Variant {
    var result: Variant = undefined;
    godot.core.variantNewNil(&result);
    return result;
}

pub fn deinit(self: *Variant) void {
    godot.core.variantDestroy(&self.value);
}

pub fn initFrom(from: anytype) Variant {
    if (@TypeOf(from) == Variant) return from;
    const tid = comptime getVariantType(@TypeOf(from));
    var result: Variant = undefined;
    from_type[@intCast(tid)].?(@ptrCast(&result), @ptrCast(@constCast(&from)));
    return result;
}

pub fn as(self_const: Variant, comptime T: type) T {
    // Godot wants a mutable pointer. I don't think it actually needs one, but just to be safe we'll copy.
    var self = self_const;

    const tid = comptime getVariantType(T);
    if (tid == godot.c.GDEXTENSION_VARIANT_TYPE_OBJECT) {
        var obj: ?*anyopaque = null;
        to_type[godot.c.GDEXTENSION_VARIANT_TYPE_OBJECT].?(@ptrCast(&obj), @ptrCast(&self.value));
        const godotObj: *godot.core.Object = @ptrCast(@alignCast(godot.core.objectGetInstanceBinding(obj, godot.core.p_library, null)));
        const RealType = @typeInfo(T).pointer.child;
        if (RealType == godot.core.Object) {
            return godotObj;
        } else {
            const classTag = godot.classdbGetClassTag(@ptrCast(godot.getClassName(RealType)));
            const casted = godot.objectCastTo(godotObj.godot_object, classTag);
            return @ptrCast(@alignCast(godot.objectGetInstanceBinding(casted, godot.core.p_library, null)));
        }
    }

    var result: T = undefined;
    to_type[@intCast(tid)].?(@ptrCast(&result), @ptrCast(@constCast(&self.value)));
    return result;
}
