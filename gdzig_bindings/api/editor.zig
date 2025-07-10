const raw: *Interface = &@import("../../gdzig_bindings.zig").raw;

/// Adds an editor plugin.
///
/// It's safe to call during initialization.
///
/// @param class_name A pointer to a StringName with the name of a class (descending from EditorPlugin) which is already registered with ClassDB.
///
/// @since 4.1
pub inline fn editorAddPlugin(class_name: *const StringName) void {
    raw.editorAddPlugin(class_name.constPtr());
}

/// Removes an editor plugin.
///
/// @param class_name A pointer to a StringName with the name of a class that was previously added as an editor plugin.
///
/// @since 4.1
pub inline fn editorRemovePlugin(class_name: *const StringName) void {
    raw.editorRemovePlugin(class_name.constPtr());
}

/// Loads new XML-formatted documentation data in the editor.
///
/// The provided pointer can be immediately freed once the function returns.
///
/// @param data A slice containing a UTF-8 encoded C string.
///
/// @since 4.3
pub inline fn editorHelpLoadXmlFromUtf8(data: []const u8) void {
    raw.editorHelpLoadXmlFromUtf8CharsAndLen(data.ptr, data.len);
}

/// Loads new XML-formatted documentation data in the editor.
///
/// The provided pointer can be immediately freed once the function returns.
///
/// @param data A pointer to a UTF-8 encoded C string (null terminated).
///
/// @since 4.3
pub inline fn editorHelpLoadXmlFromUtf8Chars(data: [*:0]const u8) void {
    raw.editorHelpLoadXmlFromUtf8Chars(data);
}

const builtin = @import("../builtin.zig");
const StringName = builtin.StringName;
const Interface = @import("../Interface.zig");
