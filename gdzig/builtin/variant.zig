const logger = std.log.scoped(.variant);

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

    pub fn init(comptime T: type, value: T) Variant {
        const tag = comptime Tag.forType(T);

        if (tag == .object) {
            // For RefCounted objects, manually construct the Variant and call reference()
            // to share ownership. We bypass variantFromType because it uses init_ref()
            // which only works correctly for first-time ownership transfer.
            if (comptime class.isRefCountedPtr(T)) {
                _ = RefCounted.upcast(value).reference();
            }
            const obj = Object.upcast(value);
            return .{
                .tag = .object,
                .data = .{
                    .object = .{
                        .id = @enumFromInt(obj.getInstanceId()),
                        .object = obj,
                    },
                },
            };
        }

        const variantFromType = getVariantFromTypeConstructor(tag);
        var result: Variant = undefined;
        switch (@typeInfo(T)) {
            .pointer => variantFromType(@ptrCast(&result), @ptrCast(@constCast(value))),
            else => {
                var v: T = value;
                variantFromType(@ptrCast(&result), @ptrCast(&v));
            },
        }

        return result;
    }

    pub fn deinit(self: Variant) void {
        raw.variantDestroy(@ptrCast(@constCast(&self)));
    }

    fn isCompatibleCast(self: Variant, tag: Tag) bool {
        return switch (tag) {
            .string, .string_name => self.tag == .string_name or self.tag == .string,
            else => self.tag == tag,
        };
    }

    pub fn as(self: Variant, comptime T: type) ?T {
        const tag = comptime Tag.forType(T);

        if (!self.isCompatibleCast(tag)) {
            logger.warn(
                \\Can't cast Variant from {s} to {s}.
            , .{ @tagName(tag), @tagName(self.tag) });
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
            if (object == null) return null;
            if (class.isOpaqueClassPtr(T)) {
                return @ptrCast(@alignCast(object));
            } else {
                const Base = class.BaseOf(Child(T));
                const base: *Base = @ptrCast(object);
                return base.asInstance(Child(T));
            }
        }
    }

    pub fn ptr(self: *Variant) *anyopaque {
        return @ptrCast(&self);
    }

    pub fn constPtr(self: Variant) *const anyopaque {
        return @ptrCast(&self);
    }

    /// Creates a copy of this Variant.
    pub fn clone(self: Variant) Variant {
        var result: Variant = undefined;
        raw.variantNewCopy(@ptrCast(&result), @ptrCast(&self));
        return result;
    }

    /// Calls a method on this Variant.
    pub fn call(self: *Variant, method: StringName, args: []const *const Variant) CallError!Variant {
        var ret: Variant = undefined;
        var err: CallResult = undefined;
        raw.variantCall(@ptrCast(&self), @ptrCast(&method), @ptrCast(args.ptr), @intCast(args.len), @ptrCast(&ret), @ptrCast(&err));
        try err.throw();
        return ret;
    }

    /// Calls a static method on a Variant type.
    pub fn callStatic(variant_tag: Tag, method: StringName, args: []const *const Variant) CallError!Variant {
        var ret: Variant = undefined;
        var err: CallResult = undefined;
        raw.variantCallStatic(@intFromEnum(variant_tag), @ptrCast(&method), @ptrCast(args.ptr), @intCast(args.len), @ptrCast(&ret), @ptrCast(&err));
        try err.throw();
        return ret;
    }

    /// Evaluates an operator on two Variants.
    inline fn evaluate(a: Variant, op: Operator, b: Variant) PropertyError!Variant {
        var result: Variant = undefined;
        var valid: u8 = 0;
        raw.variantEvaluate(@intFromEnum(op), @ptrCast(&a), @ptrCast(&b), @ptrCast(&result), &valid);
        if (valid == 0) return error.InvalidOperation;
        return result;
    }

    /// Returns true if this Variant equals another.
    pub fn eql(self: Variant, other: Variant) bool {
        const result = evaluate(self, .equal, other) catch return false;
        defer result.deinit();
        return result.booleanize();
    }

    /// Returns true if this Variant does not equal another.
    pub fn notEql(self: Variant, other: Variant) bool {
        const result = evaluate(self, .not_equal, other) catch return false;
        defer result.deinit();
        return result.booleanize();
    }

    /// Returns true if this Variant is less than another.
    pub fn lessThan(self: Variant, other: Variant) bool {
        const result = evaluate(self, .less, other) catch return false;
        defer result.deinit();
        return result.booleanize();
    }

    /// Returns true if this Variant is less than or equal to another.
    pub fn lessThanOrEql(self: Variant, other: Variant) bool {
        const result = evaluate(self, .less_equal, other) catch return false;
        defer result.deinit();
        return result.booleanize();
    }

    /// Returns true if this Variant is greater than another.
    pub fn greaterThan(self: Variant, other: Variant) bool {
        const result = evaluate(self, .greater, other) catch return false;
        defer result.deinit();
        return result.booleanize();
    }

    /// Returns true if this Variant is greater than or equal to another.
    pub fn greaterThanOrEql(self: Variant, other: Variant) bool {
        const result = evaluate(self, .greater_equal, other) catch return false;
        defer result.deinit();
        return result.booleanize();
    }

    /// Adds two Variants.
    pub fn add(self: Variant, other: Variant) PropertyError!Variant {
        return evaluate(self, .add, other);
    }

    /// Subtracts another Variant from this one.
    pub fn sub(self: Variant, other: Variant) PropertyError!Variant {
        return evaluate(self, .subtract, other);
    }

    /// Multiplies two Variants.
    pub fn mul(self: Variant, other: Variant) PropertyError!Variant {
        return evaluate(self, .multiply, other);
    }

    /// Divides this Variant by another.
    pub fn div(self: Variant, other: Variant) PropertyError!Variant {
        return evaluate(self, .divide, other);
    }

    /// Returns the remainder of dividing this Variant by another.
    pub fn mod(self: Variant, other: Variant) PropertyError!Variant {
        return evaluate(self, .module, other);
    }

    /// Returns this Variant raised to the power of another.
    pub fn pow(self: Variant, other: Variant) PropertyError!Variant {
        return evaluate(self, .power, other);
    }

    /// Negates this Variant.
    pub fn neg(self: Variant) PropertyError!Variant {
        return evaluate(self, .negate, Variant.nil);
    }

    /// Returns the positive of this Variant (usually a no-op).
    pub fn pos(self: Variant) PropertyError!Variant {
        return evaluate(self, .positive, Variant.nil);
    }

    /// Shifts this Variant left by the amount in another.
    pub fn shiftLeft(self: Variant, other: Variant) PropertyError!Variant {
        return evaluate(self, .shift_left, other);
    }

    /// Shifts this Variant right by the amount in another.
    pub fn shiftRight(self: Variant, other: Variant) PropertyError!Variant {
        return evaluate(self, .shift_right, other);
    }

    /// Bitwise AND of two Variants.
    pub fn bitAnd(self: Variant, other: Variant) PropertyError!Variant {
        return evaluate(self, .bit_and, other);
    }

    /// Bitwise OR of two Variants.
    pub fn bitOr(self: Variant, other: Variant) PropertyError!Variant {
        return evaluate(self, .bit_or, other);
    }

    /// Bitwise XOR of two Variants.
    pub fn bitXor(self: Variant, other: Variant) PropertyError!Variant {
        return evaluate(self, .bit_xor, other);
    }

    /// Bitwise negation of this Variant.
    pub fn bitNot(self: Variant) PropertyError!Variant {
        return evaluate(self, .bit_negate, Variant.nil);
    }

    /// Logical AND of two Variants.
    pub fn logicalAnd(self: Variant, other: Variant) PropertyError!Variant {
        return evaluate(self, .@"and", other);
    }

    /// Logical OR of two Variants.
    pub fn logicalOr(self: Variant, other: Variant) PropertyError!Variant {
        return evaluate(self, .@"or", other);
    }

    /// Logical XOR of two Variants.
    pub fn logicalXor(self: Variant, other: Variant) PropertyError!Variant {
        return evaluate(self, .xor, other);
    }

    /// Logical NOT of this Variant.
    pub fn logicalNot(self: Variant) PropertyError!Variant {
        return evaluate(self, .not, Variant.nil);
    }

    /// Returns true if this Variant is contained in another.
    pub fn in(self: Variant, other: Variant) bool {
        const result = evaluate(self, .in, other) catch return false;
        defer result.deinit();
        return result.booleanize();
    }

    /// Gets the value of a key from this Variant.
    pub fn get(self: Variant, key: Variant) PropertyError!Variant {
        var result: Variant = undefined;
        var valid: u8 = 0;
        raw.variantGet(@ptrCast(&self), @ptrCast(&key), @ptrCast(&result), &valid);
        if (valid == 0) return error.InvalidKey;
        return result;
    }

    /// Sets a key on this Variant to a value.
    pub fn set(self: *Variant, key: Variant, value: Variant) PropertyError!void {
        var valid: u8 = 0;
        raw.variantSet(@ptrCast(&self), @ptrCast(&key), @ptrCast(&value), &valid);
        if (valid == 0) return error.InvalidKey;
    }

    /// Gets the value of a named property from this Variant.
    pub fn getNamed(self: Variant, key: StringName) ?Variant {
        var result: Variant = undefined;
        var valid: u8 = 0;
        raw.variantGetNamed(@ptrCast(&self), @ptrCast(&key), @ptrCast(&result), &valid);
        if (valid == 0) return null;
        return result;
    }

    /// Sets a named property on this Variant to a value.
    pub fn setNamed(self: *Variant, key: StringName, value: Variant) PropertyError!void {
        var valid: u8 = 0;
        raw.variantSetNamed(@ptrCast(&self), @ptrCast(&key), @ptrCast(&value), &valid);
        if (valid == 0) return error.InvalidKey;
    }

    /// Gets the value of a keyed property from this Variant.
    pub fn getKeyed(self: Variant, key: Variant) ?Variant {
        var result: Variant = undefined;
        var valid: c.GDExtensionBool = 0;
        raw.variantGetKeyed(@ptrCast(&self), @ptrCast(&key), @ptrCast(&result), &valid);
        if (valid == 0) return null;
        return result;
    }

    /// Sets a keyed property on this Variant to a value.
    pub fn setKeyed(self: *Variant, key: Variant, value: Variant) PropertyError!void {
        var valid: u8 = 0;
        raw.variantSetKeyed(@ptrCast(&self), @ptrCast(&key), @ptrCast(&value), &valid);
        if (valid == 0) return error.InvalidKey;
    }

    /// Gets the value at an index from this Variant.
    pub fn getIndexed(self: Variant, index: i64) PropertyError!Variant {
        var result: Variant = undefined;
        var valid: u8 = 0;
        var oob: u8 = 0;
        raw.variantGetIndexed(@ptrCast(&self), index, @ptrCast(&result), &valid, &oob);
        if (valid == 0) return error.InvalidOperation;
        if (oob != 0) return error.IndexOutOfBounds;
        return result;
    }

    /// Sets the value at an index on this Variant.
    pub fn setIndexed(self: *Variant, index: i64, value: Variant) PropertyError!void {
        var valid: u8 = 0;
        var oob: u8 = 0;
        raw.variantSetIndexed(@ptrCast(&self), index, @ptrCast(&value), &valid, &oob);
        if (valid == 0) return error.InvalidOperation;
        if (oob != 0) return error.IndexOutOfBounds;
    }

    /// Checks if this Variant has the given method.
    pub fn hasMethod(self: Variant, method: StringName) bool {
        return raw.variantHasMethod(@ptrCast(&self), @ptrCast(&method)) != 0;
    }

    /// Checks if this Variant has a key.
    pub fn hasKey(self: Variant, key: Variant) PropertyError!bool {
        var valid: u8 = 0;
        const result = raw.variantHasKey(@ptrCast(&self), @ptrCast(&key), &valid);
        if (valid == 0) return error.InvalidOperation;
        return result != 0;
    }

    /// Gets the hash of this Variant.
    pub fn hash(self: Variant) i64 {
        return raw.variantHash(@ptrCast(&self));
    }

    /// Compares this Variant to another by hash.
    pub fn hashCompare(self: Variant, other: Variant) bool {
        return raw.variantHashCompare(@ptrCast(&self), @ptrCast(&other)) != 0;
    }

    /// Gets the recursive hash of this Variant.
    pub fn recursiveHash(self: Variant, recursion_count: i64) i64 {
        return raw.variantRecursiveHash(@ptrCast(&self), recursion_count);
    }

    /// Gets the object instance ID from this Variant (if it contains an Object).
    pub fn getObjectInstanceId(self: Variant) ObjectId {
        return @enumFromInt(raw.variantGetObjectInstanceId(@ptrCast(&self)));
    }

    /// Converts this Variant to a boolean.
    pub fn booleanize(self: Variant) bool {
        return raw.variantBooleanize(@ptrCast(&self)) != 0;
    }

    /// Duplicates this Variant.
    pub fn duplicate(self: Variant, deep: bool) Variant {
        var result: Variant = undefined;
        raw.variantDuplicate(@ptrCast(&self), @ptrCast(&result), @intFromBool(deep));
        return result;
    }

    /// Converts this Variant to a String.
    pub fn stringify(self: Variant) String {
        var result: String = undefined;
        raw.variantStringify(@ptrCast(&self), result.ptr());
        return result;
    }

    /// Initializes an iterator over this Variant.
    pub fn iterInit(self: Variant) PropertyError!Variant {
        var iter: Variant = undefined;
        var valid: u8 = 0;
        const has_next = raw.variantIterInit(@ptrCast(&self), @ptrCast(&iter), &valid);
        if (valid == 0) return error.InvalidOperation;
        // If has_next is false, return nil to indicate empty iteration
        if (has_next == 0) return Variant.nil;
        return iter;
    }

    /// Gets the next value for an iterator over this Variant.
    /// Returns true if there are more elements, false if iteration is complete.
    pub fn iterNext(self: Variant, iter: *Variant) PropertyError!bool {
        var valid: u8 = 0;
        const result = raw.variantIterNext(@ptrCast(&self), @ptrCast(iter), &valid);
        if (valid == 0) return error.InvalidOperation;
        return result != 0;
    }

    /// Gets the current value at the iterator position.
    pub fn iterGet(self: Variant, iter: *Variant) PropertyError!Variant {
        var result: Variant = undefined;
        var valid: u8 = 0;
        raw.variantIterGet(@ptrCast(&self), @ptrCast(iter), @ptrCast(&result), &valid);
        if (valid == 0) return error.InvalidOperation;
        return result;
    }

    pub const Tag = enum(u32) {
        nil = c.GDEXTENSION_VARIANT_TYPE_NIL,
        bool = c.GDEXTENSION_VARIANT_TYPE_BOOL,
        int = c.GDEXTENSION_VARIANT_TYPE_INT,
        float = c.GDEXTENSION_VARIANT_TYPE_FLOAT,
        string = c.GDEXTENSION_VARIANT_TYPE_STRING,
        vector2 = c.GDEXTENSION_VARIANT_TYPE_VECTOR2,
        vector2i = c.GDEXTENSION_VARIANT_TYPE_VECTOR2I,
        rect2 = c.GDEXTENSION_VARIANT_TYPE_RECT2,
        rect2i = c.GDEXTENSION_VARIANT_TYPE_RECT2I,
        vector3 = c.GDEXTENSION_VARIANT_TYPE_VECTOR3,
        vector3i = c.GDEXTENSION_VARIANT_TYPE_VECTOR3I,
        transform2d = c.GDEXTENSION_VARIANT_TYPE_TRANSFORM2D,
        vector4 = c.GDEXTENSION_VARIANT_TYPE_VECTOR4,
        vector4i = c.GDEXTENSION_VARIANT_TYPE_VECTOR4I,
        plane = c.GDEXTENSION_VARIANT_TYPE_PLANE,
        quaternion = c.GDEXTENSION_VARIANT_TYPE_QUATERNION,
        aabb = c.GDEXTENSION_VARIANT_TYPE_AABB,
        basis = c.GDEXTENSION_VARIANT_TYPE_BASIS,
        transform3d = c.GDEXTENSION_VARIANT_TYPE_TRANSFORM3D,
        projection = c.GDEXTENSION_VARIANT_TYPE_PROJECTION,
        color = c.GDEXTENSION_VARIANT_TYPE_COLOR,
        string_name = c.GDEXTENSION_VARIANT_TYPE_STRING_NAME,
        node_path = c.GDEXTENSION_VARIANT_TYPE_NODE_PATH,
        rid = c.GDEXTENSION_VARIANT_TYPE_RID,
        object = c.GDEXTENSION_VARIANT_TYPE_OBJECT,
        callable = c.GDEXTENSION_VARIANT_TYPE_CALLABLE,
        signal = c.GDEXTENSION_VARIANT_TYPE_SIGNAL,
        dictionary = c.GDEXTENSION_VARIANT_TYPE_DICTIONARY,
        array = c.GDEXTENSION_VARIANT_TYPE_ARRAY,
        packed_byte_array = c.GDEXTENSION_VARIANT_TYPE_PACKED_BYTE_ARRAY,
        packed_int32_array = c.GDEXTENSION_VARIANT_TYPE_PACKED_INT32_ARRAY,
        packed_int64_array = c.GDEXTENSION_VARIANT_TYPE_PACKED_INT64_ARRAY,
        packed_float32_array = c.GDEXTENSION_VARIANT_TYPE_PACKED_FLOAT32_ARRAY,
        packed_float64_array = c.GDEXTENSION_VARIANT_TYPE_PACKED_FLOAT64_ARRAY,
        packed_string_array = c.GDEXTENSION_VARIANT_TYPE_PACKED_STRING_ARRAY,
        packed_vector2_array = c.GDEXTENSION_VARIANT_TYPE_PACKED_VECTOR2_ARRAY,
        packed_vector3_array = c.GDEXTENSION_VARIANT_TYPE_PACKED_VECTOR3_ARRAY,
        packed_color_array = c.GDEXTENSION_VARIANT_TYPE_PACKED_COLOR_ARRAY,
        packed_vector4_array = c.GDEXTENSION_VARIANT_TYPE_PACKED_VECTOR4_ARRAY,
        // max = c.GDEXTENSION_VARIANT_TYPE_VARIANT_MAX,

        pub fn forValue(value: anytype) Tag {
            return forType(@TypeOf(value));
        }

        pub fn forType(comptime T: type) Tag {
            const tag: ?Tag = comptime switch (T) {
                Aabb => .aabb,
                Array => .array,
                Basis => .basis,
                bool => .bool,
                Callable => .callable,
                Color => .color,
                Dictionary => .dictionary,
                f64 => .float,
                comptime_float => .float,
                i64 => .int,
                comptime_int => .int,
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
                Rid => .rid,
                Signal => .signal,
                String => .string,
                StringName => .string_name,
                Transform2d => .transform2d,
                Transform3d => .transform3d,
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
                    .pointer => |p| if (class.isClassPtr(T)) .object else forType(p.child),
                    else => null,
                },
            };

            return tag orelse @compileError("Cannot construct a 'Variant' from type '" ++ @typeName(T) ++ "'");
        }

        /// Gets the name of this Variant type.
        pub fn getName(self: Tag) String {
            var result: String = undefined;
            raw.variantGetTypeName(@intFromEnum(self), result.ptr());
            return result;
        }

        /// Checks if this Variant type has the given member.
        pub fn hasMember(self: Tag, member: StringName) bool {
            return raw.variantHasMember(@intFromEnum(self), @ptrCast(&member)) != 0;
        }

        /// Gets the value of a constant from this Variant type.
        pub fn getConstant(self: Tag, constant_name: StringName) Variant {
            var result: Variant = undefined;
            raw.variantGetConstantValue(@intFromEnum(self), @ptrCast(&constant_name), @ptrCast(&result));
            return result;
        }

        /// Checks if Variants can be converted from one type to another.
        pub fn canConvert(from: Tag, to: Tag) bool {
            return raw.variantCanConvert(@intFromEnum(from), @intFromEnum(to)) != 0;
        }

        /// Checks if Variants can be converted from one type to another using stricter rules.
        pub fn canConvertStrict(from: Tag, to: Tag) bool {
            return raw.variantCanConvertStrict(@intFromEnum(from), @intFromEnum(to)) != 0;
        }

        /// Returns true if this variant type allocates from Godot's pool allocators.
        /// These types need explicit cleanup when wrapped in a Variant.
        pub fn allocates(self: Tag) bool {
            return switch (self) {
                .transform2d, .aabb, .basis, .transform3d, .projection => true,
                else => false,
            };
        }

        /// Returns true if wrapping the given type in a Variant would allocate from Godot's pool allocators.
        pub fn allocatesForType(comptime T: type) bool {
            return forType(T).allocates();
        }
    };

    pub const Data = extern union {
        aabb: *Aabb,
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
        rid: Rid,
        signal: Signal,
        string: String,
        string_name: StringName,
        transform2d: *Transform2d,
        transform3d: *Transform3d,
        vector2: Vector2,
        vector2i: Vector2i,
        vector3: Vector3,
        vector3i: Vector3i,
        vector4: Vector4,
        vector4i: Vector4i,
        // max = 38,
    };

    pub const Operator = enum(u32) {
        equal = c.GDEXTENSION_VARIANT_OP_EQUAL,
        not_equal = c.GDEXTENSION_VARIANT_OP_NOT_EQUAL,
        less = c.GDEXTENSION_VARIANT_OP_LESS,
        less_equal = c.GDEXTENSION_VARIANT_OP_LESS_EQUAL,
        greater = c.GDEXTENSION_VARIANT_OP_GREATER,
        greater_equal = c.GDEXTENSION_VARIANT_OP_GREATER_EQUAL,
        add = c.GDEXTENSION_VARIANT_OP_ADD,
        subtract = c.GDEXTENSION_VARIANT_OP_SUBTRACT,
        multiply = c.GDEXTENSION_VARIANT_OP_MULTIPLY,
        divide = c.GDEXTENSION_VARIANT_OP_DIVIDE,
        negate = c.GDEXTENSION_VARIANT_OP_NEGATE,
        positive = c.GDEXTENSION_VARIANT_OP_POSITIVE,
        module = c.GDEXTENSION_VARIANT_OP_MODULE,
        power = c.GDEXTENSION_VARIANT_OP_POWER,
        shift_left = c.GDEXTENSION_VARIANT_OP_SHIFT_LEFT,
        shift_right = c.GDEXTENSION_VARIANT_OP_SHIFT_RIGHT,
        bit_and = c.GDEXTENSION_VARIANT_OP_BIT_AND,
        bit_or = c.GDEXTENSION_VARIANT_OP_BIT_OR,
        bit_xor = c.GDEXTENSION_VARIANT_OP_BIT_XOR,
        bit_negate = c.GDEXTENSION_VARIANT_OP_BIT_NEGATE,
        @"and" = c.GDEXTENSION_VARIANT_OP_AND,
        @"or" = c.GDEXTENSION_VARIANT_OP_OR,
        xor = c.GDEXTENSION_VARIANT_OP_XOR,
        not = c.GDEXTENSION_VARIANT_OP_NOT,
        in = c.GDEXTENSION_VARIANT_OP_IN,
        // max = c.GDEXTENSION_VARIANT_OP_MAX,
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
        .{ .aabb, Aabb },
        .{ .array, Array },
        .{ .basis, Basis },
        .{ .callable, Callable },
        .{ .color, Color },
        .{ .dictionary, Dictionary },
        .{ .node_path, NodePath },
        .{ .object, *Object },
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
        .{ .rid, Rid },
        .{ .rect2, Rect2 },
        .{ .rect2i, Rect2i },
        .{ .signal, Signal },
        .{ .string, String },
        .{ .string_name, StringName },
        .{ .transform2d, Transform2d },
        .{ .transform3d, Transform3d },
        .{ .vector2, Vector2 },
        .{ .vector2i, Vector2i },
        .{ .vector3, Vector3 },
        .{ .vector3i, Vector3i },
        .{ .vector4, Vector4 },
        .{ .vector4i, Vector4i },

        .{ .nil, void },
        .{ .bool, bool },
        .{ .int, i64 },
        .{ .float, f64 },
        .{ .int, enum(u32) {} },
    };

    inline for (pairs) |pair| {
        const tag = pair[0];
        const T = pair[1];

        try testing.expectEqual(tag, Variant.Tag.forType(T));
        try testing.expectEqual(tag, Variant.Tag.forType(*T));
        try testing.expectEqual(tag, Variant.Tag.forType(*const T));
    }
}

test "forType comptime" {
    const pairs = .{
        .{ .int, comptime_int },
        .{ .float, comptime_float },
    };

    inline for (pairs) |pair| {
        const tag = pair[0];
        const T = pair[1];

        try testing.expectEqual(tag, Variant.Tag.forType(T));
    }
}

const std = @import("std");
const Atomic = std.atomic.Value;
const Child = std.meta.Child;
const mem = std.mem;
const testing = std.testing;

const c = @import("gdextension");

const gdzig = @import("gdzig");
const raw = &gdzig.raw;
const CallError = gdzig.CallError;
const PropertyError = gdzig.PropertyError;
const CallResult = gdzig.class.ClassDb.CallResult;
const Aabb = gdzig.builtin.Aabb;
const Array = gdzig.builtin.Array;
const Basis = gdzig.builtin.Basis;
const Callable = gdzig.builtin.Callable;
const Color = gdzig.builtin.Color;
const Dictionary = gdzig.builtin.Dictionary;
const NodePath = gdzig.builtin.NodePath;
const PackedByteArray = gdzig.builtin.PackedByteArray;
const PackedColorArray = gdzig.builtin.PackedColorArray;
const PackedFloat32Array = gdzig.builtin.PackedFloat32Array;
const PackedFloat64Array = gdzig.builtin.PackedFloat64Array;
const PackedInt32Array = gdzig.builtin.PackedInt32Array;
const PackedInt64Array = gdzig.builtin.PackedInt64Array;
const PackedStringArray = gdzig.builtin.PackedStringArray;
const PackedVector2Array = gdzig.builtin.PackedVector2Array;
const PackedVector3Array = gdzig.builtin.PackedVector3Array;
const Plane = gdzig.builtin.Plane;
const Projection = gdzig.builtin.Projection;
const Quaternion = gdzig.builtin.Quaternion;
const Rect2 = gdzig.builtin.Rect2;
const Rect2i = gdzig.builtin.Rect2i;
const Rid = gdzig.builtin.Rid;
const Signal = gdzig.builtin.Signal;
const String = gdzig.builtin.String;
const StringName = gdzig.builtin.StringName;
const Transform2d = gdzig.builtin.Transform2d;
const Transform3d = gdzig.builtin.Transform3d;
const Vector2 = gdzig.builtin.Vector2;
const Vector2i = gdzig.builtin.Vector2i;
const Vector3 = gdzig.builtin.Vector3;
const Vector3i = gdzig.builtin.Vector3i;
const Vector4 = gdzig.builtin.Vector4;
const Vector4i = gdzig.builtin.Vector4i;
const Object = gdzig.class.Object;
const RefCounted = gdzig.class.RefCounted;
const class = gdzig.class;

const precision = @import("build_options").precision;
