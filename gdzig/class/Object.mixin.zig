// @mixin start

/// Immediately destroys the object. Prefer `queueFree` in most situations.
pub fn destroy(self: *Self) void {
    if (DestroyMeta.get(Object.upcast(self))) |destroy_meta| {
        if (destroy_meta.engine_destroying) return;
        destroy_meta.user_destroying = true;
    }
    raw.objectDestroy(self.ptr());
}

/// Upcasts a child type to this type.
pub fn upcast(value: anytype) *Self {
    return oopz.upcast(*Self, value);
}

/// Downcasts a parent type to this type.
///
/// This operation will fail at compile time if Self does not inherit from `@TypeOf(value)`. However,
/// since there is no guarantee that `value` is this type at runtime, this function has a runtime cost
/// and may return `null`.
pub fn downcast(value: anytype) ?*Self {
    const T = comptime sw: switch (@typeInfo(@TypeOf(value))) {
        .optional => |info| continue :sw @typeInfo(info.child),
        .pointer => |info| break :sw info.child,
        else => @compileError("downcasted value should be a pointer, found '" ++ @typeName(@TypeOf(value)) ++ "'"),
    };
    comptime oopz.assertIsA(T, Self);
    const tag = raw.classdbGetClassTag(@ptrCast(&StringName.fromComptimeLatin1(self_name)));
    const result = raw.objectCastTo(@ptrCast(value), tag);
    if (result) |p| {
        if (oopz.isOpaqueClass(T)) {
            return @ptrCast(@alignCast(p));
        } else {
            const object: *anyopaque = raw.objectGetInstanceBinding(p, raw.library, null) orelse return null;
            return @ptrCast(@alignCast(object));
        }
    } else {
        return null;
    }
}

/// Returns an opaque pointer to the object.
pub fn ptr(self: *Self) *anyopaque {
    return @ptrCast(self);
}

/// Returns a constant opaque pointer to the object.
pub fn constPtr(self: *const Self) *const anyopaque {
    return @ptrCast(self);
}

/// Bind an instance of an extension class to this engine class.
pub fn setInstance(self: *Self, comptime T: type, instance_: *T) void {
    comptime std.debug.assert(oopz.BaseOf(T) == Self);
    comptime std.debug.assert(oopz.isStructClass(T));

    const token = comptime typeToken(T);

    raw.objectSetInstance(@ptrCast(self), @ptrCast(typeName(T)), @ptrCast(instance_));
    raw.objectSetInstanceBinding(@ptrCast(self), token, @ptrCast(instance_), &struct {
        const callbacks = c.GDExtensionInstanceBindingCallbacks{
            .create_callback = create_callback,
            .free_callback = free_callback,
            .reference_callback = reference_callback,
        };

        fn create_callback(_: ?*anyopaque, _: ?*anyopaque) callconv(.c) ?*anyopaque {
            return null;
        }

        fn free_callback(_: ?*anyopaque, _: ?*anyopaque, _: ?*anyopaque) callconv(.c) void {}

        fn reference_callback(_: ?*anyopaque, _: ?*anyopaque, _: c.GDExtensionBool) callconv(.c) c.GDExtensionBool {
            return 1;
        }
    }.callbacks);
}

pub fn asInstance(self: *Self, comptime T: type) ?*T {
    comptime std.debug.assert(oopz.BaseOf(T) == Self);
    comptime std.debug.assert(oopz.isStructClass(T));

    const token = comptime typeToken(T);

    const ptr_ = raw.objectGetInstanceBinding(@ptrCast(self), token, null) orelse return null;

    return @ptrCast(@alignCast(ptr_));
}

fn typeToken(comptime T: type) *anyopaque {
    return @ptrCast(&struct {
        var token: void = {};
        comptime {
            _ = T;
        }
    }.token);
}

/// Connects a signal to a callable.
pub fn connect(self: *Self, comptime S: type, callable: Callable) ConnectError!void {
    const signal_name: StringName = .fromComptimeLatin1(comptime gdzig_meta.signalName(S));
    const result = self.connectRaw(signal_name, callable, .{});
    if (result != .ok) return ConnectError.AlreadyConnected;
}

/// Disconnects a signal from a callable.
pub fn disconnect(self: *Self, comptime S: type, callable: Callable) void {
    const signal_name: StringName = .fromComptimeLatin1(comptime gdzig_meta.signalName(S));
    self.disconnectRaw(signal_name, callable);
}

/// Emits a signal.
pub fn emit(self: *Self, signal: anytype) EmitError!void {
    const S = @TypeOf(signal);
    const signal_name: StringName = .fromComptimeLatin1(comptime gdzig_meta.signalName(S));
    const fields = @typeInfo(S).@"struct".fields;
    var args: std.meta.Tuple(&typeInfoToTypes(fields)) = undefined;
    inline for (fields, 0..) |field, i| {
        args[i] = @field(signal, field.name);
    }
    const result = self.emitRaw(signal_name, args);
    if (result != .ok) return EmitError.InvalidSignal;
}

fn typeInfoToTypes(comptime fields: []const std.builtin.Type.StructField) [fields.len]type {
    var types: [fields.len]type = undefined;
    for (fields, 0..) |field, i| {
        types[i] = field.type;
    }
    return types;
}

const gdzig_meta = @import("../meta.zig");
const ConnectError = @import("../gdzig.zig").ConnectError;
const EmitError = @import("../gdzig.zig").EmitError;
const DestroyMeta = @import("../register.zig").DestroyMeta;

// @mixin stop

const std = @import("std");

const godot = @import("../gdzig.zig");
const typeName = godot.meta.typeName;
const Callable = godot.builtin.Callable;
const Object = @import("object.zig").Object;
const Variant = godot.builtin.Variant;

const oopz = @import("oopz");
const raw = &godot.raw;
const StringName = @import("../builtin.zig").StringName;

const c = @import("gdextension");

const Self = @import("./object.zig").Object;
const self_name = "Object";
