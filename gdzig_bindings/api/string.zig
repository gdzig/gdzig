const raw: *Interface = &@import("../../gdzig_bindings.zig").raw;

/// Creates a String from a UTF-8 encoded C string.
///
/// @param str A pointer to a UTF-8 encoded C string (null terminated).
///
/// @return The newly created String.
///
/// @since 4.1
pub inline fn stringNewWithUtf8Chars(str: [*:0]const u8) String {
    var string: String = undefined;
    raw.stringNewWithUtf8Chars(string.ptr(), str);
    return string;
}

/// **Deprecated** in Godot 4.3. Use `stringNewWithUtf8_2` instead.
///
/// Creates a String from a UTF-8 encoded C string with the given length.
///
/// @param str A slice of UTF-8 encoded bytes.
///
/// @return The newly created String.
///
/// @since 4.1
pub inline fn stringNewWithUtf8(str: []const u8) String {
    var string: String = undefined;
    raw.stringNewWithUtf8CharsAndLen(string.ptr(), str.ptr, str.len);
    return string;
}

/// Converts a String to a UTF-8 encoded C string.
///
/// It doesn't write a null terminator.
///
/// @param string A pointer to the String.
/// @param buffer A slice to hold the resulting data.
///
/// @return The resulting encoded string length in characters (not bytes), not including a null terminator.
///
/// @since 4.1
pub inline fn stringToUtf8Chars(string: *const String, buffer: []u8) i64 {
    return raw.stringToUtf8Chars(string.constPtr(), buffer.ptr, buffer.len);
}

/// Appends another String to a String.
///
/// @param self A pointer to the String.
/// @param other A pointer to the other String to append.
///
/// @since 4.1
pub inline fn stringOperatorPlusEqString(self: *String, other: *const String) void {
    raw.stringOperatorPlusEqString(self.ptr(), other.constPtr());
}

/// Appends a character to a String.
///
/// @param self A pointer to the String.
/// @param ch The character to append.
///
/// @since 4.1
pub inline fn stringOperatorPlusEqChar(self: *String, ch: u32) void {
    raw.stringOperatorPlusEqChar(self.ptr(), ch);
}

/// Appends a Latin-1 encoded C string to a String.
///
/// @param self A pointer to the String.
/// @param cstr A Latin-1 encoded C string (null terminated).
///
/// @since 4.1
pub inline fn stringOperatorPlusEqCstr(self: *String, cstr: [*:0]const u8) void {
    raw.stringOperatorPlusEqCstr(self.ptr(), cstr);
}

/// Resizes the underlying string data to the given number of characters.
///
/// Space needs to be allocated for the null terminating character ('\0') which
/// also must be added manually, in order for all string functions to work correctly.
///
/// Warning: This is an error-prone operation - only use it if there's no other
/// efficient way to accomplish your goal.
///
/// @param self A pointer to the String.
/// @param new_size The new length for the String.
///
/// @since 4.2
pub inline fn stringResize(self: *String, new_size: i64) void {
    raw.stringResize(self.ptr(), new_size);
}

/// Creates a String from a Latin-1 encoded C string.
///
/// @param str A pointer to a Latin-1 encoded C string (null terminated).
///
/// @return The newly created String.
///
/// @since 4.1
pub inline fn stringNewWithLatin1Chars(cstr: [*:0]const u8) String {
    var result: String = undefined;
    raw.stringNewWithLatin1Chars(result.ptr(), cstr);
    return result;
}

/// Creates a String from a Latin-1 encoded C string with the given length.
///
/// @param cstr A slice of Latin-1 encoded bytes.
///
/// @return The newly created String.
///
/// @since 4.1
pub inline fn stringNewWithLatin1(cstr: []const u8) String {
    var result: String = undefined;
    raw.stringNewWithLatin1CharsAndLen(result.ptr(), cstr.ptr, cstr.len);
    return result;
}

/// Creates a String from a UTF-8 encoded C string with the given length.
///
/// @param cstr A slice of UTF-8 encoded bytes.
///
/// @return The newly created String.
///
/// @since 4.3
pub inline fn stringNewWithUtf8_2(cstr: []const u8) String {
    var result: String = undefined;
    raw.stringNewWithUtf8CharsAndLen2(result.ptr(), cstr.ptr, cstr.len);
    return result;
}

/// **Deprecated** in Godot 4.3. Use `stringNewWithUtf16_2` instead.
///
/// Creates a String from a UTF-16 encoded C string with the given length.
///
/// @param utf16 A slice of UTF-16 encoded characters.
///
/// @return The newly created String.
///
/// @since 4.1
pub inline fn stringNewWithUtf16(utf16: []const u16) String {
    var result: String = undefined;
    raw.stringNewWithUtf16CharsAndLen(result.ptr(), utf16.ptr, utf16.len);
    return result;
}

/// Creates a String from a UTF-16 encoded C string with the given length.
///
/// @param utf16 A slice of UTF-16 encoded characters.
/// @param default_little_endian If true, UTF-16 use little endian.
///
/// @return The newly created String.
///
/// @since 4.3
pub inline fn stringNewWithUtf16_2(utf16: []const u16, default_little_endian: bool) String {
    var result: String = undefined;
    raw.stringNewWithUtf16CharsAndLen2(result.ptr(), utf16.ptr, utf16.len, @intFromBool(default_little_endian));
    return result;
}

/// Creates a String from a UTF-32 encoded C string with the given length.
///
/// @param utf32 A slice of UTF-32 encoded characters.
///
/// @return The newly created String.
///
/// @since 4.1
pub inline fn stringNewWithUtf32(utf32: []const u32) String {
    var result: String = undefined;
    raw.stringNewWithUtf32CharsAndLen(result.ptr(), utf32.ptr, utf32.len);
    return result;
}

/// Creates a String from a wide C string with the given length.
///
/// @param wcstr A slice of wide characters.
///
/// @return The newly created String.
///
/// @since 4.1
pub inline fn stringNewWithWide(wcstr: []const c.wchar_t) String {
    var result: String = undefined;
    raw.stringNewWithWideCharsAndLen(result.ptr(), wcstr.ptr, wcstr.len);
    return result;
}

/// Creates a String from a wide string.
///
/// @param wcstr A pointer to a wide C string (null terminated).
///
/// @return The newly created String.
///
/// @since 4.1
pub inline fn stringNewWithWideChars(wcstr: [*:0]const c.wchar_t) String {
    var result: String = undefined;
    raw.stringNewWithWideChars(result.ptr(), wcstr);
    return result;
}

/// Converts a String to a Latin-1 encoded C string.
///
/// It doesn't write a null terminator.
///
/// @param string A pointer to the String.
/// @param buffer A slice to hold the resulting data.
///
/// @return The resulting encoded string length in characters (not bytes), not including a null terminator.
///
/// @since 4.1
pub inline fn stringToLatin1Chars(self: *const String, buffer: []u8) i64 {
    return raw.stringToLatin1Chars(self.constPtr(), buffer.ptr, buffer.len);
}

/// Converts a String to a wide C string.
///
/// It doesn't write a null terminator.
///
/// @param string A pointer to the String.
/// @param buffer A slice to hold the resulting data.
///
/// @return The resulting encoded string length in characters (not bytes), not including a null terminator.
///
/// @since 4.1
pub inline fn stringToWideChars(self: *const String, buffer: []c.wchar_t) i64 {
    return raw.stringToWideChars(self.constPtr(), buffer.ptr, buffer.len);
}

/// Appends a wide C string to a String.
///
/// @param self A pointer to the String.
/// @param wcstr A pointer to a wide C string (null terminated).
///
/// @since 4.1
pub inline fn stringOperatorPlusEqWcstr(self: *String, wcstr: [*:0]const c.wchar_t) void {
    raw.stringOperatorPlusEqWcstr(self.ptr(), wcstr);
}

/// Appends a UTF-32 encoded C string to a String.
///
/// @param self A pointer to the String.
/// @param c32str A pointer to a UTF-32 encoded C string (null terminated).
///
/// @since 4.1
pub inline fn stringOperatorPlusEqC32str(self: *String, c32str: [*:0]const u32) void {
    raw.stringOperatorPlusEqC32Str(self.ptr(), c32str);
}

/// Gets a pointer to the character at the given index from a String.
///
/// @param p_self A pointer to the String.
/// @param p_index The index.
///
/// @return A pointer to the requested character.
///
/// @since 4.1
pub inline fn stringOperatorIndex(self: *String, index: i64) *u32 {
    return raw.stringOperatorIndex(self.ptr(), index);
}

/// Gets a const pointer to the character at the given index from a String.
///
/// @param p_self A pointer to the String.
/// @param p_index The index.
///
/// @return A const pointer to the requested character.
///
/// @since 4.1
pub inline fn stringOperatorIndexConst(self: *const String, index: i64) *const u32 {
    return raw.stringOperatorIndexConst(self.constPtr(), index);
}

/// Converts a String to a UTF-16 encoded C string.
///
/// It doesn't write a null terminator.
///
/// @param string A pointer to the String.
/// @param buffer A slice to hold the resulting data.
///
/// @return The resulting encoded string length in characters (not bytes), not including a null terminator.
///
/// @since 4.1
pub inline fn stringToUtf16Chars(self: *const String, buffer: []u16) i64 {
    return raw.stringToUtf16Chars(self.constPtr(), buffer.ptr, buffer.len);
}

/// Converts a String to a UTF-32 encoded C string.
///
/// It doesn't write a null terminator.
///
/// @param string A pointer to the String.
/// @param buffer A slice to hold the resulting data.
///
/// @return The resulting encoded string length in characters (not bytes), not including a null terminator.
///
/// @since 4.1
pub inline fn stringToUtf32Chars(self: *const String, buffer: []u32) i64 {
    return raw.stringToUtf32Chars(self.constPtr(), buffer.ptr, buffer.len);
}

/// Creates a String from a UTF-16 encoded C string.
///
/// @param utf16 A pointer to a UTF-16 encoded C string (null terminated).
///
/// @return The newly created String.
///
/// @since 4.1
pub inline fn stringNewWithUtf16Chars(utf16: [*:0]const u16) String {
    var result: String = undefined;
    raw.stringNewWithUtf16Chars(result.ptr(), utf16);
    return result;
}

/// Creates a String from a UTF-32 encoded C string.
///
/// @param utf32 A pointer to a UTF-32 encoded C string (null terminated).
///
/// @return The newly created String.
///
/// @since 4.1
pub inline fn stringNewWithUtf32Chars(utf32: [*:0]const u32) String {
    var result: String = undefined;
    raw.stringNewWithUtf32Chars(result.ptr(), utf32);
    return result;
}

const c = @import("gdextension");

const builtin = @import("../builtin.zig");
const String = builtin.String;
const Interface = @import("../Interface.zig");
