const std = @import("std");

const godot = @import("gdzig.zig");
const c = godot.c;
const Callable = godot.builtin.Callable;
const debug = godot.debug;
const meta = godot.meta;
const Object = godot.class.Object;
const PropertyHint = godot.global.PropertyHint;
const PropertyUsageFlags = godot.global.PropertyUsageFlags;
const String = godot.builtin.String;
const StringName = godot.builtin.StringName;

fn assertCanInitialize(comptime T: type) void {
    comptime {
        if (@hasDecl(T, "init")) return;
        for (@typeInfo(T).@"struct".fields) |field| {
            if (std.mem.eql(u8, "base", field.name)) continue;
            if (field.default_value_ptr == null) {
                @compileError("The type '" ++ meta.getTypeShortName(T) ++ "' should either have an 'fn init(base: *" ++ meta.getTypeShortName(meta.BaseOf(T)) ++ ") " ++ meta.getTypeShortName(T) ++ "' function, or a default value for the field '" ++ field.name ++ "', but it has neither.");
            }
        }
    }
}

/// Create a Godot object.
pub fn create(comptime T: type) !*T {
    comptime debug.assertIsObject(T);

    // If this is an engine type, just return it.
    if (comptime @typeInfo(T) == .@"opaque") {
        return @ptrCast(godot.interface.classdbConstructObject2(@ptrCast(meta.getNamePtr(T))).?);
    }

    // Assert that we can initialize the user type
    comptime {
        if (!@hasDecl(T, "init")) {
            for (@typeInfo(T).@"struct".fields) |field| {
                if (std.mem.eql(u8, "base", field.name)) continue;
                if (field.default_value_ptr == null) {
                    @compileError("The type '" ++ meta.getTypeShortName(T) ++ "' should either have an 'fn init(base: *" ++ meta.getTypeShortName(meta.BaseOf(T)) ++ ") " ++ meta.getTypeShortName(T) ++ "' function, or a default value for the field '" ++ field.name ++ "', but it has neither.");
                }
            }
        }
    }

    // Construct the base object
    const base_name = meta.getNamePtr(meta.BaseOf(T));
    const base: *meta.BaseOf(T) = @ptrCast(godot.interface.classdbConstructObject2(@ptrCast(base_name)).?);

    // Allocate the user object, and link it to the base object
    const class_name = meta.getNamePtr(T);
    const self: *T = try godot.heap.general_allocator.create(T);
    godot.interface.objectSetInstance(@ptrCast(base), @ptrCast(class_name), @ptrCast(self));

    // Initialize the user object
    if (@hasDecl(T, "init")) {
        self.* = T.init(base);
    } else {
        self.* = .{ .base = base };
    }

    return self;
}

/// Recreate a Godot object.
pub fn recreate(comptime T: type, ptr: ?*anyopaque) !*T {
    debug.assertIsObject(T);
    _ = ptr;
    @panic("Extension reloading is not currently supported");
}

/// Destroy a Godot object.
pub fn destroy(instance: anytype) void {
    debug.assertIsObject(@TypeOf(instance));

    const ptr: *anyopaque = @ptrCast(meta.asObject(instance));
    godot.interface.objectFreeInstanceBinding(ptr, godot.interface.library);
    godot.interface.objectDestroy(ptr);
}

/// Unreference a Godot object.
pub fn unreference(instance: anytype) void {
    if (meta.asRefCounted(instance).unreference()) {
        godot.interface.objectDestroy(@ptrCast(meta.asObject(instance)));
    }
}

pub fn connect(obj: anytype, comptime signal_name: [:0]const u8, instance: anytype, comptime method_name: [:0]const u8) void {
    if (@typeInfo(@TypeOf(instance)) != .pointer) {
        @compileError("pointer type expected for parameter 'instance'");
    }
    // TODO: I think this is a memory leak??
    godot.register.registerMethod(std.meta.Child(@TypeOf(instance)), method_name);
    const callable = Callable.initObjectMethod(@ptrCast(meta.asObject(instance)), .fromComptimeLatin1(method_name));
    _ = obj.connect(.fromComptimeLatin1(signal_name), callable, .{});
}

pub const PropertyInfo = struct {
    type: c.GDExtensionVariantType = c.GDEXTENSION_VARIANT_TYPE_NIL,
    name: StringName,
    class_name: StringName,
    hint: u32 = @intFromEnum(PropertyHint.property_hint_none),
    hint_string: String,
    usage: u32 = @bitCast(PropertyUsageFlags.property_usage_default),
    const Self = @This();

    pub fn init(@"type": c.GDExtensionVariantType, name: StringName) Self {
        return .{
            .type = @"type",
            .name = name,
            .hint_string = String.fromUtf8("test property"),
            .class_name = StringName.fromLatin1(""),
            .hint = @intFromEnum(PropertyHint.property_hint_none),
            .usage = @bitCast(PropertyUsageFlags.property_usage_default),
        };
    }

    pub fn initFull(@"type": c.GDExtensionVariantType, name: StringName, class_name: StringName, hint: PropertyHint, hint_string: String, usage: PropertyUsageFlags) Self {
        return .{
            .type = @"type",
            .name = name,
            .class_name = class_name,
            .hint_string = hint_string,
            .hint = @bitCast(hint),
            .usage = @bitCast(usage),
        };
    }
};

var dummy_callbacks = c.GDExtensionInstanceBindingCallbacks{ .create_callback = instanceBindingCreateCallback, .free_callback = instanceBindingFreeCallback, .reference_callback = instanceBindingReferenceCallback };
fn instanceBindingCreateCallback(_: ?*anyopaque, _: ?*anyopaque) callconv(.C) ?*anyopaque {
    return null;
}
fn instanceBindingFreeCallback(_: ?*anyopaque, _: ?*anyopaque, _: ?*anyopaque) callconv(.C) void {}
fn instanceBindingReferenceCallback(_: ?*anyopaque, _: ?*anyopaque, _: c.GDExtensionBool) callconv(.C) c.GDExtensionBool {
    return 1;
}
