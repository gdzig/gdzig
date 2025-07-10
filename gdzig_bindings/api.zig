const raw: *Interface = &@import("../../gdzig_bindings.zig").raw;

pub const GodotVersion = extern struct {
    major: u32,
    minor: u32,
    patch: u32,
    string: [*:0]const u8,
};

pub const Error = error{
    VariantCallError,
    InvalidOperation,
    InvalidKey,
    IndexOutOfBounds,
    ScriptMethodCallError,
    MethodCallError,
    ConstructorError,
    IteratorInitFailed,
    InvalidIterator,
};

pub const CallError = error{
    InvalidMethod,
    InvalidArgument,
    TooManyArguments,
    TooFewArguments,
    InstanceIsNull,
    MethodNotConst,
};

const CallResult = extern struct {
    @"error": enum(c_uint) {
        ok = c.GDEXTENSION_CALL_OK,
        invalid_method = c.GDEXTENSION_CALL_ERROR_INVALID_METHOD,
        invalid_argument = c.GDEXTENSION_CALL_ERROR_INVALID_ARGUMENT,
        too_many_arguments = c.GDEXTENSION_CALL_ERROR_TOO_MANY_ARGUMENTS,
        too_few_arguments = c.GDEXTENSION_CALL_ERROR_TOO_FEW_ARGUMENTS,
        instance_is_null = c.GDEXTENSION_CALL_ERROR_INSTANCE_IS_NULL,
        method_not_const = c.GDEXTENSION_CALL_ERROR_METHOD_NOT_CONST,
    } = .ok,
    argument: i32 = 0,
    expected: i32 = 0,

    fn throw(self: CallResult) CallError!void {
        return switch (self) {
            .ok => {},
            .err => switch (self.err.@"error") {
                .invalid_method => error.InvalidMethod,
                .invalid_argument => error.InvalidArgument,
                .too_many_arguments => error.TooManyArguments,
                .too_few_arguments => error.TooFewArguments,
                .instance_is_null => error.InstanceIsNull,
                .method_not_const => error.MethodNotConst,
            },
        };
    }
};

pub const PropertyInfo = extern struct {
    tag: Variant.Tag,
    name: *StringName,
    class_name: *StringName,
    hint: PropertyHint,
    hint_string: *String,
    usage: PropertyUsageFlags,
};

/// Logs an error to Godot's built-in debugger and to the OS terminal.
///
/// @param description The code triggering the error.
/// @param function The function name where the error occurred.
/// @param file The file where the error occurred.
/// @param line The line where the error occurred.
/// @param editor_notify Whether or not to notify the editor.
///
/// @since 4.1
pub inline fn printError(description: [*:0]const u8, function: [*:0]const u8, file: [*:0]const u8, line: i32, editor_notify: bool) void {
    raw.printError(description, function, file, line, @intFromBool(editor_notify));
}

/// Logs a warning to Godot's built-in debugger and to the OS terminal.
///
/// @param description The code triggering the warning.
/// @param function The function name where the warning occurred.
/// @param file The file where the warning occurred.
/// @param line The line where the warning occurred.
/// @param editor_notify Whether or not to notify the editor.
///
/// @since 4.1
pub inline fn printWarning(description: [*:0]const u8, function: [*:0]const u8, file: [*:0]const u8, line: i32, editor_notify: bool) void {
    raw.printWarning(description, function, file, line, @intFromBool(editor_notify));
}

/// Logs an error with a message to Godot's built-in debugger and to the OS terminal.
///
/// @param description The code triggering the error.
/// @param message The message to show along with the error.
/// @param function The function name where the error occurred.
/// @param file The file where the error occurred.
/// @param line The line where the error occurred.
/// @param editor_notify Whether or not to notify the editor.
///
/// @since 4.1
pub inline fn printErrorWithMessage(description: [*:0]const u8, message: [*:0]const u8, function: [*:0]const u8, file: [*:0]const u8, line: i32, editor_notify: bool) void {
    raw.printErrorWithMessage(description, message, function, file, line, @intFromBool(editor_notify));
}

/// Logs a warning with a message to Godot's built-in debugger and to the OS terminal.
///
/// @param description The code triggering the warning.
/// @param message The message to show along with the warning.
/// @param function The function name where the warning occurred.
/// @param file The file where the warning occurred.
/// @param line The line where the warning occurred.
/// @param editor_notify Whether or not to notify the editor.
///
/// @since 4.1
pub inline fn printWarningWithMessage(description: [*:0]const u8, message: [*:0]const u8, function: [*:0]const u8, file: [*:0]const u8, line: i32, editor_notify: bool) void {
    raw.printWarningWithMessage(description, message, function, file, line, @intFromBool(editor_notify));
}

/// Logs a script error to Godot's built-in debugger and to the OS terminal.
///
/// @param description The code triggering the error.
/// @param function The function name where the error occurred.
/// @param file The file where the error occurred.
/// @param line The line where the error occurred.
/// @param editor_notify Whether or not to notify the editor.
///
/// @since 4.1
pub inline fn printScriptError(description: [*:0]const u8, function: [*:0]const u8, file: [*:0]const u8, line: i32, editor_notify: bool) void {
    raw.printScriptError(description, function, file, line, @intFromBool(editor_notify));
}

/// Logs a script error with a message to Godot's built-in debugger and to the OS terminal.
///
/// @param description The code triggering the error.
/// @param message The message to show along with the error.
/// @param function The function name where the error occurred.
/// @param file The file where the error occurred.
/// @param line The line where the error occurred.
/// @param editor_notify Whether or not to notify the editor.
///
/// @since 4.1
pub inline fn printScriptErrorWithMessage(description: [*:0]const u8, message: [*:0]const u8, function: [*:0]const u8, file: [*:0]const u8, line: i32, editor_notify: bool) void {
    raw.printScriptErrorWithMessage(description, message, function, file, line, @intFromBool(editor_notify));
}

/// Gets the Godot version that the GDExtension was loaded into.
///
/// @return The Godot version information.
///
/// @since 4.1
pub inline fn getGodotVersion() GodotVersion {
    var version: GodotVersion = undefined;
    raw.getGodotVersion(&version);
    return version;
}

/// Gets the size of a native struct (ex. ObjectID) in bytes.
///
/// @param name A pointer to a StringName identifying the struct name.
///
/// @return The size in bytes.
///
/// @since 4.1
pub inline fn getNativeStructSize(name: *const StringName) usize {
    return @intCast(raw.getNativeStructSize(name.constPtr()));
}

const c = @import("gdextension");

const global = @import("../global.zig");
const PropertyHint = global.PropertyHint;
const PropertyUsageFlags = global.PropertyUsageFlags;
pub const array = @import("./api/array.zig");
pub const callable = @import("./api/callable.zig");
pub const classdb = @import("./api/classdb.zig");
pub const dictionary = @import("./api/dictionary.zig");
pub const editor = @import("./api/editor.zig");
pub const extension = @import("./api/extension.zig");
pub const file_access = @import("./api/file_access.zig");
pub const image = @import("./api/image.zig");
pub const mem = @import("./api/mem.zig");
pub const object = @import("./api/object.zig");
pub const ref = @import("./api/ref.zig");
pub const script_instance = @import("./api/script_instance.zig");
pub const string = @import("./api/string.zig");
pub const string_name = @import("./api/string_name.zig");
pub const variant = @import("./api/variant.zig");
pub const worker_thread_pool = @import("./api/worker_thread_pool.zig");
pub const xml_parser = @import("./api/xml_parser.zig");
const builtin = @import("./builtin.zig");
const String = builtin.String;
const StringName = builtin.StringName;
const Variant = builtin.Variant;
const Interface = @import("./Interface.zig");
