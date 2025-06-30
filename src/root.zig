const std = @import("std");

pub const c = @import("gdextension");
pub const core = @import("bindings/core.zig");
pub const global = @import("bindings/core.zig").global;

pub const debug = @import("debug.zig");
pub const heap = @import("heap.zig");
pub const meta = @import("meta.zig");
pub const object = @import("object.zig");
pub const support = @import("support.zig");
pub const Variant = @import("Variant.zig").Variant;

pub var general_allocator: std.mem.Allocator = undefined;

const Vector = @import("vector");
pub const Vector2 = Vector.Vector2;
pub const Vector2i = Vector.Vector2i;
pub const Vector3 = Vector.Vector3;
pub const Vector3i = Vector.Vector3i;
pub const Vector4 = Vector.Vector4;
pub const Vector4i = Vector.Vector4i;

pub var dummy_callbacks = c.GDExtensionInstanceBindingCallbacks{ .create_callback = instanceBindingCreateCallback, .free_callback = instanceBindingFreeCallback, .reference_callback = instanceBindingReferenceCallback };
pub fn instanceBindingCreateCallback(_: ?*anyopaque, _: ?*anyopaque) callconv(.C) ?*anyopaque {
    return null;
}
pub fn instanceBindingFreeCallback(_: ?*anyopaque, _: ?*anyopaque, _: ?*anyopaque) callconv(.C) void {}
pub fn instanceBindingReferenceCallback(_: ?*anyopaque, _: ?*anyopaque, _: c.GDExtensionBool) callconv(.C) c.GDExtensionBool {
    return 1;
}

pub fn getObjectFromInstance(comptime T: type, obj: c.GDExtensionObjectPtr) ?*T {
    const retobj = core.objectGetInstanceBinding(obj, core.p_library, null);
    if (retobj) |r| {
        return @ptrCast(@alignCast(r));
    } else {
        return null;
    }
}

pub fn stringNameToAscii(strname: core.StringName, buf: []u8) []const u8 {
    const str = core.String.fromStringName(strname);
    return stringToAscii(str, buf);
}

pub fn stringToAscii(str: core.String, buf: []u8) []const u8 {
    const sz = core.stringToLatin1Chars(@ptrCast(&str), &buf[0], @intCast(buf.len));
    return buf[0..@intCast(sz)];
}

const max_align_t = c_longdouble;
const SIZE_OFFSET: usize = 0;
const ELEMENT_OFFSET = if ((SIZE_OFFSET + @sizeOf(u64)) % @alignOf(u64) == 0) (SIZE_OFFSET + @sizeOf(u64)) else ((SIZE_OFFSET + @sizeOf(u64)) + @alignOf(u64) - ((SIZE_OFFSET + @sizeOf(u64)) % @alignOf(u64)));
const DATA_OFFSET = if ((ELEMENT_OFFSET + @sizeOf(u64)) % @alignOf(max_align_t) == 0) (ELEMENT_OFFSET + @sizeOf(u64)) else ((ELEMENT_OFFSET + @sizeOf(u64)) + @alignOf(max_align_t) - ((ELEMENT_OFFSET + @sizeOf(u64)) % @alignOf(max_align_t)));

pub fn alloc(size: u32) ?[*]u8 {
    if (@import("builtin").mode == .Debug) {
        const p: [*c]u8 = @ptrCast(core.memAlloc(size));
        return p;
    } else {
        const p: [*c]u8 = @ptrCast(core.memAlloc(size + DATA_OFFSET));
        return @ptrCast(&p[DATA_OFFSET]);
    }
}

pub fn free(ptr: ?*anyopaque) void {
    if (ptr) |p| {
        core.memFree(p);
    }
}

const PluginCallback = ?*const fn (userdata: ?*anyopaque, p_level: c.GDExtensionInitializationLevel) void;

pub fn registerPlugin(p_get_proc_address: c.GDExtensionInterfaceGetProcAddress, p_library: c.GDExtensionClassLibraryPtr, r_initialization: [*c]c.GDExtensionInitialization, allocator: std.mem.Allocator, plugin_init_cb: PluginCallback, plugin_deinit_cb: PluginCallback) c.GDExtensionBool {
    const T = struct {
        var init_cb: PluginCallback = null;
        var deinit_cb: PluginCallback = null;
        fn initializeLevel(userdata: ?*anyopaque, p_level: c.GDExtensionInitializationLevel) callconv(.C) void {
            if (p_level == c.GDEXTENSION_INITIALIZATION_SCENE) {
                init();
            }

            if (init_cb) |cb| {
                cb(userdata, p_level);
            }
        }

        fn deinitializeLevel(userdata: ?*anyopaque, p_level: c.GDExtensionInitializationLevel) callconv(.C) void {
            if (p_level == c.GDEXTENSION_INITIALIZATION_SCENE) {
                deinit();
            }

            if (deinit_cb) |cb| {
                cb(userdata, p_level);
            }
        }
    };

    T.init_cb = plugin_init_cb;
    T.deinit_cb = plugin_deinit_cb;
    r_initialization.*.initialize = T.initializeLevel;
    r_initialization.*.deinitialize = T.deinitializeLevel;
    r_initialization.*.minimum_initialization_level = c.GDEXTENSION_INITIALIZATION_SCENE;
    general_allocator = allocator;
    core.initCore(p_get_proc_address.?, p_library) catch unreachable;
    return 1;
}

const ClassUserData = struct {
    class_name: []const u8,
};

var registered_classes: std.StringHashMap(void) = undefined;
pub fn registerClass(comptime T: type) void {
    const class_name = comptime meta.getTypeShortName(T);

    if (registered_classes.contains(class_name)) return;
    registered_classes.put(class_name, {}) catch unreachable;

    meta.getNamePtr(T).* = core.StringName.fromComptimeLatin1(class_name);

    const PerClassData = struct {
        pub var class_info = init_blk: {
            const ClassInfo: struct { T: type, version: i8 } = if (@hasDecl(c, "GDExtensionClassCreationInfo3"))
                .{ .T = c.GDExtensionClassCreationInfo3, .version = 3 }
            else if (@hasDecl(c, "GDExtensionClassCreationInfo2"))
                .{ .T = c.GDExtensionClassCreationInfo2, .version = 2 }
            else
                @compileError("Godot 4.2 or higher is required.");

            var info: ClassInfo.T = .{
                .is_virtual = 0,
                .is_abstract = 0,
                .is_exposed = 1,
                .set_func = if (@hasDecl(T, "_set")) setBind else null,
                .get_func = if (@hasDecl(T, "_get")) getBind else null,
                .get_property_list_func = if (@hasDecl(T, "_getPropertyList")) getPropertyListBind else null,
                .property_can_revert_func = if (@hasDecl(T, "_propertyCanRevert")) propertyCanRevertBind else null,
                .property_get_revert_func = if (@hasDecl(T, "_propertyGetRevert")) propertyGetRevertBind else null,
                .validate_property_func = if (@hasDecl(T, "_validateProperty")) validatePropertyBind else null,
                .notification_func = if (@hasDecl(T, "_notification")) notificationBind else null,
                .to_string_func = if (@hasDecl(T, "_toString")) toStringBind else null,
                .reference_func = null,
                .unreference_func = null,
                .create_instance_func = createInstanceBind, // (Default) constructor; mandatory. If the class is not instantiable, consider making it virtual or abstract.
                .free_instance_func = freeInstanceBind, // Destructor; mandatory.
                .recreate_instance_func = recreateInstanceBind,
                .get_virtual_func = getVirtualBind, // Queries a virtual function by name and returns a callback to invoke the requested virtual function.
                .get_virtual_call_data_func = null,
                .call_virtual_with_data_func = null,
                .get_rid_func = null,
                .class_userdata = @constCast(@ptrCast(&ClassUserData{
                    .class_name = @typeName(T),
                })), // Per-class user data, later accessible in instance bindings.
            };

            if (ClassInfo.version >= 3) {
                info.is_runtime = 0;
            }

            const t = @TypeOf(info.free_property_list_func);

            if (t == c.GDExtensionClassFreePropertyList) {
                info.free_property_list_func = freePropertyListBind;
            } else if (t == c.GDExtensionClassFreePropertyList2) {
                info.free_property_list_func = freePropertyListBind2;
            } else {
                @compileError(".free_property_list_func is an unknown type.");
            }

            break :init_blk info;
        };

        pub fn setBind(p_instance: c.GDExtensionClassInstancePtr, name: c.GDExtensionConstStringNamePtr, value: c.GDExtensionConstVariantPtr) callconv(.C) c.GDExtensionBool {
            if (p_instance) |p| {
                return if (T._set(@ptrCast(@alignCast(p)), @as(*core.StringName, @ptrCast(@constCast(name))).*, @as(*Variant, @ptrCast(@alignCast(@constCast(value)))).*)) 1 else 0; //fn _set(_: *Self, name: Godot.core.StringName, _: Godot.Variant) bool
            } else {
                return 0;
            }
        }

        pub fn getBind(p_instance: c.GDExtensionClassInstancePtr, name: c.GDExtensionConstStringNamePtr, value: c.GDExtensionVariantPtr) callconv(.C) c.GDExtensionBool {
            if (p_instance) |p| {
                return if (T._get(@ptrCast(@alignCast(p)), @as(*core.StringName, @ptrCast(@constCast(name))).*, @as(*Variant, @ptrCast(@alignCast(value))))) 1 else 0; //fn _get(self:*Self, name: core.StringName, value:*Variant) bool
            } else {
                return 0;
            }
        }

        pub fn getPropertyListBind(p_instance: c.GDExtensionClassInstancePtr, r_count: [*c]u32) callconv(.C) [*c]const c.GDExtensionPropertyInfo {
            if (p_instance) |p| {
                const ptr: *T = @ptrCast(@alignCast(p));
                const property_list = T._getPropertyList(ptr);

                const count: u32 = @intCast(property_list.len);

                const propertyies: [*c]c.GDExtensionPropertyInfo = @ptrCast(@alignCast(alloc(@sizeOf(c.GDExtensionPropertyInfo) * count)));
                for (property_list, 0..) |*property, i| {
                    propertyies[i].type = property.type;
                    propertyies[i].hint = property.hint;
                    propertyies[i].usage = property.usage;
                    propertyies[i].name = @ptrCast(@constCast(&property.name));
                    propertyies[i].class_name = @ptrCast(@constCast(&property.class_name));
                    propertyies[i].hint_string = @ptrCast(@constCast(&property.hint_string));
                }
                if (r_count) |r| {
                    r.* = count;
                }
                return propertyies;
            } else {
                if (r_count) |r| {
                    r.* = 0;
                }
                return null;
            }
        }

        pub fn freePropertyListBind(p_instance: c.GDExtensionClassInstancePtr, p_list: [*c]const c.GDExtensionPropertyInfo) callconv(.C) void {
            if (@hasDecl(T, "_freePropertyList")) {
                if (p_instance) |p| {
                    T._freePropertyList(@ptrCast(@alignCast(p)), p_list); //fn _free_property_list(self:*Self, p_list:[*c]const c.GDExtensionPropertyInfo) void {}
                }
            }
            if (p_list) |list| {
                free(@ptrCast(@constCast(list)));
            }
        }

        pub fn freePropertyListBind2(p_instance: c.GDExtensionClassInstancePtr, p_list: [*c]const c.GDExtensionPropertyInfo, p_count: u32) callconv(.C) void {
            if (@hasDecl(T, "_freePropertyList")) {
                if (p_instance) |p| {
                    T._freePropertyList(@ptrCast(@alignCast(p)), p_list, p_count); //fn _free_property_list(self:*Self, p_list:[*c]const c.GDExtensionPropertyInfo, p_count:u32) void {}
                }
            }
            if (p_list) |list| {
                free(@ptrCast(@constCast(list)));
            }
        }

        pub fn propertyCanRevertBind(p_instance: c.GDExtensionClassInstancePtr, p_name: c.GDExtensionConstStringNamePtr) callconv(.C) c.GDExtensionBool {
            if (p_instance) |p| {
                return if (T._propertyCanRevert(@ptrCast(@alignCast(p)), @as(*core.StringName, @ptrCast(@constCast(p_name))).*)) 1 else 0; //fn _property_can_revert(self:*Self, name: core.StringName) bool
            } else {
                return 0;
            }
        }

        pub fn propertyGetRevertBind(p_instance: c.GDExtensionClassInstancePtr, p_name: c.GDExtensionConstStringNamePtr, r_ret: c.GDExtensionVariantPtr) callconv(.C) c.GDExtensionBool {
            if (p_instance) |p| {
                return if (T._propertyGetRevert(@ptrCast(@alignCast(p)), @as(*core.StringName, @ptrCast(@constCast(p_name))).*, @as(*Variant, @ptrCast(@alignCast(r_ret))))) 1 else 0; //fn _property_get_revert(self:*Self, name: core.StringName, ret:*Variant) bool
            } else {
                return 0;
            }
        }

        pub fn validatePropertyBind(p_instance: c.GDExtensionClassInstancePtr, p_property: [*c]c.GDExtensionPropertyInfo) callconv(.C) c.GDExtensionBool {
            if (p_instance) |p| {
                return if (T._validateProperty(@ptrCast(@alignCast(p)), p_property)) 1 else 0; //fn _validate_property(self:*Self, p_property: [*c]c.GDExtensionPropertyInfo) bool
            } else {
                return 0;
            }
        }

        pub fn notificationBind(p_instance: c.GDExtensionClassInstancePtr, p_what: i32, _: c.GDExtensionBool) callconv(.C) void {
            if (p_instance) |p| {
                T._notification(@ptrCast(@alignCast(p)), p_what); //fn _notification(self:*Self, what:i32) void
            }
        }

        pub fn toStringBind(p_instance: c.GDExtensionClassInstancePtr, r_is_valid: [*c]c.GDExtensionBool, p_out: c.GDExtensionStringPtr) callconv(.C) void {
            if (p_instance) |p| {
                const ret: ?core.String = T._toString(@ptrCast(@alignCast(p))); //fn _to_string(self:*Self) ?Godot.core.String {}
                if (ret) |r| {
                    r_is_valid.* = 1;
                    @as(*core.String, @ptrCast(p_out)).* = r;
                }
            }
        }

        pub fn referenceBind(p_instance: c.GDExtensionClassInstancePtr) callconv(.C) void {
            T._reference(@ptrCast(@alignCast(p_instance)));
        }

        pub fn unreferenceBind(p_instance: c.GDExtensionClassInstancePtr) callconv(.C) void {
            T._unreference(@ptrCast(@alignCast(p_instance)));
        }

        pub fn createInstanceBind(p_userdata: ?*anyopaque) callconv(.C) c.GDExtensionObjectPtr {
            _ = p_userdata;
            const ret = object.create(T) catch unreachable;
            return @ptrCast(meta.asObjectPtr(ret));
        }

        pub fn recreateInstanceBind(p_class_userdata: ?*anyopaque, p_object: c.GDExtensionObjectPtr) callconv(.C) c.GDExtensionClassInstancePtr {
            _ = p_class_userdata;
            const ret = object.recreate(T, p_object) catch unreachable;
            return @ptrCast(ret);
        }

        pub fn freeInstanceBind(p_userdata: ?*anyopaque, p_instance: c.GDExtensionClassInstancePtr) callconv(.C) void {
            if (@hasDecl(T, "deinit")) {
                @as(*T, @ptrCast(@alignCast(p_instance))).deinit();
            }
            general_allocator.destroy(@as(*T, @ptrCast(@alignCast(p_instance))));
            _ = p_userdata;
        }

        fn getClassDataFromOpaque(p_class_userdata: ?*anyopaque) *const ClassUserData {
            return @alignCast(@ptrCast(p_class_userdata));
        }

        pub fn getVirtualBind(p_class_userdata: ?*anyopaque, p_name: c.GDExtensionConstStringNamePtr) callconv(.C) c.GDExtensionClassCallVirtual {
            const Base = std.meta.FieldType(T, .base);
            const virtual_bind = @field(Base, "getVirtualDispatch");
            return virtual_bind(T, p_class_userdata, p_name);
        }

        pub fn getRidBind(p_instance: c.GDExtensionClassInstancePtr) callconv(.C) u64 {
            return T._getRid(@ptrCast(@alignCast(p_instance)));
        }
    };

    const classdbRegisterExtensionClass = if (@hasDecl(core, "classdbRegisterExtensionClass3"))
        core.classdbRegisterExtensionClass3
    else if (@hasDecl(core, "classdbRegisterExtensionClass2"))
        core.classdbRegisterExtensionClass2
    else
        @compileError("Godot 4.2 or higher is required.");

    classdbRegisterExtensionClass(@ptrCast(core.p_library), @ptrCast(meta.getNamePtr(T)), @ptrCast(meta.getNamePtr(meta.BaseOf(T))), @ptrCast(&PerClassData.class_info));

    if (@hasDecl(T, "_bind_methods")) {
        T._bindMethods();
    }
}

pub fn MethodBinderT(comptime MethodType: type) type {
    return struct {
        const ReturnType = @typeInfo(MethodType).@"fn".return_type;
        const ArgCount = @typeInfo(MethodType).@"fn".params.len;
        const ArgsTuple = std.meta.fields(std.meta.ArgsTuple(MethodType));
        var arg_properties: [ArgCount + 1]c.GDExtensionPropertyInfo = undefined;
        var arg_metadata: [ArgCount + 1]c.GDExtensionClassMethodArgumentMetadata = undefined;
        var method_name: core.StringName = undefined;
        var method_info: c.GDExtensionClassMethodInfo = undefined;

        pub fn bindCall(p_method_userdata: ?*anyopaque, p_instance: c.GDExtensionClassInstancePtr, p_args: [*c]const c.GDExtensionConstVariantPtr, p_argument_count: c.GDExtensionInt, p_return: c.GDExtensionVariantPtr, p_error: [*c]c.GDExtensionCallError) callconv(.C) void {
            _ = p_error;
            const method: *MethodType = @ptrCast(@alignCast(p_method_userdata));
            if (ArgCount == 0) {
                if (ReturnType == void or ReturnType == null) {
                    @call(.auto, method, .{});
                } else {
                    @as(*Variant, @ptrCast(p_return)).* = Variant.init(@call(.auto, method, .{}));
                }
            } else {
                var variants: [ArgCount - 1]Variant = undefined;
                var args: std.meta.ArgsTuple(MethodType) = undefined;
                args[0] = @ptrCast(@alignCast(p_instance));
                inline for (0..ArgCount - 1) |i| {
                    if (i < p_argument_count) {
                        core.variantNewCopy(@ptrCast(&variants[i]), @ptrCast(p_args[i]));
                    }

                    args[i + 1] = variants[i].as(ArgsTuple[i + 1].type);
                }
                if (ReturnType == void or ReturnType == null) {
                    @call(.auto, method, args);
                } else {
                    @as(*Variant, @ptrCast(p_return)).* = Variant.init(@call(.auto, method, args));
                }
            }
        }

        fn ptrToArg(comptime T: type, p_arg: c.GDExtensionConstTypePtr) T {
            // TODO: I think this does not increment refcount on user-defined RefCounted types
            if (comptime meta.isRefCounted(T) and meta.isWrappedPointer(T)) {
                const obj = core.refGetObject(p_arg);
                return @bitCast(core.Object{ .ptr = obj.? });
            } else if (comptime meta.isObject(T) and meta.isWrappedPointer(T)) {
                return @bitCast(core.Object{ .ptr = @constCast(p_arg.?) });
            } else {
                return @as(*T, @ptrCast(@constCast(@alignCast(p_arg)))).*;
            }
        }

        pub fn bindPtrcall(p_method_userdata: ?*anyopaque, p_instance: c.GDExtensionClassInstancePtr, p_args: [*c]const c.GDExtensionConstTypePtr, p_return: c.GDExtensionTypePtr) callconv(.C) void {
            const method: *MethodType = @ptrCast(@alignCast(p_method_userdata));
            if (ArgCount == 0) {
                if (ReturnType == void or ReturnType == null) {
                    @call(.auto, method, .{});
                } else {
                    @as(*ReturnType.?, @ptrCast(@alignCast(p_return))).* = @call(.auto, method, .{});
                }
            } else {
                var args: std.meta.ArgsTuple(MethodType) = undefined;
                args[0] = @ptrCast(@alignCast(p_instance));
                inline for (1..ArgCount) |i| {
                    args[i] = ptrToArg(ArgsTuple[i].type, p_args[i - 1]);
                }
                if (ReturnType == void or ReturnType == null) {
                    @call(.auto, method, args);
                } else {
                    @as(*ReturnType.?, @ptrCast(@alignCast(p_return))).* = @call(.auto, method, args);
                }
            }
        }
    };
}

var registered_methods: std.StringHashMap(void) = undefined;
pub fn registerMethod(comptime T: type, comptime name: [:0]const u8) void {
    //prevent duplicate registration
    const fullname = std.mem.concat(general_allocator, u8, &[_][]const u8{ meta.getTypeShortName(T), "::", name }) catch unreachable;
    if (registered_methods.contains(fullname)) {
        general_allocator.free(fullname);
        return;
    }
    registered_methods.put(fullname, {}) catch unreachable;

    const p_method = @field(T, name);
    const MethodBinder = MethodBinderT(@TypeOf(p_method));

    MethodBinder.method_name = core.StringName.fromComptimeLatin1(name);
    MethodBinder.arg_metadata[0] = c.GDEXTENSION_METHOD_ARGUMENT_METADATA_NONE;
    MethodBinder.arg_properties[0] = c.GDExtensionPropertyInfo{
        .type = @intFromEnum(Variant.Tag.forType(MethodBinder.ReturnType.?)),
        .name = @ptrCast(@constCast(&core.StringName.init())),
        .class_name = @ptrCast(@constCast(&core.StringName.init())),
        .hint = @intFromEnum(global.PropertyHint.property_hint_none),
        .hint_string = @ptrCast(@constCast(&core.String.init())),
        .usage = @bitCast(global.PropertyUsageFlags.property_usage_none),
    };

    inline for (1..MethodBinder.ArgCount) |i| {
        MethodBinder.arg_properties[i] = c.GDExtensionPropertyInfo{
            .type = @intFromEnum(Variant.Tag.forType(MethodBinder.ArgsTuple[i].type)),
            .name = @ptrCast(@constCast(&core.StringName.init())),
            .class_name = meta.getNamePtr(MethodBinder.ArgsTuple[i].type),
            .hint = @intFromEnum(global.PropertyHint.property_hint_none),
            .hint_string = @ptrCast(@constCast(&core.String.init())),
            .usage = @bitCast(global.PropertyUsageFlags.property_usage_none),
        };

        MethodBinder.arg_metadata[i] = c.GDEXTENSION_METHOD_ARGUMENT_METADATA_NONE;
    }

    MethodBinder.method_info = c.GDExtensionClassMethodInfo{
        .name = @ptrCast(&MethodBinder.method_name),
        .method_userdata = @ptrCast(@constCast(&p_method)),
        .call_func = MethodBinder.bindCall,
        .ptrcall_func = MethodBinder.bindPtrcall,
        .method_flags = c.GDEXTENSION_METHOD_FLAG_NORMAL,
        .has_return_value = if (MethodBinder.ReturnType != void) 1 else 0,
        .return_value_info = @ptrCast(&MethodBinder.arg_properties[0]),
        .return_value_metadata = MethodBinder.arg_metadata[0],
        .argument_count = MethodBinder.ArgCount - 1,
        .arguments_info = @ptrCast(&MethodBinder.arg_properties[1]),
        .arguments_metadata = @ptrCast(&MethodBinder.arg_metadata[1]),
        .default_argument_count = 0,
        .default_arguments = null,
    };

    core.classdbRegisterExtensionClassMethod(core.p_library, meta.getNamePtr(T), &MethodBinder.method_info);
}

var registered_signals: std.StringHashMap(void) = undefined;
pub fn registerSignal(comptime T: type, comptime signal_name: [:0]const u8, arguments: []const PropertyInfo) void {
    //prevent duplicate registration
    const fullname = std.mem.concat(general_allocator, u8, &[_][]const u8{ meta.getTypeShortName(T), "::", signal_name }) catch unreachable;
    if (registered_signals.contains(fullname)) {
        general_allocator.free(fullname);
        return;
    }
    registered_signals.put(fullname, {}) catch unreachable;

    var propertyies: [32]c.GDExtensionPropertyInfo = undefined;
    if (arguments.len > 32) {
        std.log.err("why you need so many arguments for a single signal? whatever, you can increase the upper limit as you want", .{});
    }

    for (arguments, 0..) |*a, i| {
        propertyies[i].type = a.type;
        propertyies[i].hint = a.hint;
        propertyies[i].usage = a.usage;
        propertyies[i].name = @ptrCast(@constCast(&a.name));
        propertyies[i].class_name = @ptrCast(@constCast(&a.class_name));
        propertyies[i].hint_string = @ptrCast(@constCast(&a.hint_string));
    }

    if (arguments.len > 0) {
        core.classdbRegisterExtensionClassSignal(core.p_library, meta.getNamePtr(T), &core.StringName.fromLatin1(signal_name), &propertyies[0], @intCast(arguments.len));
    } else {
        core.classdbRegisterExtensionClassSignal(core.p_library, meta.getNamePtr(T), &core.StringName.fromLatin1(signal_name), null, 0);
    }
}

pub fn connect(obj: anytype, comptime signal_name: [:0]const u8, instance: anytype, comptime method_name: [:0]const u8) void {
    if (@typeInfo(@TypeOf(instance)) != .pointer) {
        @compileError("pointer type expected for parameter 'instance'");
    }
    // TODO: I think this is a memory leak??
    registerMethod(std.meta.Child(@TypeOf(instance)), method_name);
    const callable = core.Callable.initObjectMethod(.{ .ptr = meta.asObjectPtr(instance) }, .fromComptimeLatin1(method_name));
    _ = obj.connect(.fromComptimeLatin1(signal_name), callable, .{});
}

pub fn init() void {
    registered_classes = std.StringHashMap(void).init(general_allocator);
    registered_methods = std.StringHashMap(void).init(general_allocator);
    registered_signals = std.StringHashMap(void).init(general_allocator);
}

pub fn deinit() void {
    {
        var keys = registered_classes.keyIterator();
        while (keys.next()) |it| {
            var class_name = core.StringName.fromUtf8(it.*);
            defer class_name.deinit();
            core.classdbUnregisterExtensionClass(core.p_library, @ptrCast(&class_name));
        }
    }

    {
        var keys = registered_methods.keyIterator();
        while (keys.next()) |it| {
            general_allocator.free(it.*);
        }
    }

    {
        var keys = registered_signals.keyIterator();
        while (keys.next()) |it| {
            general_allocator.free(it.*);
        }
    }

    registered_signals.deinit();
    registered_methods.deinit();
    registered_classes.deinit();
}

pub const PropertyInfo = struct {
    type: c.GDExtensionVariantType = c.GDEXTENSION_VARIANT_TYPE_NIL,
    name: core.StringName,
    class_name: core.StringName,
    hint: u32 = @intFromEnum(global.PropertyHint.property_hint_none),
    hint_string: core.String,
    usage: u32 = @bitCast(global.PropertyUsageFlags.property_usage_default),
    const Self = @This();

    pub fn init(@"type": c.GDExtensionVariantType, name: core.StringName) Self {
        return .{
            .type = @"type",
            .name = name,
            .hint_string = core.String.fromUtf8("test property"),
            .class_name = core.StringName.fromLatin1(""),
            .hint = @intFromEnum(global.PropertyHint.property_hint_none),
            .usage = @bitCast(global.PropertyUsageFlags.property_usage_default),
        };
    }

    pub fn initFull(@"type": c.GDExtensionVariantType, name: core.StringName, class_name: core.StringName, hint: global.PropertHint, hint_string: core.String, usage: global.PropertyUsageFlags) Self {
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

comptime {
    _ = Variant;
}
