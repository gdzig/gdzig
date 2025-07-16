/// Creates a StringName from a Latin-1 encoded C string.
///
/// If `is_static` is true, then:
/// - The StringName will reuse the `str` buffer instead of copying it.
///   You must guarantee that the buffer remains valid for the duration of the application (e.g. string literal).
/// - You must not call a destructor for this StringName. Incrementing the initial reference once should achieve this.
///
/// - **str**: A pointer to a Latin-1 encoded C string (null terminated).
/// - **is_static**: If true, the StringName will reuse the buffer instead of copying it.
///
/// @return The newly created StringName.
///
/// **Since Godot 4.2**
pub inline fn fromLatin1(str: [:0]const u8, is_static: bool) StringName {
    var string_name: StringName = undefined;
    raw.stringNameNewWithLatin1Chars(string_name.ptr(), @ptrCast(str.ptr), @intFromBool(is_static));
    return string_name;
}

/// Creates a StringName from a comptime Latin-1 encoded C string.
///
/// Since the string is known to be static, it will be reused instead of copied.
///
/// - **str**: A pointer to a Latin-1 encoded C string (null terminated).
///
/// @return The newly created StringName.
///
/// **Since Godot 4.2**
pub fn fromComptimeLatin1(comptime str: [:0]const u8) StringName {
    var self: StringName = undefined;
    raw.stringNameNewWithLatin1Chars(@ptrCast(&self), @ptrCast(str.ptr), 1);
    return self;
}

/// Creates a StringName from a UTF-8 encoded string with the given length.
///
/// - **str**: A slice of UTF-8 encoded bytes.
///
/// @return The newly created StringName.
///
/// **Since Godot 4.1**
pub inline fn fromUtf8(str: []const u8) StringName {
    var string_name: StringName = undefined;
    raw.stringNameNewWithUtf8CharsAndLen(string_name.ptr(), @ptrCast(str.ptr), @intCast(str.len));
    return string_name;
}

/// Creates a StringName from a UTF-8 encoded C string.
///
/// - **str**: A pointer to a C string (null terminated and UTF-8 encoded).
///
/// @return The newly created StringName.
///
/// **Since Godot 4.2**
pub inline fn fromNullTerminatedUtf8(str: [:0]const u8) StringName {
    var string_name: StringName = undefined;
    raw.stringNameNewWithUtf8Chars(string_name.ptr(), @ptrCast(str.ptr));
    return string_name;
}

// @mixin stop

const raw: *Interface = &@import("../gdzig.zig").raw;

const Interface = @import("../Interface.zig");
const StringName = @import("./string_name.zig").StringName;
