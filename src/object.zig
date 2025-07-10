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

/// Binds an extension class to a Godot object. This function should be called before any other function on the object.
pub fn bind(object: anytype) void {
    if (!meta.isExtensionClassPtr(object)) {
        @compileError("The type '" ++ meta.getTypeShortName(@TypeOf(object)) ++ "' is not an extension class pointer.");
    }

    const class_name = meta.getNamePtr(meta.Child(@TypeOf(object)));

    godot.interface.objectSetInstance(@ptrCast(object.base), @ptrCast(class_name), @ptrCast(object));
    godot.interface.objectSetInstanceBinding(@ptrCast(object.base), godot.interface.library, @ptrCast(object), &dummy_callbacks);
}

/// Create a Godot object.
pub fn create(comptime T: type) !*T {
    comptime debug.assertIsObjectType(T);

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
    godot.interface.objectSetInstanceBinding(@ptrCast(base), godot.interface.library, @ptrCast(self), &dummy_callbacks);

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
    debug.assertIsObjectType(T);
    _ = ptr;
    @panic("Extension reloading is not currently supported");
}

/// Destroy a Godot object.
pub fn destroy(instance: anytype) void {
    debug.assertIsObjectPtr(@TypeOf(instance));

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

pub const PropertyBuilder = struct {
    allocator: Allocator,
    properties: std.ArrayListUnmanaged(PropertyInfo) = .empty,

    pub fn init(allocator: Allocator) PropertyBuilder {
        return PropertyBuilder{
            .allocator = allocator,
        };
    }

    pub fn append(self: *PropertyBuilder, comptime T: type, comptime field_name: [:0]const u8, comptime opt: struct {
        hint: PropertyHint = .property_hint_none,
        hint_string: [:0]const u8 = "",
        usage: PropertyUsageFlags = .property_usage_default,
    }) !void {
        const info = try PropertyInfo.fromField(self.allocator, T, field_name, .{
            .hint = opt.hint,
            .hint_string = opt.hint_string,
            .usage = opt.usage,
        });
        try self.properties.append(self.allocator, info);
    }

    pub fn toOwnedSlice(self: *PropertyBuilder) ![]PropertyInfo {
        return self.properties.toOwnedSlice(self.allocator);
    }
};

pub const PropertyInfo = extern struct {
    type: Variant.Tag,
    name: ?*StringName = null,
    class_name: ?*StringName = null,
    hint: PropertyHint = .property_hint_none,
    hint_string: ?*String = null,
    usage: PropertyUsageFlags = .property_usage_default,

    pub fn init(allocator: Allocator, comptime tag: Variant.Tag, comptime field_name: [:0]const u8) !PropertyInfo {
        const name = try allocator.create(StringName);
        name.* = StringName.fromComptimeLatin1(field_name);

        return .{
            .name = name,
            .type = tag,
        };
    }

    pub fn fromField(allocator: Allocator, comptime T: type, comptime field_name: [:0]const u8, comptime opt: struct {
        hint: PropertyHint = .property_hint_none,
        hint_string: [:0]const u8 = "",
        usage: PropertyUsageFlags = .property_usage_default,
    }) !PropertyInfo {
        // This double allocation is dumb, but the API expects *String and *StringName
        const name = try allocator.create(StringName);
        name.* = StringName.fromComptimeLatin1(field_name);
        const hint_string = try allocator.create(String);
        hint_string.* = String.fromLatin1(opt.hint_string);

        return .{
            .class_name = meta.getNamePtr(T),
            .name = name,
            .type = Variant.Tag.forType(@FieldType(T, field_name)),
            .hint_string = hint_string,
            .hint = opt.hint,
            .usage = opt.usage,
        };
    }

    pub fn deinit(self: *PropertyInfo, allocator: Allocator) void {
        allocator.free(self.name);
        allocator.free(self.hint_string);
    }
};

pub var dummy_callbacks = c.GDExtensionInstanceBindingCallbacks{ .create_callback = instanceBindingCreateCallback, .free_callback = instanceBindingFreeCallback, .reference_callback = instanceBindingReferenceCallback };
fn instanceBindingCreateCallback(_: ?*anyopaque, _: ?*anyopaque) callconv(.C) ?*anyopaque {
    return null;
}
fn instanceBindingFreeCallback(_: ?*anyopaque, _: ?*anyopaque, _: ?*anyopaque) callconv(.C) void {}
fn instanceBindingReferenceCallback(_: ?*anyopaque, _: ?*anyopaque, _: c.GDExtensionBool) callconv(.C) c.GDExtensionBool {
    return 1;
}

const std = @import("std");
const Allocator = std.mem.Allocator;

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
const Variant = godot.builtin.Variant;
