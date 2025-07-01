/// Create a Godot object.
pub fn create(comptime T: type) !*T {
    // TODO: I don't think this class can handle nested user types (MyType { base: Node } and MyTypeSubtype { base: MyType })
    debug.assertIsObject(T);

    const class_name = meta.getNamePtr(T);
    const base_name = meta.getNamePtr(meta.BaseOf(T));

    // TODO: shouldn't we use Godot's allocator? can this be done without a double allocation?
    const ptr = godot.interface.classdbConstructObject2(@ptrCast(base_name)).?;
    const self = try godot.heap.general_allocator.create(T);

    // Store the pointer on base type
    if (T == godot.class.Object) {
        self.ptr = ptr;
    } else {
        self.base = @bitCast(godot.class.Object{ .ptr = ptr });
    }

    godot.interface.objectSetInstance(ptr, @ptrCast(class_name), @ptrCast(self));
    godot.interface.objectSetInstanceBinding(ptr, godot.interface.library, @ptrCast(self), @ptrCast(&dummy_callbacks));

    // TODO: doesn't Godot call `_init`? shouldn't we let `init` call `heap.create()`?
    //       Proper hierarchy of control is not clear here
    if (@hasDecl(T, "init")) {
        self.init();
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

    const ptr = meta.asObjectPtr(instance);
    godot.interface.objectFreeInstanceBinding(ptr, godot.interface.library);
    godot.interface.objectDestroy(ptr);
}

/// Unreference a Godot object.
pub fn unreference(instance: anytype) void {
    if (meta.asRefCounted(instance).unreference()) {
        godot.interface.objectDestroy(meta.asObjectPtr(instance));
    }
}

pub fn connect(obj: anytype, comptime signal_name: [:0]const u8, instance: anytype, comptime method_name: [:0]const u8) void {
    if (@typeInfo(@TypeOf(instance)) != .pointer) {
        @compileError("pointer type expected for parameter 'instance'");
    }
    // TODO: I think this is a memory leak??
    godot.register.registerMethod(std.meta.Child(@TypeOf(instance)), method_name);
    const callable = Callable.initObjectMethod(.{ .ptr = meta.asObjectPtr(instance) }, .fromComptimeLatin1(method_name));
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
