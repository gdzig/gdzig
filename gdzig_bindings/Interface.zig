const Interface = @This();

library: *ClassLibrary,

/// @since 4.1
///
/// Gets the Godot version that the GDExtension was loaded into.
///
/// @param r_godot_version A pointer to the structure to write the version information into.
getGodotVersion: Child(c.GDExtensionInterfaceGetGodotVersion),

/// @since 4.1
///
/// Allocates memory.
///
/// @param p_bytes The amount of memory to allocate in bytes.
///
/// @return A pointer to the allocated memory, or NULL if unsuccessful.
memAlloc: Child(c.GDExtensionInterfaceMemAlloc),

/// @since 4.1
///
/// Reallocates memory.
///
/// @param p_ptr A pointer to the previously allocated memory.
/// @param p_bytes The number of bytes to resize the memory block to.
///
/// @return A pointer to the allocated memory, or NULL if unsuccessful.
memRealloc: Child(c.GDExtensionInterfaceMemRealloc),

/// @since 4.1
///
/// Frees memory.
///
/// @param p_ptr A pointer to the previously allocated memory.
memFree: Child(c.GDExtensionInterfaceMemFree),

/// @since 4.1
///
/// Logs an error to Godot's built-in debugger and to the OS terminal.
///
/// @param p_description The code triggering the error.
/// @param p_function The function name where the error occurred.
/// @param p_file The file where the error occurred.
/// @param p_line The line where the error occurred.
/// @param p_editor_notify Whether or not to notify the editor.
printError: Child(c.GDExtensionInterfacePrintError),

/// @since 4.1
///
/// Logs an error with a message to Godot's built-in debugger and to the OS terminal.
///
/// @param p_description The code triggering the error.
/// @param p_message The message to show along with the error.
/// @param p_function The function name where the error occurred.
/// @param p_file The file where the error occurred.
/// @param p_line The line where the error occurred.
/// @param p_editor_notify Whether or not to notify the editor.
printErrorWithMessage: Child(c.GDExtensionInterfacePrintErrorWithMessage),

/// @since 4.1
///
/// Logs a warning to Godot's built-in debugger and to the OS terminal.
///
/// @param p_description The code triggering the warning.
/// @param p_function The function name where the warning occurred.
/// @param p_file The file where the warning occurred.
/// @param p_line The line where the warning occurred.
/// @param p_editor_notify Whether or not to notify the editor.
printWarning: Child(c.GDExtensionInterfacePrintWarning),

/// @since 4.1
///
/// Logs a warning with a message to Godot's built-in debugger and to the OS terminal.
///
/// @param p_description The code triggering the warning.
/// @param p_message The message to show along with the warning.
/// @param p_function The function name where the warning occurred.
/// @param p_file The file where the warning occurred.
/// @param p_line The line where the warning occurred.
/// @param p_editor_notify Whether or not to notify the editor.
printWarningWithMessage: Child(c.GDExtensionInterfacePrintWarningWithMessage),

/// @since 4.1
///
/// Logs a script error to Godot's built-in debugger and to the OS terminal.
///
/// @param p_description The code triggering the error.
/// @param p_function The function name where the error occurred.
/// @param p_file The file where the error occurred.
/// @param p_line The line where the error occurred.
/// @param p_editor_notify Whether or not to notify the editor.
printScriptError: Child(c.GDExtensionInterfacePrintScriptError),

/// @since 4.1
///
/// Logs a script error with a message to Godot's built-in debugger and to the OS terminal.
///
/// @param p_description The code triggering the error.
/// @param p_message The message to show along with the error.
/// @param p_function The function name where the error occurred.
/// @param p_file The file where the error occurred.
/// @param p_line The line where the error occurred.
/// @param p_editor_notify Whether or not to notify the editor.
printScriptErrorWithMessage: Child(c.GDExtensionInterfacePrintScriptErrorWithMessage),

/// @since 4.1
///
/// Gets the size of a native struct (ex. ObjectID) in bytes.
///
/// @param p_name A pointer to a StringName identifying the struct name.
///
/// @return The size in bytes.
getNativeStructSize: Child(c.GDExtensionInterfaceGetNativeStructSize),

/// @since 4.1
///
/// Copies one Variant into a another.
///
/// @param r_dest A pointer to the destination Variant.
/// @param p_src A pointer to the source Variant.
variantNewCopy: Child(c.GDExtensionInterfaceVariantNewCopy),

/// @since 4.1
///
/// Creates a new Variant containing nil.
///
/// @param r_dest A pointer to the destination Variant.
variantNewNil: Child(c.GDExtensionInterfaceVariantNewNil),

/// @since 4.1
///
/// Destroys a Variant.
///
/// @param p_self A pointer to the Variant to destroy.
variantDestroy: Child(c.GDExtensionInterfaceVariantDestroy),

/// @since 4.1
///
/// Calls a method on a Variant.
///
/// @param p_self A pointer to the Variant.
/// @param p_method A pointer to a StringName identifying the method.
/// @param p_args A pointer to a C array of Variant.
/// @param p_argument_count The number of arguments.
/// @param r_return A pointer a Variant which will be assigned the return value.
/// @param r_error A pointer the structure which will hold error information.
///
/// @see Variant::callp()
variantCall: Child(c.GDExtensionInterfaceVariantCall),

/// @since 4.1
///
/// Calls a static method on a Variant.
///
/// @param p_self A pointer to the Variant.
/// @param p_method A pointer to a StringName identifying the method.
/// @param p_args A pointer to a C array of Variant.
/// @param p_argument_count The number of arguments.
/// @param r_return A pointer a Variant which will be assigned the return value.
/// @param r_error A pointer the structure which will be updated with error information.
///
/// @see Variant::call_static()
variantCallStatic: Child(c.GDExtensionInterfaceVariantCallStatic),

/// @since 4.1
///
/// Evaluate an operator on two Variants.
///
/// @param p_op The operator to evaluate.
/// @param p_a The first Variant.
/// @param p_b The second Variant.
/// @param r_return A pointer a Variant which will be assigned the return value.
/// @param r_valid A pointer to a boolean which will be set to false if the operation is invalid.
///
/// @see Variant::evaluate()
variantEvaluate: Child(c.GDExtensionInterfaceVariantEvaluate),

/// @since 4.1
///
/// Sets a key on a Variant to a value.
///
/// @param p_self A pointer to the Variant.
/// @param p_key A pointer to a Variant representing the key.
/// @param p_value A pointer to a Variant representing the value.
/// @param r_valid A pointer to a boolean which will be set to false if the operation is invalid.
///
/// @see Variant::set()
variantSet: Child(c.GDExtensionInterfaceVariantSet),

/// @since 4.1
///
/// Sets a named key on a Variant to a value.
///
/// @param p_self A pointer to the Variant.
/// @param p_key A pointer to a StringName representing the key.
/// @param p_value A pointer to a Variant representing the value.
/// @param r_valid A pointer to a boolean which will be set to false if the operation is invalid.
///
/// @see Variant::set_named()
variantSetNamed: Child(c.GDExtensionInterfaceVariantSetNamed),

/// @since 4.1
///
/// Sets a keyed property on a Variant to a value.
///
/// @param p_self A pointer to the Variant.
/// @param p_key A pointer to a Variant representing the key.
/// @param p_value A pointer to a Variant representing the value.
/// @param r_valid A pointer to a boolean which will be set to false if the operation is invalid.
///
/// @see Variant::set_keyed()
variantSetKeyed: Child(c.GDExtensionInterfaceVariantSetKeyed),

/// @since 4.1
///
/// Sets an index on a Variant to a value.
///
/// @param p_self A pointer to the Variant.
/// @param p_index The index.
/// @param p_value A pointer to a Variant representing the value.
/// @param r_valid A pointer to a boolean which will be set to false if the operation is invalid.
/// @param r_oob A pointer to a boolean which will be set to true if the index is out of bounds.
variantSetIndexed: Child(c.GDExtensionInterfaceVariantSetIndexed),

/// @since 4.1
///
/// Gets the value of a key from a Variant.
///
/// @param p_self A pointer to the Variant.
/// @param p_key A pointer to a Variant representing the key.
/// @param r_ret A pointer to a Variant which will be assigned the value.
/// @param r_valid A pointer to a boolean which will be set to false if the operation is invalid.
variantGet: Child(c.GDExtensionInterfaceVariantGet),

/// @since 4.1
///
/// Gets the value of a named key from a Variant.
///
/// @param p_self A pointer to the Variant.
/// @param p_key A pointer to a StringName representing the key.
/// @param r_ret A pointer to a Variant which will be assigned the value.
/// @param r_valid A pointer to a boolean which will be set to false if the operation is invalid.
variantGetNamed: Child(c.GDExtensionInterfaceVariantGetNamed),

/// @since 4.1
///
/// Gets the value of a keyed property from a Variant.
///
/// @param p_self A pointer to the Variant.
/// @param p_key A pointer to a Variant representing the key.
/// @param r_ret A pointer to a Variant which will be assigned the value.
/// @param r_valid A pointer to a boolean which will be set to false if the operation is invalid.
variantGetKeyed: Child(c.GDExtensionInterfaceVariantGetKeyed),

/// @since 4.1
///
/// Gets the value of an index from a Variant.
///
/// @param p_self A pointer to the Variant.
/// @param p_index The index.
/// @param r_ret A pointer to a Variant which will be assigned the value.
/// @param r_valid A pointer to a boolean which will be set to false if the operation is invalid.
/// @param r_oob A pointer to a boolean which will be set to true if the index is out of bounds.
variantGetIndexed: Child(c.GDExtensionInterfaceVariantGetIndexed),

/// @since 4.1
///
/// Initializes an iterator over a Variant.
///
/// @param p_self A pointer to the Variant.
/// @param r_iter A pointer to a Variant which will be assigned the iterator.
/// @param r_valid A pointer to a boolean which will be set to false if the operation is invalid.
///
/// @return true if the operation is valid; otherwise false.
///
/// @see Variant::iter_init()
variantIterInit: Child(c.GDExtensionInterfaceVariantIterInit),

/// @since 4.1
///
/// Gets the next value for an iterator over a Variant.
///
/// @param p_self A pointer to the Variant.
/// @param r_iter A pointer to a Variant which will be assigned the iterator.
/// @param r_valid A pointer to a boolean which will be set to false if the operation is invalid.
///
/// @return true if the operation is valid; otherwise false.
///
/// @see Variant::iter_next()
variantIterNext: Child(c.GDExtensionInterfaceVariantIterNext),

/// @since 4.1
///
/// Gets the next value for an iterator over a Variant.
///
/// @param p_self A pointer to the Variant.
/// @param r_iter A pointer to a Variant which will be assigned the iterator.
/// @param r_ret A pointer to a Variant which will be assigned false if the operation is invalid.
/// @param r_valid A pointer to a boolean which will be set to false if the operation is invalid.
///
/// @see Variant::iter_get()
variantIterGet: Child(c.GDExtensionInterfaceVariantIterGet),

/// @since 4.1
///
/// Gets the hash of a Variant.
///
/// @param p_self A pointer to the Variant.
///
/// @return The hash value.
///
/// @see Variant::hash()
variantHash: Child(c.GDExtensionInterfaceVariantHash),

/// @since 4.1
///
/// Gets the recursive hash of a Variant.
///
/// @param p_self A pointer to the Variant.
/// @param p_recursion_count The number of recursive loops so far.
///
/// @return The hash value.
///
/// @see Variant::recursive_hash()
variantRecursiveHash: Child(c.GDExtensionInterfaceVariantRecursiveHash),

/// @since 4.1
///
/// Compares two Variants by their hash.
///
/// @param p_self A pointer to the Variant.
/// @param p_other A pointer to the other Variant to compare it to.
///
/// @return The hash value.
///
/// @see Variant::hash_compare()
variantHashCompare: Child(c.GDExtensionInterfaceVariantHashCompare),

/// @since 4.1
///
/// Converts a Variant to a boolean.
///
/// @param p_self A pointer to the Variant.
///
/// @return The boolean value of the Variant.
variantBooleanize: Child(c.GDExtensionInterfaceVariantBooleanize),

/// @since 4.1
///
/// Duplicates a Variant.
///
/// @param p_self A pointer to the Variant.
/// @param r_ret A pointer to a Variant to store the duplicated value.
/// @param p_deep Whether or not to duplicate deeply (when supported by the Variant type).
variantDuplicate: Child(c.GDExtensionInterfaceVariantDuplicate),

/// @since 4.1
///
/// Converts a Variant to a string.
///
/// @param p_self A pointer to the Variant.
/// @param r_ret A pointer to a String to store the resulting value.
variantStringify: Child(c.GDExtensionInterfaceVariantStringify),

/// @since 4.1
///
/// Gets the type of a Variant.
///
/// @param p_self A pointer to the Variant.
///
/// @return The variant type.
variantGetType: Child(c.GDExtensionInterfaceVariantGetType),

/// @since 4.1
///
/// Checks if a Variant has the given method.
///
/// @param p_self A pointer to the Variant.
/// @param p_method A pointer to a StringName with the method name.
///
/// @return
variantHasMethod: Child(c.GDExtensionInterfaceVariantHasMethod),

/// @since 4.1
///
/// Checks if a type of Variant has the given member.
///
/// @param p_type The Variant type.
/// @param p_member A pointer to a StringName with the member name.
///
/// @return
variantHasMember: Child(c.GDExtensionInterfaceVariantHasMember),

/// @since 4.1
///
/// Checks if a Variant has a key.
///
/// @param p_self A pointer to the Variant.
/// @param p_key A pointer to a Variant representing the key.
/// @param r_valid A pointer to a boolean which will be set to false if the key doesn't exist.
///
/// @return true if the key exists; otherwise false.
variantHasKey: Child(c.GDExtensionInterfaceVariantHasKey),

/// @since 4.4
///
/// Gets the object instance ID from a variant of type GDEXTENSION_VARIANT_TYPE_OBJECT.
///
/// If the variant isn't of type GDEXTENSION_VARIANT_TYPE_OBJECT, then zero will be returned.
/// The instance ID will be returned even if the object is no longer valid - use `object_get_instance_by_id()` to check if the object is still valid.
///
/// @param p_self A pointer to the Variant.
///
/// @return The instance ID for the contained object.
variantGetObjectInstanceId: Child(c.GDExtensionInterfaceVariantGetObjectInstanceId),

/// @since 4.1
///
/// Gets the name of a Variant type.
///
/// @param p_type The Variant type.
/// @param r_name A pointer to a String to store the Variant type name.
variantGetTypeName: Child(c.GDExtensionInterfaceVariantGetTypeName),

/// @since 4.1
///
/// Checks if Variants can be converted from one type to another.
///
/// @param p_from The Variant type to convert from.
/// @param p_to The Variant type to convert to.
///
/// @return true if the conversion is possible; otherwise false.
variantCanConvert: Child(c.GDExtensionInterfaceVariantCanConvert),

/// @since 4.1
///
/// Checks if Variant can be converted from one type to another using stricter rules.
///
/// @param p_from The Variant type to convert from.
/// @param p_to The Variant type to convert to.
///
/// @return true if the conversion is possible; otherwise false.
variantCanConvertStrict: Child(c.GDExtensionInterfaceVariantCanConvertStrict),

/// @since 4.1
///
/// Gets a pointer to a function that can create a Variant of the given type from a raw value.
///
/// @param p_type The Variant type.
///
/// @return A pointer to a function that can create a Variant of the given type from a raw value.
getVariantFromTypeConstructor: Child(c.GDExtensionInterfaceGetVariantFromTypeConstructor),

/// @since 4.1
///
/// Gets a pointer to a function that can get the raw value from a Variant of the given type.
///
/// @param p_type The Variant type.
///
/// @return A pointer to a function that can get the raw value from a Variant of the given type.
getVariantToTypeConstructor: Child(c.GDExtensionInterfaceGetVariantToTypeConstructor),

/// @since 4.4
///
/// Provides a function pointer for retrieving a pointer to a variant's internal value.
/// Access to a variant's internal value can be used to modify it in-place, or to retrieve its value without the overhead of variant conversion functions.
/// It is recommended to cache the getter for all variant types in a function table to avoid retrieval overhead upon use.
///
/// @note Each function assumes the variant's type has already been determined and matches the function.
/// Invoking the function with a variant of a mismatched type has undefined behavior, and may lead to a segmentation fault.
///
/// @param p_type The Variant type.
///
/// @return A pointer to a type-specific function that returns a pointer to the internal value of a variant. Check the implementation of this function (gdextension_variant_get_ptr_internal_getter) for pointee type info of each variant type.
variantGetPtrInternalGetter: Child(c.GDExtensionInterfaceGetVariantGetInternalPtrFunc),

/// @since 4.1
///
/// Gets a pointer to a function that can evaluate the given Variant operator on the given Variant types.
///
/// @param p_operator The variant operator.
/// @param p_type_a The type of the first Variant.
/// @param p_type_b The type of the second Variant.
///
/// @return A pointer to a function that can evaluate the given Variant operator on the given Variant types.
variantGetPtrOperatorEvaluator: Child(c.GDExtensionInterfaceVariantGetPtrOperatorEvaluator),

/// @since 4.1
///
/// Gets a pointer to a function that can call a builtin method on a type of Variant.
///
/// @param p_type The Variant type.
/// @param p_method A pointer to a StringName with the method name.
/// @param p_hash A hash representing the method signature.
///
/// @return A pointer to a function that can call a builtin method on a type of Variant.
variantGetPtrBuiltinMethod: Child(c.GDExtensionInterfaceVariantGetPtrBuiltinMethod),

/// @since 4.1
///
/// Gets a pointer to a function that can call one of the constructors for a type of Variant.
///
/// @param p_type The Variant type.
/// @param p_constructor The index of the constructor.
///
/// @return A pointer to a function that can call one of the constructors for a type of Variant.
variantGetPtrConstructor: Child(c.GDExtensionInterfaceVariantGetPtrConstructor),

/// @since 4.1
///
/// Gets a pointer to a function than can call the destructor for a type of Variant.
///
/// @param p_type The Variant type.
///
/// @return A pointer to a function than can call the destructor for a type of Variant.
variantGetPtrDestructor: Child(c.GDExtensionInterfaceVariantGetPtrDestructor),

/// @since 4.1
///
/// Constructs a Variant of the given type, using the first constructor that matches the given arguments.
///
/// @param p_type The Variant type.
/// @param p_base A pointer to a Variant to store the constructed value.
/// @param p_args A pointer to a C array of Variant pointers representing the arguments for the constructor.
/// @param p_argument_count The number of arguments to pass to the constructor.
/// @param r_error A pointer the structure which will be updated with error information.
variantConstruct: Child(c.GDExtensionInterfaceVariantConstruct),

/// @since 4.1
///
/// Gets a pointer to a function that can call a member's setter on the given Variant type.
///
/// @param p_type The Variant type.
/// @param p_member A pointer to a StringName with the member name.
///
/// @return A pointer to a function that can call a member's setter on the given Variant type.
variantGetPtrSetter: Child(c.GDExtensionInterfaceVariantGetPtrSetter),

/// @since 4.1
///
/// Gets a pointer to a function that can call a member's getter on the given Variant type.
///
/// @param p_type The Variant type.
/// @param p_member A pointer to a StringName with the member name.
///
/// @return A pointer to a function that can call a member's getter on the given Variant type.
variantGetPtrGetter: Child(c.GDExtensionInterfaceVariantGetPtrGetter),

/// @since 4.1
///
/// Gets a pointer to a function that can set an index on the given Variant type.
///
/// @param p_type The Variant type.
///
/// @return A pointer to a function that can set an index on the given Variant type.
variantGetPtrIndexedSetter: Child(c.GDExtensionInterfaceVariantGetPtrIndexedSetter),

/// @since 4.1
///
/// Gets a pointer to a function that can get an index on the given Variant type.
///
/// @param p_type The Variant type.
///
/// @return A pointer to a function that can get an index on the given Variant type.
variantGetPtrIndexedGetter: Child(c.GDExtensionInterfaceVariantGetPtrIndexedGetter),

/// @since 4.1
///
/// Gets a pointer to a function that can set a key on the given Variant type.
///
/// @param p_type The Variant type.
///
/// @return A pointer to a function that can set a key on the given Variant type.
variantGetPtrKeyedSetter: Child(c.GDExtensionInterfaceVariantGetPtrKeyedSetter),

/// @since 4.1
///
/// Gets a pointer to a function that can get a key on the given Variant type.
///
/// @param p_type The Variant type.
///
/// @return A pointer to a function that can get a key on the given Variant type.
variantGetPtrKeyedGetter: Child(c.GDExtensionInterfaceVariantGetPtrKeyedGetter),

/// @since 4.1
///
/// Gets a pointer to a function that can check a key on the given Variant type.
///
/// @param p_type The Variant type.
///
/// @return A pointer to a function that can check a key on the given Variant type.
variantGetPtrKeyedChecker: Child(c.GDExtensionInterfaceVariantGetPtrKeyedChecker),

/// @since 4.1
///
/// Gets the value of a constant from the given Variant type.
///
/// @param p_type The Variant type.
/// @param p_constant A pointer to a StringName with the constant name.
/// @param r_ret A pointer to a Variant to store the value.
variantGetConstantValue: Child(c.GDExtensionInterfaceVariantGetConstantValue),

/// @since 4.1
///
/// Gets a pointer to a function that can call a Variant utility function.
///
/// @param p_function A pointer to a StringName with the function name.
/// @param p_hash A hash representing the function signature.
///
/// @return A pointer to a function that can call a Variant utility function.
variantGetPtrUtilityFunction: Child(c.GDExtensionInterfaceVariantGetPtrUtilityFunction),

/// @since 4.1
///
/// Creates a String from a Latin-1 encoded C string.
///
/// @param r_dest A pointer to a Variant to hold the newly created String.
/// @param p_contents A pointer to a Latin-1 encoded C string (null terminated).
stringNewWithLatin1Chars: Child(c.GDExtensionInterfaceStringNewWithLatin1Chars),

/// @since 4.1
///
/// Creates a String from a UTF-8 encoded C string.
///
/// @param r_dest A pointer to a Variant to hold the newly created String.
/// @param p_contents A pointer to a UTF-8 encoded C string (null terminated).
stringNewWithUtf8Chars: Child(c.GDExtensionInterfaceStringNewWithUtf8Chars),

/// @since 4.1
///
/// Creates a String from a UTF-16 encoded C string.
///
/// @param r_dest A pointer to a Variant to hold the newly created String.
/// @param p_contents A pointer to a UTF-16 encoded C string (null terminated).
stringNewWithUtf16Chars: Child(c.GDExtensionInterfaceStringNewWithUtf16Chars),

/// @since 4.1
///
/// Creates a String from a UTF-32 encoded C string.
///
/// @param r_dest A pointer to a Variant to hold the newly created String.
/// @param p_contents A pointer to a UTF-32 encoded C string (null terminated).
stringNewWithUtf32Chars: Child(c.GDExtensionInterfaceStringNewWithUtf32Chars),

/// @since 4.1
///
/// Creates a String from a wide C string.
///
/// @param r_dest A pointer to a Variant to hold the newly created String.
/// @param p_contents A pointer to a wide C string (null terminated).
stringNewWithWideChars: Child(c.GDExtensionInterfaceStringNewWithWideChars),

/// @since 4.1
///
/// Creates a String from a Latin-1 encoded C string with the given length.
///
/// @param r_dest A pointer to a Variant to hold the newly created String.
/// @param p_contents A pointer to a Latin-1 encoded C string.
/// @param p_size The number of characters (= number of bytes).
stringNewWithLatin1CharsAndLen: Child(c.GDExtensionInterfaceStringNewWithLatin1CharsAndLen),

/// @since 4.1
/// @deprecated in Godot 4.3. Use `string_new_with_utf8_chars_and_len2` instead.
///
/// Creates a String from a UTF-8 encoded C string with the given length.
///
/// @param r_dest A pointer to a Variant to hold the newly created String.
/// @param p_contents A pointer to a UTF-8 encoded C string.
/// @param p_size The number of bytes (not code units).
stringNewWithUtf8CharsAndLen: Child(c.GDExtensionInterfaceStringNewWithUtf8CharsAndLen),

/// @since 4.3
///
/// Creates a String from a UTF-8 encoded C string with the given length.
///
/// @param r_dest A pointer to a Variant to hold the newly created String.
/// @param p_contents A pointer to a UTF-8 encoded C string.
/// @param p_size The number of bytes (not code units).
///
/// @return Error code signifying if the operation successful.
stringNewWithUtf8CharsAndLen2: Child(c.GDExtensionInterfaceStringNewWithUtf8CharsAndLen2),

/// @since 4.1
/// @deprecated in Godot 4.3. Use `string_new_with_utf16_chars_and_len2` instead.
///
/// Creates a String from a UTF-16 encoded C string with the given length.
///
/// @param r_dest A pointer to a Variant to hold the newly created String.
/// @param p_contents A pointer to a UTF-16 encoded C string.
/// @param p_size The number of characters (not bytes).
stringNewWithUtf16CharsAndLen: Child(c.GDExtensionInterfaceStringNewWithUtf16CharsAndLen),

/// @since 4.3
///
/// Creates a String from a UTF-16 encoded C string with the given length.
///
/// @param r_dest A pointer to a Variant to hold the newly created String.
/// @param p_contents A pointer to a UTF-16 encoded C string.
/// @param p_size The number of characters (not bytes).
/// @param p_default_little_endian If true, UTF-16 use little endian.
///
/// @return Error code signifying if the operation successful.
stringNewWithUtf16CharsAndLen2: Child(c.GDExtensionInterfaceStringNewWithUtf16CharsAndLen2),

/// @since 4.1
///
/// Creates a String from a UTF-32 encoded C string with the given length.
///
/// @param r_dest A pointer to a Variant to hold the newly created String.
/// @param p_contents A pointer to a UTF-32 encoded C string.
/// @param p_size The number of characters (not bytes).
stringNewWithUtf32CharsAndLen: Child(c.GDExtensionInterfaceStringNewWithUtf32CharsAndLen),

/// @since 4.1
///
/// Creates a String from a wide C string with the given length.
///
/// @param r_dest A pointer to a Variant to hold the newly created String.
/// @param p_contents A pointer to a wide C string.
/// @param p_size The number of characters (not bytes).
stringNewWithWideCharsAndLen: Child(c.GDExtensionInterfaceStringNewWithWideCharsAndLen),

/// @since 4.1
///
/// Converts a String to a Latin-1 encoded C string.
///
/// It doesn't write a null terminator.
///
/// @param p_self A pointer to the String.
/// @param r_text A pointer to the buffer to hold the resulting data. If NULL is passed in, only the length will be computed.
/// @param p_max_write_length The maximum number of characters that can be written to r_text. It has no affect on the return value.
///
/// @return The resulting encoded string length in characters (not bytes), not including a null terminator.
stringToLatin1Chars: Child(c.GDExtensionInterfaceStringToLatin1Chars),

/// @since 4.1
///
/// Converts a String to a UTF-8 encoded C string.
///
/// It doesn't write a null terminator.
///
/// @param p_self A pointer to the String.
/// @param r_text A pointer to the buffer to hold the resulting data. If NULL is passed in, only the length will be computed.
/// @param p_max_write_length The maximum number of characters that can be written to r_text. It has no affect on the return value.
///
/// @return The resulting encoded string length in characters (not bytes), not including a null terminator.
stringToUtf8Chars: Child(c.GDExtensionInterfaceStringToUtf8Chars),

/// @since 4.1
///
/// Converts a String to a UTF-16 encoded C string.
///
/// It doesn't write a null terminator.
///
/// @param p_self A pointer to the String.
/// @param r_text A pointer to the buffer to hold the resulting data. If NULL is passed in, only the length will be computed.
/// @param p_max_write_length The maximum number of characters that can be written to r_text. It has no affect on the return value.
///
/// @return The resulting encoded string length in characters (not bytes), not including a null terminator.
stringToUtf16Chars: Child(c.GDExtensionInterfaceStringToUtf16Chars),

/// @since 4.1
///
/// Converts a String to a UTF-32 encoded C string.
///
/// It doesn't write a null terminator.
///
/// @param p_self A pointer to the String.
/// @param r_text A pointer to the buffer to hold the resulting data. If NULL is passed in, only the length will be computed.
/// @param p_max_write_length The maximum number of characters that can be written to r_text. It has no affect on the return value.
///
/// @return The resulting encoded string length in characters (not bytes), not including a null terminator.
stringToUtf32Chars: Child(c.GDExtensionInterfaceStringToUtf32Chars),

/// @since 4.1
///
/// Converts a String to a wide C string.
///
/// It doesn't write a null terminator.
///
/// @param p_self A pointer to the String.
/// @param r_text A pointer to the buffer to hold the resulting data. If NULL is passed in, only the length will be computed.
/// @param p_max_write_length The maximum number of characters that can be written to r_text. It has no affect on the return value.
///
/// @return The resulting encoded string length in characters (not bytes), not including a null terminator.
stringToWideChars: Child(c.GDExtensionInterfaceStringToWideChars),

/// @since 4.1
///
/// Gets a pointer to the character at the given index from a String.
///
/// @param p_self A pointer to the String.
/// @param p_index The index.
///
/// @return A pointer to the requested character.
stringOperatorIndex: Child(c.GDExtensionInterfaceStringOperatorIndex),

/// @since 4.1
///
/// Gets a const pointer to the character at the given index from a String.
///
/// @param p_self A pointer to the String.
/// @param p_index The index.
///
/// @return A const pointer to the requested character.
stringOperatorIndexConst: Child(c.GDExtensionInterfaceStringOperatorIndexConst),

/// @since 4.1
///
/// Appends another String to a String.
///
/// @param p_self A pointer to the String.
/// @param p_b A pointer to the other String to append.
stringOperatorPlusEqString: Child(c.GDExtensionInterfaceStringOperatorPlusEqString),

/// @since 4.1
///
/// Appends a character to a String.
///
/// @param p_self A pointer to the String.
/// @param p_b A pointer to the character to append.
stringOperatorPlusEqChar: Child(c.GDExtensionInterfaceStringOperatorPlusEqChar),

/// @since 4.1
///
/// Appends a Latin-1 encoded C string to a String.
///
/// @param p_self A pointer to the String.
/// @param p_b A pointer to a Latin-1 encoded C string (null terminated).
stringOperatorPlusEqCstr: Child(c.GDExtensionInterfaceStringOperatorPlusEqCstr),

/// @since 4.1
///
/// Appends a wide C string to a String.
///
/// @param p_self A pointer to the String.
/// @param p_b A pointer to a wide C string (null terminated).
stringOperatorPlusEqWcstr: Child(c.GDExtensionInterfaceStringOperatorPlusEqWcstr),

/// @since 4.1
///
/// Appends a UTF-32 encoded C string to a String.
///
/// @param p_self A pointer to the String.
/// @param p_b A pointer to a UTF-32 encoded C string (null terminated).
stringOperatorPlusEqC32str: Child(c.GDExtensionInterfaceStringOperatorPlusEqC32str),

/// @since 4.2
///
/// Resizes the underlying string data to the given number of characters.
///
/// Space needs to be allocated for the null terminating character ('\0') which
/// also must be added manually, in order for all string functions to work correctly.
///
/// Warning: This is an error-prone operation - only use it if there's no other
/// efficient way to accomplish your goal.
///
/// @param p_self A pointer to the String.
/// @param p_resize The new length for the String.
///
/// @return Error code signifying if the operation successful.
stringResize: Child(c.GDExtensionInterfaceStringResize),

/// @since 4.2
///
/// Creates a StringName from a Latin-1 encoded C string.
///
/// If `p_is_static` is true, then:
/// - The StringName will reuse the `p_contents` buffer instead of copying it.
///   You must guarantee that the buffer remains valid for the duration of the application (e.g. string literal).
/// - You must not call a destructor for this StringName. Incrementing the initial reference once should achieve this.
///
/// `p_is_static` is purely an optimization and can easily introduce undefined behavior if used wrong. In case of doubt, set it to false.
///
/// @param r_dest A pointer to uninitialized storage, into which the newly created StringName is constructed.
/// @param p_contents A pointer to a C string (null terminated and Latin-1 or ASCII encoded).
/// @param p_is_static Whether the StringName reuses the buffer directly (see above).
stringNameNewWithLatin1Chars: Child(c.GDExtensionInterfaceStringNameNewWithLatin1Chars),

/// @since 4.2
///
/// Creates a StringName from a UTF-8 encoded C string.
///
/// @param r_dest A pointer to uninitialized storage, into which the newly created StringName is constructed.
/// @param p_contents A pointer to a C string (null terminated and UTF-8 encoded).
stringNameNewWithUtf8Chars: Child(c.GDExtensionInterfaceStringNameNewWithUtf8Chars),

/// @since 4.2
///
/// Creates a StringName from a UTF-8 encoded string with a given number of characters.
///
/// @param r_dest A pointer to uninitialized storage, into which the newly created StringName is constructed.
/// @param p_contents A pointer to a C string (null terminated and UTF-8 encoded).
/// @param p_size The number of bytes (not UTF-8 code points).
stringNameNewWithUtf8CharsAndLen: Child(c.GDExtensionInterfaceStringNameNewWithUtf8CharsAndLen),

/// @since 4.1
///
/// Opens a raw XML buffer on an XMLParser instance.
///
/// @param p_instance A pointer to an XMLParser object.
/// @param p_buffer A pointer to the buffer.
/// @param p_size The size of the buffer.
///
/// @return A Godot error code (ex. OK, ERR_INVALID_DATA, etc).
///
/// @see XMLParser::open_buffer()
xmlParserOpenBuffer: Child(c.GDExtensionInterfaceXmlParserOpenBuffer),

/// @since 4.1
///
/// Stores the given buffer using an instance of FileAccess.
///
/// @param p_instance A pointer to a FileAccess object.
/// @param p_src A pointer to the buffer.
/// @param p_length The size of the buffer.
///
/// @see FileAccess::store_buffer()
fileAccessStoreBuffer: Child(c.GDExtensionInterfaceFileAccessStoreBuffer),

/// @since 4.1
///
/// Reads the next p_length bytes into the given buffer using an instance of FileAccess.
///
/// @param p_instance A pointer to a FileAccess object.
/// @param p_dst A pointer to the buffer to store the data.
/// @param p_length The requested number of bytes to read.
///
/// @return The actual number of bytes read (may be less than requested).
fileAccessGetBuffer: Child(c.GDExtensionInterfaceFileAccessGetBuffer),

/// @since 4.3
///
/// Returns writable pointer to internal Image buffer.
///
/// @param p_instance A pointer to a Image object.
///
/// @return Pointer to internal Image buffer.
///
/// @see Image::ptrw()
imagePtrw: Child(c.GDExtensionInterfaceImagePtrw),

/// @since 4.3
///
/// Returns read only pointer to internal Image buffer.
///
/// @param p_instance A pointer to a Image object.
///
/// @return Pointer to internal Image buffer.
///
/// @see Image::ptr()
imagePtr: Child(c.GDExtensionInterfaceImagePtr),

/// @since 4.1
///
/// Adds a group task to an instance of WorkerThreadPool.
///
/// @param p_instance A pointer to a WorkerThreadPool object.
/// @param p_func A pointer to a function to run in the thread pool.
/// @param p_userdata A pointer to arbitrary data which will be passed to p_func.
/// @param p_tasks The number of tasks needed in the group.
/// @param p_high_priority Whether or not this is a high priority task.
/// @param p_description A pointer to a String with the task description.
///
/// @return The task group ID.
///
/// @see WorkerThreadPool::add_group_task()
workerThreadPoolAddNativeGroupTask: Child(c.GDExtensionInterfaceWorkerThreadPoolAddNativeGroupTask),

/// @since 4.1
///
/// Adds a task to an instance of WorkerThreadPool.
///
/// @param p_instance A pointer to a WorkerThreadPool object.
/// @param p_func A pointer to a function to run in the thread pool.
/// @param p_userdata A pointer to arbitrary data which will be passed to p_func.
/// @param p_high_priority Whether or not this is a high priority task.
/// @param p_description A pointer to a String with the task description.
///
/// @return The task ID.
workerThreadPoolAddNativeTask: Child(c.GDExtensionInterfaceWorkerThreadPoolAddNativeTask),

/// @since 4.1
///
/// Gets a pointer to a byte in a PackedByteArray.
///
/// @param p_self A pointer to a PackedByteArray object.
/// @param p_index The index of the byte to get.
///
/// @return A pointer to the requested byte.
packedByteArrayOperatorIndex: Child(c.GDExtensionInterfacePackedByteArrayOperatorIndex),

/// @since 4.1
///
/// Gets a const pointer to a byte in a PackedByteArray.
///
/// @param p_self A const pointer to a PackedByteArray object.
/// @param p_index The index of the byte to get.
///
/// @return A const pointer to the requested byte.
packedByteArrayOperatorIndexConst: Child(c.GDExtensionInterfacePackedByteArrayOperatorIndexConst),

/// @since 4.1
///
/// Gets a pointer to a 32-bit float in a PackedFloat32Array.
///
/// @param p_self A pointer to a PackedFloat32Array object.
/// @param p_index The index of the float to get.
///
/// @return A pointer to the requested 32-bit float.
packedFloat32ArrayOperatorIndex: Child(c.GDExtensionInterfacePackedFloat32ArrayOperatorIndex),

/// @since 4.1
///
/// Gets a const pointer to a 32-bit float in a PackedFloat32Array.
///
/// @param p_self A const pointer to a PackedFloat32Array object.
/// @param p_index The index of the float to get.
///
/// @return A const pointer to the requested 32-bit float.
packedFloat32ArrayOperatorIndexConst: Child(c.GDExtensionInterfacePackedFloat32ArrayOperatorIndexConst),

/// @since 4.1
///
/// Gets a pointer to a 64-bit float in a PackedFloat64Array.
///
/// @param p_self A pointer to a PackedFloat64Array object.
/// @param p_index The index of the float to get.
///
/// @return A pointer to the requested 64-bit float.
packedFloat64ArrayOperatorIndex: Child(c.GDExtensionInterfacePackedFloat64ArrayOperatorIndex),

/// @since 4.1
///
/// Gets a const pointer to a 64-bit float in a PackedFloat64Array.
///
/// @param p_self A const pointer to a PackedFloat64Array object.
/// @param p_index The index of the float to get.
///
/// @return A const pointer to the requested 64-bit float.
packedFloat64ArrayOperatorIndexConst: Child(c.GDExtensionInterfacePackedFloat64ArrayOperatorIndexConst),

/// @since 4.1
///
/// Gets a pointer to a 32-bit integer in a PackedInt32Array.
///
/// @param p_self A pointer to a PackedInt32Array object.
/// @param p_index The index of the integer to get.
///
/// @return A pointer to the requested 32-bit integer.
packedInt32ArrayOperatorIndex: Child(c.GDExtensionInterfacePackedInt32ArrayOperatorIndex),

/// @since 4.1
///
/// Gets a const pointer to a 32-bit integer in a PackedInt32Array.
///
/// @param p_self A const pointer to a PackedInt32Array object.
/// @param p_index The index of the integer to get.
///
/// @return A const pointer to the requested 32-bit integer.
packedInt32ArrayOperatorIndexConst: Child(c.GDExtensionInterfacePackedInt32ArrayOperatorIndexConst),

/// @since 4.1
///
/// Gets a pointer to a 64-bit integer in a PackedInt64Array.
///
/// @param p_self A pointer to a PackedInt64Array object.
/// @param p_index The index of the integer to get.
///
/// @return A pointer to the requested 64-bit integer.
packedInt64ArrayOperatorIndex: Child(c.GDExtensionInterfacePackedInt64ArrayOperatorIndex),

/// @since 4.1
///
/// Gets a const pointer to a 64-bit integer in a PackedInt64Array.
///
/// @param p_self A const pointer to a PackedInt64Array object.
/// @param p_index The index of the integer to get.
///
/// @return A const pointer to the requested 64-bit integer.
packedInt64ArrayOperatorIndexConst: Child(c.GDExtensionInterfacePackedInt64ArrayOperatorIndexConst),

/// @since 4.1
///
/// Gets a pointer to a string in a PackedStringArray.
///
/// @param p_self A pointer to a PackedStringArray object.
/// @param p_index The index of the String to get.
///
/// @return A pointer to the requested String.
packedStringArrayOperatorIndex: Child(c.GDExtensionInterfacePackedStringArrayOperatorIndex),

/// @since 4.1
///
/// Gets a const pointer to a string in a PackedStringArray.
///
/// @param p_self A const pointer to a PackedStringArray object.
/// @param p_index The index of the String to get.
///
/// @return A const pointer to the requested String.
packedStringArrayOperatorIndexConst: Child(c.GDExtensionInterfacePackedStringArrayOperatorIndexConst),

/// @since 4.1
///
/// Gets a pointer to a Vector2 in a PackedVector2Array.
///
/// @param p_self A pointer to a PackedVector2Array object.
/// @param p_index The index of the Vector2 to get.
///
/// @return A pointer to the requested Vector2.
packedVector2ArrayOperatorIndex: Child(c.GDExtensionInterfacePackedVector2ArrayOperatorIndex),

/// @since 4.1
///
/// Gets a const pointer to a Vector2 in a PackedVector2Array.
///
/// @param p_self A const pointer to a PackedVector2Array object.
/// @param p_index The index of the Vector2 to get.
///
/// @return A const pointer to the requested Vector2.
packedVector2ArrayOperatorIndexConst: Child(c.GDExtensionInterfacePackedVector2ArrayOperatorIndexConst),

/// @since 4.1
///
/// Gets a pointer to a Vector3 in a PackedVector3Array.
///
/// @param p_self A pointer to a PackedVector3Array object.
/// @param p_index The index of the Vector3 to get.
///
/// @return A pointer to the requested Vector3.
packedVector3ArrayOperatorIndex: Child(c.GDExtensionInterfacePackedVector3ArrayOperatorIndex),

/// @since 4.1
///
/// Gets a const pointer to a Vector3 in a PackedVector3Array.
///
/// @param p_self A const pointer to a PackedVector3Array object.
/// @param p_index The index of the Vector3 to get.
///
/// @return A const pointer to the requested Vector3.
packedVector3ArrayOperatorIndexConst: Child(c.GDExtensionInterfacePackedVector3ArrayOperatorIndexConst),

/// @since 4.3
///
/// Gets a pointer to a Vector4 in a PackedVector4Array.
///
/// @param p_self A pointer to a PackedVector4Array object.
/// @param p_index The index of the Vector4 to get.
///
/// @return A pointer to the requested Vector4.
packedVector4ArrayOperatorIndex: Child(c.GDExtensionInterfacePackedVector4ArrayOperatorIndex),

/// @since 4.3
///
/// Gets a const pointer to a Vector4 in a PackedVector4Array.
///
/// @param p_self A const pointer to a PackedVector4Array object.
/// @param p_index The index of the Vector4 to get.
///
/// @return A const pointer to the requested Vector4.
packedVector4ArrayOperatorIndexConst: Child(c.GDExtensionInterfacePackedVector4ArrayOperatorIndexConst),

/// @since 4.1
///
/// Gets a pointer to a color in a PackedColorArray.
///
/// @param p_self A pointer to a PackedColorArray object.
/// @param p_index The index of the Color to get.
///
/// @return A pointer to the requested Color.
packedColorArrayOperatorIndex: Child(c.GDExtensionInterfacePackedColorArrayOperatorIndex),

/// @since 4.1
///
/// Gets a const pointer to a color in a PackedColorArray.
///
/// @param p_self A const pointer to a PackedColorArray object.
/// @param p_index The index of the Color to get.
///
/// @return A const pointer to the requested Color.
packedColorArrayOperatorIndexConst: Child(c.GDExtensionInterfacePackedColorArrayOperatorIndexConst),

/// @since 4.1
///
/// Gets a pointer to a Variant in an Array.
///
/// @param p_self A pointer to an Array object.
/// @param p_index The index of the Variant to get.
///
/// @return A pointer to the requested Variant.
arrayOperatorIndex: Child(c.GDExtensionInterfaceArrayOperatorIndex),

/// @since 4.1
///
/// Gets a const pointer to a Variant in an Array.
///
/// @param p_self A const pointer to an Array object.
/// @param p_index The index of the Variant to get.
///
/// @return A const pointer to the requested Variant.
arrayOperatorIndexConst: Child(c.GDExtensionInterfaceArrayOperatorIndexConst),

/// @since 4.1
///
/// Sets an Array to be a reference to another Array object.
///
/// @param p_self A pointer to the Array object to update.
/// @param p_from A pointer to the Array object to reference.
arrayRef: Child(c.GDExtensionInterfaceArrayRef),

/// @since 4.1
///
/// Makes an Array into a typed Array.
///
/// @param p_self A pointer to the Array.
/// @param p_type The type of Variant the Array will store.
/// @param p_class_name A pointer to a StringName with the name of the object (if p_type is GDEXTENSION_VARIANT_TYPE_OBJECT).
/// @param p_script A pointer to a Script object (if p_type is GDEXTENSION_VARIANT_TYPE_OBJECT and the base class is extended by a script).
arraySetTyped: Child(c.GDExtensionInterfaceArraySetTyped),

/// @since 4.1
///
/// Gets a pointer to a Variant in a Dictionary with the given key.
///
/// @param p_self A pointer to a Dictionary object.
/// @param p_key A pointer to a Variant representing the key.
///
/// @return A pointer to a Variant representing the value at the given key.
dictionaryOperatorIndex: Child(c.GDExtensionInterfaceDictionaryOperatorIndex),

/// @since 4.1
///
/// Gets a const pointer to a Variant in a Dictionary with the given key.
///
/// @param p_self A const pointer to a Dictionary object.
/// @param p_key A pointer to a Variant representing the key.
///
/// @return A const pointer to a Variant representing the value at the given key.
dictionaryOperatorIndexConst: Child(c.GDExtensionInterfaceDictionaryOperatorIndexConst),

/// @since 4.4
///
/// Makes a Dictionary into a typed Dictionary.
///
/// @param p_self A pointer to the Dictionary.
/// @param p_key_type The type of Variant the Dictionary key will store.
/// @param p_key_class_name A pointer to a StringName with the name of the object (if p_key_type is GDEXTENSION_VARIANT_TYPE_OBJECT).
/// @param p_key_script A pointer to a Script object (if p_key_type is GDEXTENSION_VARIANT_TYPE_OBJECT and the base class is extended by a script).
/// @param p_value_type The type of Variant the Dictionary value will store.
/// @param p_value_class_name A pointer to a StringName with the name of the object (if p_value_type is GDEXTENSION_VARIANT_TYPE_OBJECT).
/// @param p_value_script A pointer to a Script object (if p_value_type is GDEXTENSION_VARIANT_TYPE_OBJECT and the base class is extended by a script).
dictionarySetTyped: Child(c.GDExtensionInterfaceDictionarySetTyped),

/// @since 4.1
///
/// Calls a method on an Object.
///
/// @param p_method_bind A pointer to the MethodBind representing the method on the Object's class.
/// @param p_instance A pointer to the Object.
/// @param p_args A pointer to a C array of Variants representing the arguments.
/// @param p_arg_count The number of arguments.
/// @param r_ret A pointer to Variant which will receive the return value.
/// @param r_error A pointer to a GDExtensionCallError struct that will receive error information.
objectMethodBindCall: Child(c.GDExtensionInterfaceObjectMethodBindCall),

/// @since 4.1
///
/// Calls a method on an Object (using a "ptrcall").
///
/// @param p_method_bind A pointer to the MethodBind representing the method on the Object's class.
/// @param p_instance A pointer to the Object.
/// @param p_args A pointer to a C array representing the arguments.
/// @param r_ret A pointer to the Object that will receive the return value.
objectMethodBindPtrcall: Child(c.GDExtensionInterfaceObjectMethodBindPtrcall),

/// @since 4.1
///
/// Destroys an Object.
///
/// @param p_o A pointer to the Object.
objectDestroy: Child(c.GDExtensionInterfaceObjectDestroy),

/// @since 4.1
///
/// Gets a global singleton by name.
///
/// @param p_name A pointer to a StringName with the singleton name.
///
/// @return A pointer to the singleton Object.
globalGetSingleton: Child(c.GDExtensionInterfaceGlobalGetSingleton),

/// @since 4.1
///
/// Gets a pointer representing an Object's instance binding.
///
/// @param p_o A pointer to the Object.
/// @param p_library A token the library received by the GDExtension's entry point function.
/// @param p_callbacks A pointer to a GDExtensionInstanceBindingCallbacks struct.
///
/// @return
objectGetInstanceBinding: Child(c.GDExtensionInterfaceObjectGetInstanceBinding),

/// @since 4.1
///
/// Sets an Object's instance binding.
///
/// @param p_o A pointer to the Object.
/// @param p_library A token the library received by the GDExtension's entry point function.
/// @param p_binding A pointer to the instance binding.
/// @param p_callbacks A pointer to a GDExtensionInstanceBindingCallbacks struct.
objectSetInstanceBinding: Child(c.GDExtensionInterfaceObjectSetInstanceBinding),

/// @since 4.2
///
/// Free an Object's instance binding.
///
/// @param p_o A pointer to the Object.
/// @param p_library A token the library received by the GDExtension's entry point function.
objectFreeInstanceBinding: Child(c.GDExtensionInterfaceObjectFreeInstanceBinding),

/// e
objectSetInstance: Child(c.GDExtensionInterfaceObjectSetInstance),

/// @since 4.1
///
/// Gets the class name of an Object.
///
/// If the GDExtension wraps the Godot object in an abstraction specific to its class, this is the
/// function that should be used to determine which wrapper to use.
///
/// @param p_object A pointer to the Object.
/// @param p_library A pointer the library received by the GDExtension's entry point function.
/// @param r_class_name A pointer to a String to receive the class name.
///
/// @return true if successful in getting the class name; otherwise false.
objectGetClassName: Child(c.GDExtensionInterfaceObjectGetClassName),

/// @since 4.1
///
/// Casts an Object to a different type.
///
/// @param p_object A pointer to the Object.
/// @param p_class_tag A pointer uniquely identifying a built-in class in the ClassDB.
///
/// @return Returns a pointer to the Object, or NULL if it can't be cast to the requested type.
objectCastTo: Child(c.GDExtensionInterfaceObjectCastTo),

/// @since 4.1
///
/// Gets an Object by its instance ID.
///
/// @param p_instance_id The instance ID.
///
/// @return A pointer to the Object.
objectGetInstanceFromId: Child(c.GDExtensionInterfaceObjectGetInstanceFromId),

/// @since 4.1
///
/// Gets the instance ID from an Object.
///
/// @param p_object A pointer to the Object.
///
/// @return The instance ID.
objectGetInstanceId: Child(c.GDExtensionInterfaceObjectGetInstanceId),

/// @since 4.3
///
/// Checks if this object has a script with the given method.
///
/// @param p_object A pointer to the Object.
/// @param p_method A pointer to a StringName identifying the method.
///
/// @returns true if the object has a script and that script has a method with the given name. Returns false if the object has no script.
objectHasScriptMethod: Child(c.GDExtensionInterfaceObjectHasScriptMethod),

/// @since 4.3
///
/// Call the given script method on this object.
///
/// @param p_object A pointer to the Object.
/// @param p_method A pointer to a StringName identifying the method.
/// @param p_args A pointer to a C array of Variant.
/// @param p_argument_count The number of arguments.
/// @param r_return A pointer a Variant which will be assigned the return value.
/// @param r_error A pointer the structure which will hold error information.
objectCallScriptMethod: Child(c.GDExtensionInterfaceObjectCallScriptMethod),

/// @since 4.1
///
/// Gets the Object from a reference.
///
/// @param p_ref A pointer to the reference.
///
/// @return A pointer to the Object from the reference or NULL.
refGetObject: Child(c.GDExtensionInterfaceRefGetObject),

/// @since 4.1
///
/// Sets the Object referred to by a reference.
///
/// @param p_ref A pointer to the reference.
/// @param p_object A pointer to the Object to refer to.
refSetObject: Child(c.GDExtensionInterfaceRefSetObject),

/// @since 4.1
/// @deprecated in Godot 4.2. Use `script_instance_create3` instead.
///
/// Creates a script instance that contains the given info and instance data.
///
/// @param p_info A pointer to a GDExtensionScriptInstanceInfo struct.
/// @param p_instance_data A pointer to a data representing the script instance in the GDExtension. This will be passed to all the function pointers on p_info.
///
/// @return A pointer to a ScriptInstanceExtension object.
scriptInstanceCreate: Child(c.GDExtensionInterfaceScriptInstanceCreate),

/// @since 4.2
/// @deprecated in Godot 4.3. Use `script_instance_create3` instead.
///
/// Creates a script instance that contains the given info and instance data.
///
/// @param p_info A pointer to a GDExtensionScriptInstanceInfo2 struct.
/// @param p_instance_data A pointer to a data representing the script instance in the GDExtension. This will be passed to all the function pointers on p_info.
///
/// @return A pointer to a ScriptInstanceExtension object.
scriptInstanceCreate2: Child(c.GDExtensionInterfaceScriptInstanceCreate2),

/// @since 4.3
///
/// Creates a script instance that contains the given info and instance data.
///
/// @param p_info A pointer to a GDExtensionScriptInstanceInfo3 struct.
/// @param p_instance_data A pointer to a data representing the script instance in the GDExtension. This will be passed to all the function pointers on p_info.
///
/// @return A pointer to a ScriptInstanceExtension object.
scriptInstanceCreate3: Child(c.GDExtensionInterfaceScriptInstanceCreate3),

/// @since 4.2
///
/// Creates a placeholder script instance for a given script and instance.
///
/// This interface is optional as a custom placeholder could also be created with script_instance_create().
///
/// @param p_language A pointer to a ScriptLanguage.
/// @param p_script A pointer to a Script.
/// @param p_owner A pointer to an Object.
///
/// @return A pointer to a PlaceHolderScriptInstance object.
placeholderScriptInstanceCreate: Child(c.GDExtensionInterfacePlaceHolderScriptInstanceCreate),

/// @since 4.2
///
/// Updates a placeholder script instance with the given properties and values.
///
/// The passed in placeholder must be an instance of PlaceHolderScriptInstance
/// such as the one returned by placeholder_script_instance_create().
///
/// @param p_placeholder A pointer to a PlaceHolderScriptInstance.
/// @param p_properties A pointer to an Array of Dictionary representing PropertyInfo.
/// @param p_values A pointer to a Dictionary mapping StringName to Variant values.
placeholderScriptInstanceUpdate: Child(c.GDExtensionInterfacePlaceHolderScriptInstanceUpdate),

/// @since 4.2
///
/// Get the script instance data attached to this object.
///
/// @param p_object A pointer to the Object.
/// @param p_language A pointer to the language expected for this script instance.
///
/// @return A GDExtensionScriptInstanceDataPtr that was attached to this object as part of script_instance_create.
objectGetScriptInstance: Child(c.GDExtensionInterfaceObjectGetScriptInstance),

/// @since 4.2
/// @deprecated in Godot 4.3. Use `callable_custom_create2` instead.
///
/// Creates a custom Callable object from a function pointer.
///
/// Provided struct can be safely freed once the function returns.
///
/// @param r_callable A pointer that will receive the new Callable.
/// @param p_callable_custom_info The info required to construct a Callable.
callableCustomCreate: Child(c.GDExtensionInterfaceCallableCustomCreate),

/// @since 4.3
///
/// Creates a custom Callable object from a function pointer.
///
/// Provided struct can be safely freed once the function returns.
///
/// @param r_callable A pointer that will receive the new Callable.
/// @param p_callable_custom_info The info required to construct a Callable.
callableCustomCreate2: Child(c.GDExtensionInterfaceCallableCustomCreate2),

/// @since 4.2
///
/// Retrieves the userdata pointer from a custom Callable.
///
/// If the Callable is not a custom Callable or the token does not match the one provided to callable_custom_create() via GDExtensionCallableCustomInfo then NULL will be returned.
///
/// @param p_callable A pointer to a Callable.
/// @param p_token A pointer to an address that uniquely identifies the GDExtension.
callableCustomGetUserdata: Child(c.GDExtensionInterfaceCallableCustomGetUserData),

/// @since 4.1
/// @deprecated in Godot 4.4. Use `classdb_construct_object2` instead.
///
/// Constructs an Object of the requested class.
///
/// The passed class must be a built-in godot class, or an already-registered extension class. In both cases, object_set_instance() should be called to fully initialize the object.
///
/// @param p_classname A pointer to a StringName with the class name.
///
/// @return A pointer to the newly created Object.
classdbConstructObject: Child(c.GDExtensionInterfaceClassdbConstructObject),

/// @since 4.4
///
/// Constructs an Object of the requested class.
///
/// The passed class must be a built-in godot class, or an already-registered extension class. In both cases, object_set_instance() should be called to fully initialize the object.
///
/// "NOTIFICATION_POSTINITIALIZE" must be sent after construction.
///
/// @param p_classname A pointer to a StringName with the class name.
///
/// @return A pointer to the newly created Object.
classdbConstructObject2: Child(c.GDExtensionInterfaceClassdbConstructObject2),

/// @since 4.1
///
/// Gets a pointer to the MethodBind in ClassDB for the given class, method and hash.
///
/// @param p_classname A pointer to a StringName with the class name.
/// @param p_methodname A pointer to a StringName with the method name.
/// @param p_hash A hash representing the function signature.
///
/// @return A pointer to the MethodBind from ClassDB.
classdbGetMethodBind: Child(c.GDExtensionInterfaceClassdbGetMethodBind),

/// @since 4.1
///
/// Gets a pointer uniquely identifying the given built-in class in the ClassDB.
///
/// @param p_classname A pointer to a StringName with the class name.
///
/// @return A pointer uniquely identifying the built-in class in the ClassDB.
classdbGetClassTag: Child(c.GDExtensionInterfaceClassdbGetClassTag),

/// @since 4.1
/// @deprecated in Godot 4.2. Use `classdb_register_extension_class4` instead.
///
/// Registers an extension class in the ClassDB.
///
/// Provided struct can be safely freed once the function returns.
///
/// @param p_library A pointer the library received by the GDExtension's entry point function.
/// @param p_class_name A pointer to a StringName with the class name.
/// @param p_parent_class_name A pointer to a StringName with the parent class name.
/// @param p_extension_funcs A pointer to a GDExtensionClassCreationInfo struct.
classdbRegisterExtensionClass: Child(c.GDExtensionInterfaceClassdbRegisterExtensionClass),

/// @since 4.2
/// @deprecated in Godot 4.3. Use `classdb_register_extension_class4` instead.
///
/// Registers an extension class in the ClassDB.
///
/// Provided struct can be safely freed once the function returns.
///
/// @param p_library A pointer the library received by the GDExtension's entry point function.
/// @param p_class_name A pointer to a StringName with the class name.
/// @param p_parent_class_name A pointer to a StringName with the parent class name.
/// @param p_extension_funcs A pointer to a GDExtensionClassCreationInfo2 struct.
classdbRegisterExtensionClass2: Child(c.GDExtensionInterfaceClassdbRegisterExtensionClass2),

/// @since 4.3
/// @deprecated in Godot 4.4. Use `classdb_register_extension_class4` instead.
///
/// Registers an extension class in the ClassDB.
///
/// Provided struct can be safely freed once the function returns.
///
/// @param p_library A pointer the library received by the GDExtension's entry point function.
/// @param p_class_name A pointer to a StringName with the class name.
/// @param p_parent_class_name A pointer to a StringName with the parent class name.
/// @param p_extension_funcs A pointer to a GDExtensionClassCreationInfo2 struct.
classdbRegisterExtensionClass3: Child(c.GDExtensionInterfaceClassdbRegisterExtensionClass3),

/// @since 4.4
///
/// Registers an extension class in the ClassDB.
///
/// Provided struct can be safely freed once the function returns.
///
/// @param p_library A pointer the library received by the GDExtension's entry point function.
/// @param p_class_name A pointer to a StringName with the class name.
/// @param p_parent_class_name A pointer to a StringName with the parent class name.
/// @param p_extension_funcs A pointer to a GDExtensionClassCreationInfo2 struct.
classdbRegisterExtensionClass4: Child(c.GDExtensionInterfaceClassdbRegisterExtensionClass4),

/// @since 4.1
///
/// Registers a method on an extension class in the ClassDB.
///
/// Provided struct can be safely freed once the function returns.
///
/// @param p_library A pointer the library received by the GDExtension's entry point function.
/// @param p_class_name A pointer to a StringName with the class name.
/// @param p_method_info A pointer to a GDExtensionClassMethodInfo struct.
classdbRegisterExtensionClassMethod: Child(c.GDExtensionInterfaceClassdbRegisterExtensionClassMethod),

/// @since 4.3
///
/// Registers a virtual method on an extension class in ClassDB, that can be implemented by scripts or other extensions.
///
/// Provided struct can be safely freed once the function returns.
///
/// @param p_library A pointer the library received by the GDExtension's entry point function.
/// @param p_class_name A pointer to a StringName with the class name.
/// @param p_method_info A pointer to a GDExtensionClassMethodInfo struct.
classdbRegisterExtensionClassVirtualMethod: Child(c.GDExtensionInterfaceClassdbRegisterExtensionClassVirtualMethod),

/// @since 4.1
///
/// Registers an integer constant on an extension class in the ClassDB.
///
/// Note about registering bitfield values (if p_is_bitfield is true): even though p_constant_value is signed, language bindings are
/// advised to treat bitfields as uint64_t, since this is generally clearer and can prevent mistakes like using -1 for setting all bits.
/// Language APIs should thus provide an abstraction that registers bitfields (uint64_t) separately from regular constants (int64_t).
///
/// @param p_library A pointer the library received by the GDExtension's entry point function.
/// @param p_class_name A pointer to a StringName with the class name.
/// @param p_enum_name A pointer to a StringName with the enum name.
/// @param p_constant_name A pointer to a StringName with the constant name.
/// @param p_constant_value The constant value.
/// @param p_is_bitfield Whether or not this constant is part of a bitfield.
classdbRegisterExtensionClassIntegerConstant: Child(c.GDExtensionInterfaceClassdbRegisterExtensionClassIntegerConstant),

/// @since 4.1
///
/// Registers a property on an extension class in the ClassDB.
///
/// Provided struct can be safely freed once the function returns.
///
/// @param p_library A pointer the library received by the GDExtension's entry point function.
/// @param p_class_name A pointer to a StringName with the class name.
/// @param p_info A pointer to a GDExtensionPropertyInfo struct.
/// @param p_setter A pointer to a StringName with the name of the setter method.
/// @param p_getter A pointer to a StringName with the name of the getter method.
classdbRegisterExtensionClassProperty: Child(c.GDExtensionInterfaceClassdbRegisterExtensionClassProperty),

/// @since 4.2
///
/// Registers an indexed property on an extension class in the ClassDB.
///
/// Provided struct can be safely freed once the function returns.
///
/// @param p_library A pointer the library received by the GDExtension's entry point function.
/// @param p_class_name A pointer to a StringName with the class name.
/// @param p_info A pointer to a GDExtensionPropertyInfo struct.
/// @param p_setter A pointer to a StringName with the name of the setter method.
/// @param p_getter A pointer to a StringName with the name of the getter method.
/// @param p_index The index to pass as the first argument to the getter and setter methods.
classdbRegisterExtensionClassPropertyIndexed: Child(c.GDExtensionInterfaceClassdbRegisterExtensionClassPropertyIndexed),

/// @since 4.1
///
/// Registers a property group on an extension class in the ClassDB.
///
/// @param p_library A pointer the library received by the GDExtension's entry point function.
/// @param p_class_name A pointer to a StringName with the class name.
/// @param p_group_name A pointer to a String with the group name.
/// @param p_prefix A pointer to a String with the prefix used by properties in this group.
classdbRegisterExtensionClassPropertyGroup: Child(c.GDExtensionInterfaceClassdbRegisterExtensionClassPropertyGroup),

/// @since 4.1
///
/// Registers a property subgroup on an extension class in the ClassDB.
///
/// @param p_library A pointer the library received by the GDExtension's entry point function.
/// @param p_class_name A pointer to a StringName with the class name.
/// @param p_subgroup_name A pointer to a String with the subgroup name.
/// @param p_prefix A pointer to a String with the prefix used by properties in this subgroup.
classdbRegisterExtensionClassPropertySubgroup: Child(c.GDExtensionInterfaceClassdbRegisterExtensionClassPropertySubgroup),

/// @since 4.1
///
/// Registers a signal on an extension class in the ClassDB.
///
/// Provided structs can be safely freed once the function returns.
///
/// @param p_library A pointer the library received by the GDExtension's entry point function.
/// @param p_class_name A pointer to a StringName with the class name.
/// @param p_signal_name A pointer to a StringName with the signal name.
/// @param p_argument_info A pointer to a GDExtensionPropertyInfo struct.
/// @param p_argument_count The number of arguments the signal receives.
classdbRegisterExtensionClassSignal: Child(c.GDExtensionInterfaceClassdbRegisterExtensionClassSignal),

/// e
classdbUnregisterExtensionClass: Child(c.GDExtensionInterfaceClassdbUnregisterExtensionClass),

/// @since 4.1
///
/// Gets the path to the current GDExtension library.
///
/// @param p_library A pointer the library received by the GDExtension's entry point function.
/// @param r_path A pointer to a String which will receive the path.
getLibraryPath: Child(c.GDExtensionInterfaceGetLibraryPath),

/// @since 4.1
///
/// Adds an editor plugin.
///
/// It's safe to call during initialization.
///
/// @param p_class_name A pointer to a StringName with the name of a class (descending from EditorPlugin) which is already registered with ClassDB.
editorAddPlugin: Child(c.GDExtensionInterfaceEditorAddPlugin),

/// @since 4.1
///
/// Removes an editor plugin.
///
/// @param p_class_name A pointer to a StringName with the name of a class that was previously added as an editor plugin.
editorRemovePlugin: Child(c.GDExtensionInterfaceEditorRemovePlugin),

/// @since 4.3
///
/// Loads new XML-formatted documentation data in the editor.
///
/// The provided pointer can be immediately freed once the function returns.
///
/// @param p_data A pointer to a UTF-8 encoded C string (null terminated).
editorHelpLoadXmlFromUtf8Chars: Child(c.GDExtensionsInterfaceEditorHelpLoadXmlFromUtf8Chars),

/// @since 4.3
///
/// Loads new XML-formatted documentation data in the editor.
///
/// The provided pointer can be immediately freed once the function returns.
///
/// @param p_data A pointer to a UTF-8 encoded C string.
/// @param p_size The number of bytes (not code units).
editorHelpLoadXmlFromUtf8CharsAndLen: Child(c.GDExtensionsInterfaceEditorHelpLoadXmlFromUtf8CharsAndLen),

pub fn init(getProcAddress: Child(c.GDExtensionInterfaceGetProcAddress), library: *ClassLibrary) Interface {
    const self: Interface = .{
        .library = library,
        .getGodotVersion = @ptrCast(getProcAddress("get_godot_version").?),
        .memAlloc = @ptrCast(getProcAddress("mem_alloc").?),
        .memRealloc = @ptrCast(getProcAddress("mem_realloc").?),
        .memFree = @ptrCast(getProcAddress("mem_free").?),
        .printError = @ptrCast(getProcAddress("print_error").?),
        .printErrorWithMessage = @ptrCast(getProcAddress("print_error_with_message").?),
        .printWarning = @ptrCast(getProcAddress("print_warning").?),
        .printWarningWithMessage = @ptrCast(getProcAddress("print_warning_with_message").?),
        .printScriptError = @ptrCast(getProcAddress("print_script_error").?),
        .printScriptErrorWithMessage = @ptrCast(getProcAddress("print_script_error_with_message").?),
        .getNativeStructSize = @ptrCast(getProcAddress("get_native_struct_size").?),
        .variantNewCopy = @ptrCast(getProcAddress("variant_new_copy").?),
        .variantNewNil = @ptrCast(getProcAddress("variant_new_nil").?),
        .variantDestroy = @ptrCast(getProcAddress("variant_destroy").?),
        .variantCall = @ptrCast(getProcAddress("variant_call").?),
        .variantCallStatic = @ptrCast(getProcAddress("variant_call_static").?),
        .variantEvaluate = @ptrCast(getProcAddress("variant_evaluate").?),
        .variantSet = @ptrCast(getProcAddress("variant_set").?),
        .variantSetNamed = @ptrCast(getProcAddress("variant_set_named").?),
        .variantSetKeyed = @ptrCast(getProcAddress("variant_set_keyed").?),
        .variantSetIndexed = @ptrCast(getProcAddress("variant_set_indexed").?),
        .variantGet = @ptrCast(getProcAddress("variant_get").?),
        .variantGetNamed = @ptrCast(getProcAddress("variant_get_named").?),
        .variantGetKeyed = @ptrCast(getProcAddress("variant_get_keyed").?),
        .variantGetIndexed = @ptrCast(getProcAddress("variant_get_indexed").?),
        .variantIterInit = @ptrCast(getProcAddress("variant_iter_init").?),
        .variantIterNext = @ptrCast(getProcAddress("variant_iter_next").?),
        .variantIterGet = @ptrCast(getProcAddress("variant_iter_get").?),
        .variantHash = @ptrCast(getProcAddress("variant_hash").?),
        .variantRecursiveHash = @ptrCast(getProcAddress("variant_recursive_hash").?),
        .variantHashCompare = @ptrCast(getProcAddress("variant_hash_compare").?),
        .variantBooleanize = @ptrCast(getProcAddress("variant_booleanize").?),
        .variantDuplicate = @ptrCast(getProcAddress("variant_duplicate").?),
        .variantStringify = @ptrCast(getProcAddress("variant_stringify").?),
        .variantGetType = @ptrCast(getProcAddress("variant_get_type").?),
        .variantHasMethod = @ptrCast(getProcAddress("variant_has_method").?),
        .variantHasMember = @ptrCast(getProcAddress("variant_has_member").?),
        .variantHasKey = @ptrCast(getProcAddress("variant_has_key").?),
        .variantGetObjectInstanceId = @ptrCast(getProcAddress("variant_get_object_instance_id").?),
        .variantGetTypeName = @ptrCast(getProcAddress("variant_get_type_name").?),
        .variantCanConvert = @ptrCast(getProcAddress("variant_can_convert").?),
        .variantCanConvertStrict = @ptrCast(getProcAddress("variant_can_convert_strict").?),
        .getVariantFromTypeConstructor = @ptrCast(getProcAddress("get_variant_from_type_constructor").?),
        .getVariantToTypeConstructor = @ptrCast(getProcAddress("get_variant_to_type_constructor").?),
        .variantGetPtrInternalGetter = @ptrCast(getProcAddress("variant_get_ptr_internal_getter").?),
        .variantGetPtrOperatorEvaluator = @ptrCast(getProcAddress("variant_get_ptr_operator_evaluator").?),
        .variantGetPtrBuiltinMethod = @ptrCast(getProcAddress("variant_get_ptr_builtin_method").?),
        .variantGetPtrConstructor = @ptrCast(getProcAddress("variant_get_ptr_constructor").?),
        .variantGetPtrDestructor = @ptrCast(getProcAddress("variant_get_ptr_destructor").?),
        .variantConstruct = @ptrCast(getProcAddress("variant_construct").?),
        .variantGetPtrSetter = @ptrCast(getProcAddress("variant_get_ptr_setter").?),
        .variantGetPtrGetter = @ptrCast(getProcAddress("variant_get_ptr_getter").?),
        .variantGetPtrIndexedSetter = @ptrCast(getProcAddress("variant_get_ptr_indexed_setter").?),
        .variantGetPtrIndexedGetter = @ptrCast(getProcAddress("variant_get_ptr_indexed_getter").?),
        .variantGetPtrKeyedSetter = @ptrCast(getProcAddress("variant_get_ptr_keyed_setter").?),
        .variantGetPtrKeyedGetter = @ptrCast(getProcAddress("variant_get_ptr_keyed_getter").?),
        .variantGetPtrKeyedChecker = @ptrCast(getProcAddress("variant_get_ptr_keyed_checker").?),
        .variantGetConstantValue = @ptrCast(getProcAddress("variant_get_constant_value").?),
        .variantGetPtrUtilityFunction = @ptrCast(getProcAddress("variant_get_ptr_utility_function").?),
        .stringNewWithLatin1Chars = @ptrCast(getProcAddress("string_new_with_latin1_chars").?),
        .stringNewWithUtf8Chars = @ptrCast(getProcAddress("string_new_with_utf8_chars").?),
        .stringNewWithUtf16Chars = @ptrCast(getProcAddress("string_new_with_utf16_chars").?),
        .stringNewWithUtf32Chars = @ptrCast(getProcAddress("string_new_with_utf32_chars").?),
        .stringNewWithWideChars = @ptrCast(getProcAddress("string_new_with_wide_chars").?),
        .stringNewWithLatin1CharsAndLen = @ptrCast(getProcAddress("string_new_with_latin1_chars_and_len").?),
        .stringNewWithUtf8CharsAndLen = @ptrCast(getProcAddress("string_new_with_utf8_chars_and_len").?),
        .stringNewWithUtf8CharsAndLen2 = @ptrCast(getProcAddress("string_new_with_utf8_chars_and_len2").?),
        .stringNewWithUtf16CharsAndLen = @ptrCast(getProcAddress("string_new_with_utf16_chars_and_len").?),
        .stringNewWithUtf16CharsAndLen2 = @ptrCast(getProcAddress("string_new_with_utf16_chars_and_len2").?),
        .stringNewWithUtf32CharsAndLen = @ptrCast(getProcAddress("string_new_with_utf32_chars_and_len").?),
        .stringNewWithWideCharsAndLen = @ptrCast(getProcAddress("string_new_with_wide_chars_and_len").?),
        .stringToLatin1Chars = @ptrCast(getProcAddress("string_to_latin1_chars").?),
        .stringToUtf8Chars = @ptrCast(getProcAddress("string_to_utf8_chars").?),
        .stringToUtf16Chars = @ptrCast(getProcAddress("string_to_utf16_chars").?),
        .stringToUtf32Chars = @ptrCast(getProcAddress("string_to_utf32_chars").?),
        .stringToWideChars = @ptrCast(getProcAddress("string_to_wide_chars").?),
        .stringOperatorIndex = @ptrCast(getProcAddress("string_operator_index").?),
        .stringOperatorIndexConst = @ptrCast(getProcAddress("string_operator_index_const").?),
        .stringOperatorPlusEqString = @ptrCast(getProcAddress("string_operator_plus_eq_string").?),
        .stringOperatorPlusEqChar = @ptrCast(getProcAddress("string_operator_plus_eq_char").?),
        .stringOperatorPlusEqCstr = @ptrCast(getProcAddress("string_operator_plus_eq_cstr").?),
        .stringOperatorPlusEqWcstr = @ptrCast(getProcAddress("string_operator_plus_eq_wcstr").?),
        .stringOperatorPlusEqC32str = @ptrCast(getProcAddress("string_operator_plus_eq_c32str").?),
        .stringResize = @ptrCast(getProcAddress("string_resize").?),
        .stringNameNewWithLatin1Chars = @ptrCast(getProcAddress("string_name_new_with_latin1_chars").?),
        .stringNameNewWithUtf8Chars = @ptrCast(getProcAddress("string_name_new_with_utf8_chars").?),
        .stringNameNewWithUtf8CharsAndLen = @ptrCast(getProcAddress("string_name_new_with_utf8_chars_and_len").?),
        .xmlParserOpenBuffer = @ptrCast(getProcAddress("xml_parser_open_buffer").?),
        .fileAccessStoreBuffer = @ptrCast(getProcAddress("file_access_store_buffer").?),
        .fileAccessGetBuffer = @ptrCast(getProcAddress("file_access_get_buffer").?),
        .imagePtrw = @ptrCast(getProcAddress("image_ptrw").?),
        .imagePtr = @ptrCast(getProcAddress("image_ptr").?),
        .workerThreadPoolAddNativeGroupTask = @ptrCast(getProcAddress("worker_thread_pool_add_native_group_task").?),
        .workerThreadPoolAddNativeTask = @ptrCast(getProcAddress("worker_thread_pool_add_native_task").?),
        .packedByteArrayOperatorIndex = @ptrCast(getProcAddress("packed_byte_array_operator_index").?),
        .packedByteArrayOperatorIndexConst = @ptrCast(getProcAddress("packed_byte_array_operator_index_const").?),
        .packedFloat32ArrayOperatorIndex = @ptrCast(getProcAddress("packed_float32_array_operator_index").?),
        .packedFloat32ArrayOperatorIndexConst = @ptrCast(getProcAddress("packed_float32_array_operator_index_const").?),
        .packedFloat64ArrayOperatorIndex = @ptrCast(getProcAddress("packed_float64_array_operator_index").?),
        .packedFloat64ArrayOperatorIndexConst = @ptrCast(getProcAddress("packed_float64_array_operator_index_const").?),
        .packedInt32ArrayOperatorIndex = @ptrCast(getProcAddress("packed_int32_array_operator_index").?),
        .packedInt32ArrayOperatorIndexConst = @ptrCast(getProcAddress("packed_int32_array_operator_index_const").?),
        .packedInt64ArrayOperatorIndex = @ptrCast(getProcAddress("packed_int64_array_operator_index").?),
        .packedInt64ArrayOperatorIndexConst = @ptrCast(getProcAddress("packed_int64_array_operator_index_const").?),
        .packedStringArrayOperatorIndex = @ptrCast(getProcAddress("packed_string_array_operator_index").?),
        .packedStringArrayOperatorIndexConst = @ptrCast(getProcAddress("packed_string_array_operator_index_const").?),
        .packedVector2ArrayOperatorIndex = @ptrCast(getProcAddress("packed_vector2_array_operator_index").?),
        .packedVector2ArrayOperatorIndexConst = @ptrCast(getProcAddress("packed_vector2_array_operator_index_const").?),
        .packedVector3ArrayOperatorIndex = @ptrCast(getProcAddress("packed_vector3_array_operator_index").?),
        .packedVector3ArrayOperatorIndexConst = @ptrCast(getProcAddress("packed_vector3_array_operator_index_const").?),
        .packedVector4ArrayOperatorIndex = @ptrCast(getProcAddress("packed_vector4_array_operator_index").?),
        .packedVector4ArrayOperatorIndexConst = @ptrCast(getProcAddress("packed_vector4_array_operator_index_const").?),
        .packedColorArrayOperatorIndex = @ptrCast(getProcAddress("packed_color_array_operator_index").?),
        .packedColorArrayOperatorIndexConst = @ptrCast(getProcAddress("packed_color_array_operator_index_const").?),
        .arrayOperatorIndex = @ptrCast(getProcAddress("array_operator_index").?),
        .arrayOperatorIndexConst = @ptrCast(getProcAddress("array_operator_index_const").?),
        .arrayRef = @ptrCast(getProcAddress("array_ref").?),
        .arraySetTyped = @ptrCast(getProcAddress("array_set_typed").?),
        .dictionaryOperatorIndex = @ptrCast(getProcAddress("dictionary_operator_index").?),
        .dictionaryOperatorIndexConst = @ptrCast(getProcAddress("dictionary_operator_index_const").?),
        .dictionarySetTyped = @ptrCast(getProcAddress("dictionary_set_typed").?),
        .objectMethodBindCall = @ptrCast(getProcAddress("object_method_bind_call").?),
        .objectMethodBindPtrcall = @ptrCast(getProcAddress("object_method_bind_ptrcall").?),
        .objectDestroy = @ptrCast(getProcAddress("object_destroy").?),
        .globalGetSingleton = @ptrCast(getProcAddress("global_get_singleton").?),
        .objectGetInstanceBinding = @ptrCast(getProcAddress("object_get_instance_binding").?),
        .objectSetInstanceBinding = @ptrCast(getProcAddress("object_set_instance_binding").?),
        .objectFreeInstanceBinding = @ptrCast(getProcAddress("object_free_instance_binding").?),
        .objectSetInstance = @ptrCast(getProcAddress("object_set_instance").?),
        .objectGetClassName = @ptrCast(getProcAddress("object_get_class_name").?),
        .objectCastTo = @ptrCast(getProcAddress("object_cast_to").?),
        .objectGetInstanceFromId = @ptrCast(getProcAddress("object_get_instance_from_id").?),
        .objectGetInstanceId = @ptrCast(getProcAddress("object_get_instance_id").?),
        .objectHasScriptMethod = @ptrCast(getProcAddress("object_has_script_method").?),
        .objectCallScriptMethod = @ptrCast(getProcAddress("object_call_script_method").?),
        .refGetObject = @ptrCast(getProcAddress("ref_get_object").?),
        .refSetObject = @ptrCast(getProcAddress("ref_set_object").?),
        .scriptInstanceCreate = @ptrCast(getProcAddress("script_instance_create").?),
        .scriptInstanceCreate2 = @ptrCast(getProcAddress("script_instance_create2").?),
        .scriptInstanceCreate3 = @ptrCast(getProcAddress("script_instance_create3").?),
        .placeholderScriptInstanceCreate = @ptrCast(getProcAddress("placeholder_script_instance_create").?),
        .placeholderScriptInstanceUpdate = @ptrCast(getProcAddress("placeholder_script_instance_update").?),
        .objectGetScriptInstance = @ptrCast(getProcAddress("object_get_script_instance").?),
        .callableCustomCreate = @ptrCast(getProcAddress("callable_custom_create").?),
        .callableCustomCreate2 = @ptrCast(getProcAddress("callable_custom_create2").?),
        .callableCustomGetUserdata = @ptrCast(getProcAddress("callable_custom_get_userdata").?),
        .classdbConstructObject = @ptrCast(getProcAddress("classdb_construct_object").?),
        .classdbConstructObject2 = @ptrCast(getProcAddress("classdb_construct_object2").?),
        .classdbGetMethodBind = @ptrCast(getProcAddress("classdb_get_method_bind").?),
        .classdbGetClassTag = @ptrCast(getProcAddress("classdb_get_class_tag").?),
        .classdbRegisterExtensionClass = @ptrCast(getProcAddress("classdb_register_extension_class").?),
        .classdbRegisterExtensionClass2 = @ptrCast(getProcAddress("classdb_register_extension_class2").?),
        .classdbRegisterExtensionClass3 = @ptrCast(getProcAddress("classdb_register_extension_class3").?),
        .classdbRegisterExtensionClass4 = @ptrCast(getProcAddress("classdb_register_extension_class4").?),
        .classdbRegisterExtensionClassMethod = @ptrCast(getProcAddress("classdb_register_extension_class_method").?),
        .classdbRegisterExtensionClassVirtualMethod = @ptrCast(getProcAddress("classdb_register_extension_class_virtual_method").?),
        .classdbRegisterExtensionClassIntegerConstant = @ptrCast(getProcAddress("classdb_register_extension_class_integer_constant").?),
        .classdbRegisterExtensionClassProperty = @ptrCast(getProcAddress("classdb_register_extension_class_property").?),
        .classdbRegisterExtensionClassPropertyIndexed = @ptrCast(getProcAddress("classdb_register_extension_class_property_indexed").?),
        .classdbRegisterExtensionClassPropertyGroup = @ptrCast(getProcAddress("classdb_register_extension_class_property_group").?),
        .classdbRegisterExtensionClassPropertySubgroup = @ptrCast(getProcAddress("classdb_register_extension_class_property_subgroup").?),
        .classdbRegisterExtensionClassSignal = @ptrCast(getProcAddress("classdb_register_extension_class_signal").?),
        .classdbUnregisterExtensionClass = @ptrCast(getProcAddress("classdb_unregister_extension_class").?),
        .getLibraryPath = @ptrCast(getProcAddress("get_library_path").?),
        .editorAddPlugin = @ptrCast(getProcAddress("editor_add_plugin").?),
        .editorRemovePlugin = @ptrCast(getProcAddress("editor_remove_plugin").?),
        .editorHelpLoadXmlFromUtf8Chars = @ptrCast(getProcAddress("editor_help_load_xml_from_utf8_chars").?),
        .editorHelpLoadXmlFromUtf8CharsAndLen = @ptrCast(getProcAddress("editor_help_load_xml_from_utf8_chars_and_len").?),
    };

    return self;
}

pub const ClassLibrary = opaque {
    pub fn ptr(self: *@This()) c.GDExtensionClassLibraryPtr {
        return @ptrCast(self);
    }
};

const std = @import("std");
const Child = std.meta.Child;

const c = @import("gdextension");

const builtin = @import("builtin.zig");
const class = @import("class.zig");
const global = @import("global.zig");
const typeName = @import("gdzig_bindings.zig").typeName;
