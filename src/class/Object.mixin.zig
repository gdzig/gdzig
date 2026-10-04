// @mixin start

/// Immediately destroys the object. Prefer `queueFree` in most situations.
pub fn destroy(self: *Self) void {
    if (DestroyInstanceBinding.get(Object.upcast(self))) |destroy_meta| {
        if (destroy_meta.engine_destroying) return;
        destroy_meta.user_destroying = true;
    }
    raw.objectDestroy(self.ptr());
}

/// Returns whether this object inherits the named engine class.
/// Godot 4.6 expects String, while Godot 4.7 expects StringName.
fn isClassImpl(self: *const Self, p_class: StringName) bool {
    const modern = gdzig.version.gte(.@"4.7");
    if (isClass_ptr == null) {
        const hash: i64 = if (modern) 2619796661 else object_is_class_compat.object_is_class;
        isClass_ptr = raw.classdbGetMethodBind(@ptrCast(&StringName.fromComptimeLatin1("Object")), @ptrCast(&StringName.fromComptimeLatin1("is_class")), hash);
    }
    var result: bool = false;
    if (modern) {
        const args = [_]c.GDExtensionConstTypePtr{@ptrCast(&p_class)};
        raw.objectMethodBindPtrcall(isClass_ptr, @ptrCast(@constCast(self)), @ptrCast(&args), @ptrCast(&result));
    } else {
        var legacy_name: gdzig.builtin.String = .fromStringName(p_class);
        defer legacy_name.deinit();
        const args = [_]c.GDExtensionConstTypePtr{@ptrCast(&legacy_name)};
        raw.objectMethodBindPtrcall(isClass_ptr, @ptrCast(@constCast(self)), @ptrCast(&args), @ptrCast(&result));
    }
    return result;
}
var isClass_ptr: c.GDExtensionMethodBindPtr = null;

/// Upcasts a child type to this type.
pub fn upcast(value: anytype) *Self {
    return class.upcast(*Self, value);
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
    comptime class.assertIsA(T, Self);
    const tag = raw.classdbGetClassTag(@ptrCast(&StringName.fromComptimeLatin1(self_name)));
    const result = raw.objectCastTo(@ptrCast(value), tag);
    if (result) |p| {
        if (class.isOpaqueClass(T)) {
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
    comptime std.debug.assert(class.isA(Self, T));
    comptime std.debug.assert(class.isStructClass(T));

    const token = comptime typeToken(T);

    raw.objectSetInstance(@ptrCast(self), @ptrCast(&StringName.fromType(T)), @ptrCast(instance_));
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
    comptime std.debug.assert(class.isA(Self, T));
    comptime std.debug.assert(class.isStructClass(T));

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
    const signal_name: StringName = .fromSignal(S);
    const result = self.connectRaw(signal_name, callable, .{});
    if (result != .ok) return ConnectError.AlreadyConnected;
}

/// Disconnects a signal from a callable.
pub fn disconnect(self: *Self, comptime S: type, callable: Callable) void {
    const signal_name: StringName = .fromSignal(S);
    self.disconnectRaw(signal_name, callable);
}

/// Emits a signal. Guarantees no allocations when calling across the FFI. Passing Transform2D, AABB, Basis, Transform3D, or Projection is a compile error; use the Alloc variant.
pub fn emit(self: *Self, comptime SignalType: type, signal: AssertNonAllocating(SignalType)) EmitError!void {
    const signal_name: StringName = .fromSignal(SignalType);
    const fields = meta.structFields(SignalType);
    var args: [fields.len]Variant = undefined;
    inline for (fields, 0..) |field, i| {
        args[i] = Variant.init(field.type, @field(signal, field.name));
    }
    // No defer needed - non-allocating types don't need cleanup
    return emitImpl(self, signal_name, args);
}

/// Emits a signal. Will necessarily allocate when calling across the FFI with Transform2d, Aabb, Basis, Transform3d, or Projection.
pub fn emitAlloc(self: *Self, comptime SignalType: type, signal: SignalType) EmitError!void {
    const signal_name: StringName = .fromSignal(SignalType);
    const fields = meta.structFields(SignalType);
    var args: [fields.len]Variant = undefined;
    inline for (fields, 0..) |field, i| {
        args[i] = Variant.init(field.type, @field(signal, field.name));
    }
    defer inline for (&args, fields) |*arg, field| {
        if (allocatesAsVariant(field.type)) arg.deinit();
    };
    return emitImpl(self, signal_name, args);
}

fn emitImpl(self: *Self, signal_name: StringName, args: anytype) EmitError!void {
    switch (self.emitRaw(signal_name, args)) {
        .ok => {},
        .err_unavailable => {
            // Godot does not distinguish between "not a signal I handle" and "no one is listening to this signal"
            if (self.hasSignal(signal_name)) return;
            return EmitError.InvalidSignal;
        },
        .err_cant_acquire_resource => return EmitError.SignalsBlocked,
        .err_method_not_found => return EmitError.MethodNotFound,
        else => unreachable,
    }
}

/// Returns Signal if no fields allocate, otherwise generates a compile error.
fn AssertNonAllocating(comptime SignalType: type) type {
    const fields = meta.structFields(SignalType);
    inline for (fields) |field| {
        if (allocatesAsVariant(field.type)) {
            @compileError("Signal field '" ++ field.name ++ "' has type " ++ @typeName(field.type) ++
                " which allocates when wrapped in Variant. Use emitAlloc instead.");
        }
    }
    return SignalType;
}

const allocatesAsVariant = Variant.Tag.allocatesForType;

const ConnectError = gdzig.ConnectError;
const EmitError = gdzig.EmitError;
const class = gdzig.class;

const DestroyInstanceBinding = gdzig.extension.DestroyInstanceBinding;
const meta = @import("../meta.zig");

const object_is_class_compat = @import("../godot_4_6.zig");

// @mixin stop

const Self = gdzig.class.Object;
const self_name = "Object";

const std = @import("std");

const c = @import("gdextension");

const gdzig = @import("gdzig");
const raw = &gdzig.raw;
const Callable = gdzig.builtin.Callable;
const Object = gdzig.class.Object;
const StringName = gdzig.builtin.StringName;
const Variant = gdzig.builtin.Variant;
