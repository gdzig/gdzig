/// Creates a String from a UTF-8 encoded C string.
///
/// - **str**: A pointer to a UTF-8 encoded C string (null terminated).
///
/// **Since Godot 4.1**
pub inline fn fromUtf8Chars(str: [*:0]const u8) String {
    var string: String = undefined;
    raw.stringNewWithUtf8Chars(string.ptr(), str);
    return string;
}

/// **Deprecated** in Godot 4.3. Use `fromUtf8_2` instead.
///
/// Creates a String from a UTF-8 encoded C string with the given length.
///
/// - **str**: A slice of UTF-8 encoded bytes.
///
/// **Since Godot 4.1**
pub inline fn fromUtf8(str: []const u8) String {
    var string: String = undefined;
    raw.stringNewWithUtf8CharsAndLen(string.ptr(), str.ptr, str.len);
    return string;
}

/// Creates a String from a UTF-8 encoded C string with the given length.
///
/// - **cstr**: A slice of UTF-8 encoded bytes.
///
/// **Since Godot 4.3**
pub inline fn fromUtf8_2(cstr: []const u8) String {
    var result: String = undefined;
    raw.stringNewWithUtf8CharsAndLen2(result.ptr(), cstr.ptr, cstr.len);
    return result;
}

/// Creates a String from a Latin-1 encoded C string.
///
/// - **cstr**: A pointer to a Latin-1 encoded C string (null terminated).
///
/// **Since Godot 4.1**
pub inline fn fromLatin1WithSentinel(cstr: [*:0]const u8) String {
    var result: String = undefined;
    raw.stringNewWithLatin1Chars(result.ptr(), cstr);
    return result;
}

/// Creates a String from a Latin-1 encoded C string with the given length.
///
/// - **cstr**: A slice of Latin-1 encoded bytes.
///
/// **Since Godot 4.1**
pub inline fn fromLatin1(cstr: []const u8) String {
    var result: String = undefined;
    raw.stringNewWithLatin1CharsAndLen(result.ptr(), cstr.ptr, cstr.len);
    return result;
}

/// **Deprecated** in Godot 4.3. Use `fromUtf16_2` instead.
///
/// Creates a String from a UTF-16 encoded C string with the given length.
///
/// - **utf16**: A slice of UTF-16 encoded characters.
///
/// **Since Godot 4.1**
pub inline fn fromUtf16(utf16: []const u16) String {
    var result: String = undefined;
    raw.stringNewWithUtf16CharsAndLen(result.ptr(), utf16.ptr, utf16.len);
    return result;
}

/// Creates a String from a UTF-16 encoded C string.
///
/// - **utf16**: A pointer to a UTF-16 encoded C string (null terminated).
///
/// **Since Godot 4.1**
pub inline fn fromUtf16Chars(utf16: [*:0]const u16) String {
    var result: String = undefined;
    raw.stringNewWithUtf16Chars(result.ptr(), utf16);
    return result;
}

/// Creates a String from a UTF-16 encoded C string with the given length.
///
/// - **utf16**: A slice of UTF-16 encoded characters.
/// - **default_little_endian**: If true, UTF-16 use little endian.
///
/// **Since Godot 4.3**
pub inline fn fromUtf16_2(utf16: []const u16, default_little_endian: bool) String {
    var result: String = undefined;
    raw.stringNewWithUtf16CharsAndLen2(result.ptr(), utf16.ptr, utf16.len, @intFromBool(default_little_endian));
    return result;
}

/// Creates a String from a UTF-32 encoded C string with the given length.
///
/// - **utf32**: A slice of UTF-32 encoded characters.
///
/// **Since Godot 4.1**
pub inline fn fromUtf32(utf32: []const u32) String {
    var result: String = undefined;
    raw.stringNewWithUtf32CharsAndLen(result.ptr(), utf32.ptr, utf32.len);
    return result;
}

/// Creates a String from a UTF-32 encoded C string.
///
/// - **utf32**: A pointer to a UTF-32 encoded C string (null terminated).
///
/// **Since Godot 4.1**
pub inline fn fromUtf32Chars(utf32: [*:0]const u32) String {
    var result: String = undefined;
    raw.stringNewWithUtf32Chars(result.ptr(), utf32);
    return result;
}

/// Creates a String from a wide C string with the given length.
///
/// - **wcstr**: A slice of wide characters.
///
/// **Since Godot 4.1**
pub inline fn fromWide(wcstr: []const c.wchar_t) String {
    var result: String = undefined;
    raw.stringNewWithWideCharsAndLen(result.ptr(), wcstr.ptr, wcstr.len);
    return result;
}

/// Creates a String from a wide string.
///
/// - **wcstr**: A pointer to a wide C string (null terminated).
///
/// **Since Godot 4.1**
pub inline fn fromWideChars(wcstr: [*:0]const c.wchar_t) String {
    var result: String = undefined;
    raw.stringNewWithWideChars(result.ptr(), wcstr);
    return result;
}

/// Converts this String to a UTF-8 encoded C string.
///
/// It doesn't write a null terminator.
///
/// - **buffer**: A slice to hold the resulting data.
///
/// **Since Godot 4.1**
pub inline fn toUtf8Chars(self: *const String, buffer: []u8) i64 {
    return raw.stringToUtf8Chars(self.constPtr(), buffer.ptr, buffer.len);
}

/// Converts this String to a Latin-1 encoded C string.
///
/// It doesn't write a null terminator.
///
/// - **buffer**: A slice to hold the resulting data.
///
/// **Since Godot 4.1**
pub inline fn toLatin1Chars(self: *const String, buffer: []u8) i64 {
    return raw.stringToLatin1Chars(self.constPtr(), buffer.ptr, buffer.len);
}

/// Converts this String to a UTF-16 encoded C string.
///
/// It doesn't write a null terminator.
///
/// - **buffer**: A slice to hold the resulting data.
///
/// **Since Godot 4.1**
pub inline fn toUtf16Chars(self: *const String, buffer: []u16) i64 {
    return raw.stringToUtf16Chars(self.constPtr(), buffer.ptr, buffer.len);
}

/// Converts this String to a UTF-32 encoded C string.
///
/// It doesn't write a null terminator.
///
/// - **buffer**: A slice to hold the resulting data.
///
/// **Since Godot 4.1**
pub inline fn toUtf32Chars(self: *const String, buffer: []u32) i64 {
    return raw.stringToUtf32Chars(self.constPtr(), buffer.ptr, buffer.len);
}

/// Converts this String to a wide C string.
///
/// It doesn't write a null terminator.
///
/// - **buffer**: A slice to hold the resulting data.
///
/// **Since Godot 4.1**
pub inline fn toWideChars(self: *const String, buffer: []c.wchar_t) i64 {
    return raw.stringToWideChars(self.constPtr(), buffer.ptr, buffer.len);
}

/// Appends another String to this String.
///
/// - **other**: A pointer to the other String to append.
///
/// **Since Godot 4.1**
pub inline fn appendString(self: *String, other: *const String) void {
    raw.stringOperatorPlusEqString(self.ptr(), other.constPtr());
}

/// Appends a character to this String.
///
/// - **ch**: The character to append.
///
/// **Since Godot 4.1**
pub inline fn appendChar(self: *String, ch: u32) void {
    raw.stringOperatorPlusEqChar(self.ptr(), ch);
}

/// Appends a Latin-1 encoded C string to this String.
///
/// - **cstr**: A Latin-1 encoded C string (null terminated).
///
/// **Since Godot 4.1**
pub inline fn appendCstr(self: *String, cstr: [*:0]const u8) void {
    raw.stringOperatorPlusEqCstr(self.ptr(), cstr);
}

/// Appends a wide C string to this String.
///
/// - **wcstr**: A pointer to a wide C string (null terminated).
///
/// **Since Godot 4.1**
pub inline fn appendWcstr(self: *String, wcstr: [*:0]const c.wchar_t) void {
    raw.stringOperatorPlusEqWcstr(self.ptr(), wcstr);
}

/// Appends a UTF-32 encoded C string to this String.
///
/// - **c32str**: A pointer to a UTF-32 encoded C string (null terminated).
///
/// **Since Godot 4.1**
pub inline fn appendC32str(self: *String, c32str: [*:0]const u32) void {
    raw.stringOperatorPlusEqC32Str(self.ptr(), c32str);
}

/// Resizes the underlying string data to the given number of characters.
///
/// Space needs to be allocated for the null terminating character ('\0') which
/// also must be added manually, in order for all string functions to work correctly.
///
/// Warning: This is an error-prone operation - only use it if there's no other
/// efficient way to accomplish your goal.
///
/// - **new_size**: The new length for the String.
///
/// **Since Godot 4.2**
pub inline fn resize(self: *String, new_size: i64) void {
    raw.stringResize(self.ptr(), new_size);
}

/// Gets a pointer to the character at the given index from this String.
///
/// - **index_**: The index.
///
/// **Since Godot 4.1**
pub inline fn index(self: *String, index_: i64) *u32 {
    return raw.stringOperatorIndex(self.ptr(), index_);
}

/// Gets a const pointer to the character at the given index from this String.
///
/// - **index_**: The index.
///
/// **Since Godot 4.1**
pub inline fn indexConst(self: *const String, index_: i64) *const u32 {
    return raw.stringOperatorIndexConst(self.constPtr(), index_);
}

// @mixin stop

const raw: *Interface = &@import("../gdzig_bindings.zig").raw;

const c = @import("gdextension");

const Interface = @import("../Interface.zig");
const String = @import("./string.zig").String;
