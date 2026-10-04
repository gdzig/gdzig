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
/// Singleton classes accept only the class name, matching their other methods.
pub const isClass = if (object_is_class_singleton.owner(Self) != null) isClassForSingleton else isClassWithRuntimeAbi;

fn isClassForSingleton(p_class: StringName) bool {
    const Singleton = comptime object_is_class_singleton.owner(Self).?;
    if (comptime Singleton == Self) {
        // Use the API's exact name, not a lossy conversion from the Zig type
        // name (for example, Os must resolve the engine singleton named OS).
        if (Singleton.instance == null) {
            Singleton.instance = @ptrCast(raw.globalGetSingleton(@ptrCast(&StringName.fromComptimeLatin1(self_name))).?);
        }
        return isClassWithRuntimeAbi(@ptrCast(Singleton.instance.?), p_class);
    } else {
        // The owning class initializes its storage with its own exact API name.
        return Singleton.isClass(p_class);
    }
}

// Shared ABI adapter for the instance and singleton isClass entry points.
// The public API accepts StringName on both runtimes, but 4.6 ptrcall requires
// a temporary String. Selecting a compatibility hash does not perform conversion.
fn isClassWithRuntimeAbi(self: *const Self, p_class: StringName) bool {
    if (gdzig.version.gte(.@"4.7")) {
        return if (comptime object_is_class_singleton.owner(Self) != null) isClassRaw(p_class) else self.isClassRaw(p_class);
    }
    if (isClass_legacy_ptr == null) {
        isClass_legacy_ptr = raw.classdbGetMethodBind(@ptrCast(&StringName.fromComptimeLatin1("Object")), @ptrCast(&StringName.fromComptimeLatin1("is_class")), object_is_class_compat.godot_4_6.object_is_class);
    }
    var result: bool = false;
    var legacy_name: gdzig.builtin.String = .fromStringName(p_class);
    defer legacy_name.deinit();
    const args = [_]c.GDExtensionConstTypePtr{@ptrCast(&legacy_name)};
    raw.objectMethodBindPtrcall(isClass_legacy_ptr, @ptrCast(@constCast(self)), @ptrCast(&args), @ptrCast(&result));
    return result;
}
var isClass_legacy_ptr: c.GDExtensionMethodBindPtr = null;

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

const object_is_class_compat = @import("../compat/method_hashes.zig");
const object_is_class_singleton = @import("../compat/singleton.zig");

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
