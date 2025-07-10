const raw: *Interface = &@import("../../gdzig_bindings.zig").raw;

/// Creates a StringName from a Latin-1 encoded C string.
///
/// If `is_static` is true, then:
/// - The StringName will reuse the `p_contents` buffer instead of copying it.
///   You must guarantee that the buffer remains valid for the duration of the application (e.g. string literal).
/// - You must not call a destructor for this StringName. Incrementing the initial reference once should achieve this.
///
/// @param str A pointer to a Latin-1 encoded C string (null terminated).
/// @param is_static If true, the StringName will reuse the buffer instead of copying it.
///
/// @return The newly created StringName.
///
/// @since 4.2
pub inline fn stringNameNewWithLatin1Chars(str: [*:0]const u8, is_static: bool) StringName {
    var string_name: StringName = undefined;
    raw.stringNameNewWithLatin1Chars(string_name.ptr(), str, is_static != 0);
    return string_name;
}

/// Creates a StringName from a UTF-8 encoded C string.
///
/// @param str A pointer to a C string (null terminated and UTF-8 encoded).
///
/// @return The newly created StringName.
///
/// @since 4.2
pub inline fn stringNameNewWithUtf8Chars(str: [*:0]const u8) StringName {
    var string_name: StringName = undefined;
    raw.stringNameNewWithUtf8Chars(string_name.ptr(), str);
    return string_name;
}

pub inline fn stringNameNewWithUtf8(str: []const u8) StringName {
    var string_name: StringName = undefined;
    raw.stringNameNewWithUtf8CharsAndLen(string_name.ptr(), str.ptr, str.len);
    return string_name;
}

const builtin = @import("../builtin.zig");
const StringName = builtin.StringName;
const Interface = @import("../Interface.zig");
