const raw: *Interface = &@import("../../gdzig_bindings.zig").raw;

/// Creates a new Variant containing nil.
///
/// @return A new nil Variant.
///
/// @since 4.1
pub inline fn variantNewNil() Variant {
    var result: Variant = undefined;
    raw.variantNewNil(result.ptr());
    return result;
}

/// Copies one Variant into a another.
///
/// @param src A pointer to the source Variant.
///
/// @return A new copy of the Variant.
///
/// @since 4.1
pub inline fn variantNewCopy(src: *const Variant) Variant {
    var result: Variant = undefined;
    raw.variantNewCopy(result.ptr(), src);
    return result;
}

/// Destroys a Variant.
///
/// @param self A pointer to the Variant to destroy.
///
/// @since 4.1
pub inline fn variantDestroy(variant: *Variant) void {
    raw.variantDestroy(variant);
}

/// Gets the type of a Variant.
///
/// @param self A pointer to the Variant.
///
/// @return The variant type.
///
/// @since 4.1
pub inline fn variantGetType(variant: *const Variant) Variant.Tag {
    return @enumFromInt(raw.variantGetType(variant));
}

/// Calls a method on a Variant.
///
/// @param self A pointer to the Variant.
/// @param method A pointer to a StringName with the method name.
/// @param args A slice of Variant pointers representing the arguments.
///
/// @return The return value from the method call.
///
/// @see Variant::callp()
///
/// @since 4.1
pub inline fn variantCall(self: *Variant, method: *const StringName, args: []const *const Variant) CallError!Variant {
    var ret: Variant = undefined;
    var result: CallResult = undefined;

    raw.variantCall(self.ptr(), method.constPtr(), @ptrCast(args.ptr), @intCast(args.len), @ptrCast(&ret), &result);

    try result.throw();

    return ret;
}

/// Calls a static method on a Variant.
///
/// @param variant_tag The type of Variant to call the static method on.
/// @param method A pointer to a StringName identifying the method.
/// @param args A slice of Variant pointers representing the arguments.
///
/// @return The return value from the static method call.
///
/// @see Variant::call_static()
///
/// @since 4.1
pub inline fn variantCallStatic(variant_tag: Variant.Tag, method: *const StringName, args: []const *const Variant) CallError!Variant {
    var ret: Variant = undefined;
    var result: CallResult = undefined;

    raw.variantCallStatic(@intFromEnum(variant_tag), method.constPtr(), @ptrCast(args.ptr), @intCast(args.len), ret.ptr(), &result);

    try result.throw();

    return ret;
}

/// Evaluate an operator on two Variants.
///
/// @param op The operator to evaluate.
/// @param a The first Variant.
/// @param b The second Variant.
///
/// @return The result of the operation. Returns an error if the operation is invalid.
///
/// @see Variant::evaluate()
///
/// @since 4.1
pub inline fn variantEvaluate(op: Variant.Operator, a: *const Variant, b: *const Variant) Error!Variant {
    var result: Variant = undefined;
    var valid: u8 = 0;

    raw.variantEvaluate(@intFromEnum(op), a.constPtr(), b.constPtr(), result.ptr(), &valid);

    if (valid == 0) {
        return error.InvalidOperation;
    }

    return result;
}

/// Gets the value of a key from a Variant.
///
/// @param self A pointer to the Variant.
/// @param key A pointer to a Variant representing the key.
///
/// @return The value for the given key. Returns an error if the key is invalid.
///
/// @since 4.1
pub inline fn variantGet(self: *const Variant, key: *const Variant) Error!Variant {
    var result: Variant = undefined;
    var valid: u8 = 0;

    raw.variantGet(self.constPtr(), key.constPtr(), result.ptr(), &valid);

    if (valid == 0) {
        return error.InvalidOperation;
    }

    return result;
}

/// Sets a key on a Variant to a value.
///
/// @param self A pointer to the Variant.
/// @param key A pointer to a Variant representing the key.
/// @param value A pointer to a Variant representing the value.
///
/// @see Variant::set()
///
/// @since 4.1
pub inline fn variantSet(self: *Variant, key: *const Variant, value: *const Variant) Error!void {
    var valid: u8 = 0;

    raw.variantSet(self.ptr(), key.constPtr(), value.constPtr(), &valid);

    if (valid == 0) {
        return error.InvalidOperation;
    }
}

/// Sets a named key on a Variant to a value.
///
/// @param self A pointer to the Variant.
/// @param key A pointer to a StringName representing the key.
/// @param value A pointer to a Variant representing the value.
///
/// @see Variant::set_named()
///
/// @since 4.1
pub inline fn variantSetNamed(self: *Variant, key: *const StringName, value: *const Variant) Error!void {
    var valid: u8 = 0;
    raw.variantSetNamed(self.ptr(), key.constPtr(), value.constPtr(), &valid);
    if (valid == 0) {
        return error.InvalidOperation;
    }
}

/// Sets a keyed property on a Variant to a value.
///
/// @param self A pointer to the Variant.
/// @param key A pointer to a Variant representing the key.
/// @param value A pointer to a Variant representing the value.
///
/// @see Variant::set_keyed()
///
/// @since 4.1
pub inline fn variantSetKeyed(self: *Variant, key: *const Variant, value: *const Variant) Error!void {
    var valid: u8 = 0;
    raw.variantSetKeyed(self.ptr(), key.constPtr(), value.constPtr(), &valid);
    if (valid == 0) {
        return error.InvalidOperation;
    }
}

/// Gets the value of a named key from a Variant.
///
/// @param self A pointer to the Variant.
/// @param key A pointer to a StringName representing the key.
///
/// @return The value for the given key, or null if the operation is invalid.
///
/// @since 4.1
pub inline fn variantGetNamed(self: *const Variant, key: *const StringName) ?Variant {
    var result: Variant = undefined;
    var valid: u8 = 0;

    raw.variantGetNamed(self.constPtr(), key.constPtr(), result.ptr(), &valid);

    if (valid == 0) {
        return null;
    }

    return result;
}

/// Gets the value of a keyed property from a Variant.
///
/// @param self A pointer to the Variant.
/// @param key A pointer to a Variant representing the key.
///
/// @return The value for the given key, or null if the operation is invalid.
///
/// @since 4.1
pub inline fn variantGetKeyed(self: *const Variant, key: *const Variant) ?Variant {
    var result: Variant = undefined;
    var valid: c.GDExtensionBool = 0;

    raw.variantGetKeyed(self.constPtr(), key.constPtr(), result.ptr(), &valid);

    if (valid == 0) {
        return null;
    }

    return result;
}

/// Gets the value of an index from a Variant.
///
/// @param self A pointer to the Variant.
/// @param index The index.
///
/// @return The value at the given index. Returns an error if the operation is invalid or the index is out of bounds.
///
/// @since 4.1
pub inline fn variantGetIndexed(self: *const Variant, index: i64) Error!Variant {
    var result: Variant = undefined;
    var valid: u8 = 0;
    var oob: u8 = 0;

    raw.variantGetIndexed(self.constPtr(), index, @ptrCast(&result), &valid, &oob);

    if (valid == 0) {
        return error.InvalidOperation;
    }
    if (oob != 0) {
        return error.IndexOutOfBounds;
    }

    return result;
}

/// Sets an index on a Variant to a value.
///
/// @param self A pointer to the Variant.
/// @param index The index.
/// @param value A pointer to a Variant representing the value.
///
/// @since 4.1
pub inline fn variantSetIndexed(self: *Variant, index: i64, value: *const Variant) Error!void {
    var valid: u8 = 0;
    var oob: u8 = 0;

    raw.variantSetIndexed(self.ptr(), index, value.constPtr(), &valid, &oob);

    if (valid == 0) {
        return error.InvalidOperation;
    }
    if (oob != 0) {
        return error.IndexOutOfBounds;
    }
}

/// Checks if a Variant has the given method.
///
/// @param self A pointer to the Variant.
/// @param method A pointer to a StringName with the method name.
///
/// @return true if the method exists; otherwise false.
///
/// @since 4.1
pub inline fn variantHasMethod(self: *const Variant, method: *const StringName) bool {
    return raw.variantHasMethod(self.constPtr(), method.constPtr()) != 0;
}

/// Checks if a Variant has a key.
///
/// @param self A pointer to the Variant.
/// @param key A pointer to a Variant representing the key.
///
/// @return true if the key exists; otherwise false. Returns an error if the check was invalid.
///
/// @since 4.1
pub inline fn variantHasKey(self: *const Variant, key: *const Variant) !bool {
    var valid: u8 = 0;

    const result = raw.variantHasKey(self.constPtr(), key.constPtr(), &valid);

    if (valid == 0) {
        return error.InvalidOperation;
    }

    return result != 0;
}

/// Gets the hash of a Variant.
///
/// @param self A pointer to the Variant.
///
/// @return The hash value.
///
/// @see Variant::hash()
///
/// @since 4.1
pub inline fn variantHash(self: *const Variant) i64 {
    return raw.variantHash(self.constPtr());
}

/// Compares two Variants by their hash.
///
/// @param self A pointer to the Variant.
/// @param other A pointer to the other Variant to compare it to.
///
/// @return true if the variants are equal by hash comparison; otherwise false.
///
/// @see Variant::hash_compare()
///
/// @since 4.1
pub inline fn variantHashCompare(self: *const Variant, other: *const Variant) bool {
    return raw.variantHashCompare(self.constPtr(), other.constPtr()) != 0;
}

/// Gets the recursive hash of a Variant.
///
/// @param self A pointer to the Variant.
/// @param recursion_count The recursion count.
///
/// @return The hash value.
///
/// @see Variant::recursive_hash()
///
/// @since 4.1
pub inline fn variantRecursiveHash(self: *const Variant, recursion_count: i64) i64 {
    return raw.variantRecursiveHash(self.constPtr(), recursion_count);
}

/// Gets the object instance ID from a variant of type GDEXTENSION_VARIANT_TYPE_OBJECT.
///
/// If the variant isn't of type GDEXTENSION_VARIANT_TYPE_OBJECT, then zero will be returned.
/// The instance ID will be returned even if the object is no longer valid - use `object_get_instance_by_id()` to check if the object is still valid.
///
/// @param self A pointer to the Variant.
///
/// @return The instance ID for the contained object.
///
/// @since 4.4
pub inline fn variantGetObjectInstanceId(self: *const Variant) ObjectID {
    return @enumFromInt(raw.variantGetObjectInstanceId(self.constPtr()));
}

/// Converts a Variant to a boolean.
///
/// @param self A pointer to the Variant.
///
/// @return The boolean value of the Variant.
///
/// @since 4.1
pub inline fn variantBooleanize(self: *const Variant) bool {
    return raw.variantBooleanize(self.constPtr()) != 0;
}

/// Duplicates a Variant.
///
/// @param self A pointer to the Variant.
/// @param deep Whether or not to duplicate deeply (when supported by the Variant type).
///
/// @return The duplicated Variant.
///
/// @since 4.1
pub inline fn variantDuplicate(self: *const Variant, deep: bool) Variant {
    var result: Variant = undefined;
    raw.variantDuplicate(self.constPtr(), result.ptr(), @intFromBool(deep));
    return result;
}

/// Converts a Variant to a string.
///
/// @param self A pointer to the Variant.
///
/// @return The string representation.
///
/// @since 4.1
pub inline fn variantStringify(self: *const Variant) String {
    var result: String = undefined;
    raw.variantStringify(self.constPtr(), result.ptr());
    return result;
}

/// Provides a function pointer for retrieving a pointer to a variant's internal value.
/// Access to a variant's internal value can be used to modify it in-place, or to retrieve its value without the overhead of variant conversion functions.
/// It is recommended to cache the getter for all variant types in a function table to avoid retrieval overhead upon use.
///
/// @note Each function assumes the variant's type has already been determined and matches the function.
/// Invoking the function with a variant of a mismatched type has undefined behavior, and may lead to a segmentation fault.
///
/// @param variant_tag The Variant type.
///
/// @return A pointer to a type-specific function that returns a pointer to the internal value of a variant. Check the implementation of this function (gdextension_variant_get_ptr_internal_getter) for pointee type info of each variant type.
///
/// @since 4.4
pub inline fn getVariantGetInternalPtrFunc(variant_tag: Variant.Tag) ?*const VariantGetInternalPtrFunc {
    return raw.getVariantGetInternalPtrFunc(@intFromEnum(variant_tag));
}

/// Gets a pointer to a function that can evaluate the given Variant operator on the given Variant types.
///
/// @param op The variant operator.
/// @param a The type of the first Variant.
/// @param b The type of the second Variant.
///
/// @return A pointer to a function that can evaluate the given Variant operator on the given Variant types.
///
/// @since 4.1
pub inline fn variantGetPtrOperatorEvaluator(op: Variant.Operator, a: Variant.Tag, b: Variant.Tag) ?*const PtrOperatorEvaluator {
    return raw.variantGetPtrOperatorEvaluator(@intFromEnum(op), @intFromEnum(a), @intFromEnum(b));
}

/// Gets a pointer to a function that can call a builtin method on a type of Variant.
///
/// @param p_type The Variant type.
/// @param p_method A pointer to a StringName with the method name.
/// @param p_hash A hash representing the method signature.
///
/// @return A pointer to a function that can call a builtin method on a type of Variant.
///
/// @since 4.1
pub inline fn variantGetPtrBuiltinMethod(variant_tag: Variant.Tag, method: *const StringName, hash: i64) ?*const PtrBuiltInMethod {
    return raw.variantGetPtrBuiltinMethod(@intFromEnum(variant_tag), method.constPtr(), hash);
}

/// Gets the name of a Variant type.
///
/// @param variant_tag The Variant type.
///
/// @return The Variant type name as a String.
///
/// @since 4.1
pub inline fn variantGetTypeName(variant_tag: Variant.Tag) String {
    var result: String = undefined;
    raw.variantGetTypeName(@intFromEnum(variant_tag), result.ptr());
    return result;
}

/// Checks if a type of Variant has the given member.
///
/// @param variant_tag The Variant type.
/// @param member A pointer to a StringName with the member name.
///
/// @return true if the type has the member; otherwise false.
///
/// @since 4.1
pub inline fn variantHasMember(variant_tag: Variant.Tag, member: *const StringName) bool {
    return raw.variantHasMember(@intFromEnum(variant_tag), member.constPtr()) != 0;
}

/// Initializes an iterator over a Variant.
///
/// @param self A pointer to the Variant.
///
/// @return The iterator as a Variant. Returns an error if the iterator initialization failed.
///
/// @return true if the operation is valid; otherwise false.
///
/// @see Variant::iter_init()
///
/// @since 4.1
pub inline fn variantIterInit(self: *const Variant) Error!Variant {
    var iter: Variant = undefined;
    var valid: u8 = 0;

    raw.variantIterInit(self.constPtr(), iter.ptr(), &valid);

    if (valid == 0) {
        return error.IteratorInitFailed;
    }

    return iter;
}

/// Gets the next value for an iterator over a Variant.
///
/// @param self A pointer to the Variant.
/// @param iter A pointer to a Variant iterator.
///
/// @return true if there are more items to iterate over; otherwise false. Returns an error if the iterator is invalid.
///
/// @see Variant::iter_next()
///
/// @since 4.1
pub inline fn variantIterNext(self: *const Variant, iter: *Variant) !bool {
    var valid: u8 = 0;
    const result = raw.variantIterNext(self.constPtr(), iter.ptr(), &valid);

    if (valid == 0) {
        return error.InvalidIterator;
    }

    return result != 0;
}

/// Gets the next value for an iterator over a Variant.
///
/// @param self A pointer to the Variant.
/// @param iter A pointer to a Variant iterator.
///
/// @return The current value at the iterator position. Returns an error if the iterator is invalid.
///
/// @see Variant::iter_get()
///
/// @since 4.1
pub inline fn variantIterGet(self: *const Variant, iter: *Variant) Error!Variant {
    var result: Variant = undefined;
    var valid: u8 = 0;

    raw.variantIterGet(self.constPtr(), iter.ptr(), @ptrCast(&result), &valid);

    if (valid == 0) {
        return error.InvalidIterator;
    }

    return result;
}

/// Checks if Variants can be converted from one type to another.
///
/// @param from The Variant type to convert from.
/// @param to The Variant type to convert to.
///
/// @return true if the conversion is possible; otherwise false.
///
/// @since 4.1
pub inline fn variantCanConvert(from: Variant.Tag, to: Variant.Tag) bool {
    return raw.variantCanConvert(@intFromEnum(from), @intFromEnum(to)) != 0;
}

/// Checks if Variant can be converted from one type to another using stricter rules.
///
/// @param from The Variant type to convert from.
/// @param to The Variant type to convert to.
///
/// @return true if the conversion is possible; otherwise false.
///
/// @since 4.1
pub inline fn variantCanConvertStrict(from: Variant.Tag, to: Variant.Tag) bool {
    return raw.variantCanConvertStrict(@intFromEnum(from), @intFromEnum(to)) != 0;
}

/// Gets the value of a constant from the given Variant type.
///
/// @param variant_tag The Variant type.
/// @param constant_name A pointer to a StringName with the constant name.
///
/// @return The constant value as a Variant.
///
/// @since 4.1
pub inline fn variantGetConstantValue(variant_tag: Variant.Tag, constant_name: *const StringName) Variant {
    var result: Variant = undefined;
    raw.variantGetConstantValue(@intFromEnum(variant_tag), constant_name.constPtr(), result.ptr());
    return result;
}

/// Gets a pointer to a function that can call a Variant utility function.
///
/// @param function A pointer to a StringName with the function name.
/// @param hash A hash representing the function signature.
///
/// @return A pointer to a function that can call a Variant utility function.
///
/// @since 4.1
pub inline fn variantGetPtrUtilityFunction(function_name: *const StringName, hash: i64) ?*const PtrUtilityFunction {
    return raw.variantGetPtrUtilityFunction(function_name.constPtr(), hash);
}

/// Gets a pointer to a function that can call a member's setter on the given Variant type.
///
/// @param variant_tag The Variant type.
/// @param member A pointer to a StringName with the member name.
///
/// @return A pointer to a function that can call a member's setter on the given Variant type.
///
/// @since 4.1
pub inline fn variantGetPtrSetter(variant_tag: Variant.Tag, member: *const StringName) ?*const PtrSetter {
    return raw.variantGetPtrSetter(@intFromEnum(variant_tag), member.constPtr());
}

/// Gets a pointer to a function that can call a member's getter on the given Variant type.
///
/// @param variant_tag The Variant type.
/// @param member A pointer to a StringName with the member name.
///
/// @return A pointer to a function that can call a member's getter on the given Variant type.
///
/// @since 4.1
pub inline fn variantGetPtrGetter(variant_tag: Variant.Tag, member: *const StringName) ?*const PtrGetter {
    return raw.variantGetPtrGetter(@intFromEnum(variant_tag), member.constPtr());
}

/// Gets a pointer to a function that can set an index on the given Variant type.
///
/// @param variant_tag The Variant type.
///
/// @return A pointer to a function that can set an index on the given Variant type.
///
/// @since 4.1
pub inline fn variantGetPtrIndexedSetter(variant_tag: Variant.Tag) ?*const PtrIndexedSetter {
    return raw.variantGetPtrIndexedSetter(@intFromEnum(variant_tag));
}

/// Gets a pointer to a function that can get an index on the given Variant type.
///
/// @param variant_tag The Variant type.
///
/// @return A pointer to a function that can get an index on the given Variant type.
///
/// @since 4.1
pub inline fn variantGetPtrIndexedGetter(variant_tag: Variant.Tag) ?*const PtrIndexedGetter {
    return raw.variantGetPtrIndexedGetter(@intFromEnum(variant_tag));
}

/// Gets a pointer to a function that can set a key on the given Variant type.
///
/// @param variant_tag The Variant type.
///
/// @return A pointer to a function that can set a key on the given Variant type.
///
/// @since 4.1
pub inline fn variantGetPtrKeyedSetter(variant_tag: Variant.Tag) ?*const PtrKeyedSetter {
    return raw.variantGetPtrKeyedSetter(@intFromEnum(variant_tag));
}

/// Gets a pointer to a function that can get a key on the given Variant type.
///
/// @param variant_tag The Variant type.
///
/// @return A pointer to a function that can get a key on the given Variant type.
///
/// @since 4.1
pub inline fn variantGetPtrKeyedGetter(variant_tag: Variant.Tag) ?*const PtrKeyedGetter {
    return raw.variantGetPtrKeyedGetter(@intFromEnum(variant_tag));
}

/// Gets a pointer to a function that can check a key on the given Variant type.
///
/// @param variant_tag The Variant type.
///
/// @return A pointer to a function that can check a key on the given Variant type.
///
/// @since 4.1
pub inline fn variantGetPtrKeyedChecker(variant_tag: Variant.Tag) ?*const PtrKeyedChecker {
    return raw.variantGetPtrKeyedChecker(@intFromEnum(variant_tag));
}

/// Gets a pointer to a function that can create a Variant of the given type from a raw value.
///
/// @param variant_tag The Variant type.
///
/// @return A pointer to a function that can create a Variant of the given type from a raw value.
///
/// @since 4.1
pub inline fn getVariantFromTypeConstructor(variant_tag: Variant.Tag) ?*const VariantFromTypeConstructorFunc {
    return raw.getVariantFromTypeConstructor(@intFromEnum(variant_tag));
}

/// Gets a pointer to a function that can get the raw value from a Variant of the given type.
///
/// @param variant_tag The Variant type.
///
/// @return A pointer to a function that can get the raw value from a Variant of the given type.
///
/// @since 4.1
pub inline fn getVariantToTypeConstructor(variant_tag: Variant.Tag) ?*const TypeFromVariantConstructorFunc {
    return raw.getVariantToTypeConstructor(@intFromEnum(variant_tag));
}

/// Gets a pointer to a function that can call one of the constructors for a type of Variant.
///
/// @param variant_tag The Variant type.
/// @param constructor The index of the constructor.
///
/// @return A pointer to a function that can call one of the constructors for a type of Variant.
///
/// @since 4.1
pub inline fn variantGetPtrConstructor(variant_tag: Variant.Tag, constructor: i32) ?*const PtrConstructor {
    return raw.variantGetPtrConstructor(@intFromEnum(variant_tag), constructor);
}

/// Gets a pointer to a function than can call the destructor for a type of Variant.
///
/// @param variant_tag The Variant type.
///
/// @return A pointer to a function than can call the destructor for a type of Variant.
///
/// @since 4.1
pub inline fn variantGetPtrDestructor(variant_tag: Variant.Tag) ?*const PtrDestructor {
    return raw.variantGetPtrDestructor(@intFromEnum(variant_tag));
}

/// Constructs a Variant of the given type, using the first constructor that matches the given arguments.
///
/// @param variant_tag The Variant type to construct.
/// @param args A slice of Variant pointers representing the arguments for the constructor.
///
/// @return The constructed Variant.
///
/// @since 4.1
pub inline fn variantConstruct(variant_tag: Variant.Tag, args: []const *const Variant) CallError!Variant {
    var ret: Variant = undefined;
    var err: CallResult = undefined;

    raw.variantConstruct(
        @intFromEnum(variant_tag),
        @ptrCast(&ret),
        @ptrCast(args.ptr),
        @intCast(args.len),
        &err,
    );

    try err.throw();

    return ret;
}

pub const VariantFromTypeConstructorFunc = fn (r_dest: c.GDExtensionUninitializedVariantPtr, p_src: c.GDExtensionTypePtr) callconv(.c) void;
pub const TypeFromVariantConstructorFunc = fn (r_dest: c.GDExtensionUninitializedTypePtr, p_src: c.GDExtensionVariantPtr) callconv(.c) void;

pub const VariantGetInternalPtrFunc = fn (p_variant: c.GDExtensionVariantPtr) callconv(.c) ?*anyopaque;
pub const PtrOperatorEvaluator = fn (p_left: c.GDExtensionConstTypePtr, p_right: c.GDExtensionConstTypePtr, r_result: c.GDExtensionTypePtr) callconv(.c) void;
pub const PtrBuiltInMethod = fn (p_base: c.GDExtensionTypePtr, p_args: [*c]const c.GDExtensionConstTypePtr, r_return: c.GDExtensionTypePtr, p_argument_count: c_int) callconv(.c) void;
pub const PtrConstructor = fn (p_base: c.GDExtensionUninitializedTypePtr, p_args: [*c]const c.GDExtensionConstTypePtr) callconv(.c) void;
pub const PtrDestructor = fn (p_base: c.GDExtensionTypePtr) callconv(.c) void;
pub const PtrSetter = fn (p_base: c.GDExtensionTypePtr, p_value: c.GDExtensionConstTypePtr) callconv(.c) void;
pub const PtrGetter = fn (p_base: c.GDExtensionConstTypePtr, r_value: c.GDExtensionTypePtr) callconv(.c) void;
pub const PtrIndexedSetter = fn (p_base: c.GDExtensionTypePtr, p_index: c.GDExtensionInt, p_value: c.GDExtensionConstTypePtr) callconv(.c) void;
pub const PtrIndexedGetter = fn (p_base: c.GDExtensionConstTypePtr, p_index: c.GDExtensionInt, r_value: c.GDExtensionTypePtr) callconv(.c) void;
pub const PtrKeyedSetter = fn (p_base: c.GDExtensionTypePtr, p_key: c.GDExtensionConstTypePtr, p_value: c.GDExtensionConstTypePtr) callconv(.c) void;
pub const PtrKeyedGetter = fn (p_base: c.GDExtensionConstTypePtr, p_key: c.GDExtensionConstTypePtr, r_value: c.GDExtensionTypePtr) callconv(.c) void;
pub const PtrKeyedChecker = fn (p_base: c.GDExtensionConstVariantPtr, p_key: c.GDExtensionConstVariantPtr) callconv(.c) u32;
pub const PtrUtilityFunction = fn (r_return: c.GDExtensionTypePtr, p_args: [*c]const c.GDExtensionConstTypePtr, p_argument_count: c_int) callconv(.c) void;

const c = @import("gdextension");

const api = @import("../api.zig");
const Error = api.Error;
const CallResult = api.CallResult;
const CallError = api.CallError;
const ObjectID = api.ObjectID;
const builtin = @import("../builtin.zig");
const StringName = builtin.StringName;
const String = builtin.String;
const Variant = builtin.Variant;
const Interface = @import("../Interface.zig");
