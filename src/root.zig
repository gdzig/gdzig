const std = @import("std");

pub const c = @import("gdextension");
pub const core = @import("bindings/core.zig");
pub const global = @import("bindings/core.zig").global;

pub const debug = @import("debug.zig");
pub const heap = @import("heap.zig");
pub const meta = @import("meta.zig");
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

pub fn unreference(refcounted_obj: anytype) void {
    if (refcounted_obj.unreference()) {
        core.objectDestroy(refcounted_obj.godot_object);
    }
}

pub fn getClassName(comptime T: type) *core.StringName {
    const Static = struct {
        pub fn makeItUniqueForT() i8 {
            return @sizeOf(T);
        }
        pub var class_name: core.StringName = undefined;
    };
    return &Static.class_name;
}

pub fn getParentClassName(comptime T: type) *core.StringName {
    const Static = struct {
        pub fn makeItUniqueForT() i8 {
            return @sizeOf(T);
        }
        pub var parent_class_name: core.StringName = undefined;
    };
    return &Static.parent_class_name;
}

pub fn stringNameToAscii(strname: core.StringName, buf: []u8) []const u8 {
    const str = core.String.initFromStringName(strname);
    return stringToAscii(str, buf);
}

pub fn stringToAscii(str: core.String, buf: []u8) []const u8 {
    const sz = core.stringToLatin1Chars(@ptrCast(&str), &buf[0], @intCast(buf.len));
    return buf[0..@intCast(sz)];
}

fn getBaseName(str: []const u8) []const u8 {
    const pos = std.mem.lastIndexOfScalar(u8, str, '.') orelse return str;
    return str[pos + 1 ..];
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

pub fn getGodotObjectPtr(inst: anytype) *const ?*anyopaque {
    const typeInfo = @typeInfo(@TypeOf(inst));
    if (typeInfo != .pointer) {
        @compileError("pointer required");
    }
    const T = typeInfo.pointer.child;
    if (@hasField(T, "godot_object")) {
        return &inst.godot_object;
    } else if (@hasField(T, "base")) {
        return getGodotObjectPtr(&inst.base);
    }
}

pub fn cast(comptime T: type, inst: anytype) ?T {
    if (@typeInfo(@TypeOf(inst)) == .optional) {
        if (inst) |i| {
            return .{ .godot_object = i.godot_object };
        } else {
            return null;
        }
    } else {
        return .{ .godot_object = inst.godot_object };
    }
}

pub fn castSafe(comptime TargetType: type, object: anytype) ?TargetType {
    const classTag = core.classdbGetClassTag(@ptrCast(getClassName(TargetType)));
    const casted = core.objectCastTo(object.godot_object, classTag);
    if (casted) |obj| {
        return TargetType{ .godot_object = obj };
    }
    return null;
}

pub fn create(comptime T: type) !*T {
    const self = try general_allocator.create(T);
    self.base = .{ .godot_object = core.classdbConstructObject2(@ptrCast(getParentClassName(T))) };
    core.objectSetInstance(self.base.godot_object, @ptrCast(getClassName(T)), @ptrCast(self));
    core.objectSetInstanceBinding(self.base.godot_object, core.p_library, @ptrCast(self), @ptrCast(&dummy_callbacks));
    if (@hasDecl(T, "init")) {
        self.init();
    }
    return self;
}

//for extension reloading
fn recreate(comptime T: type, obj: ?*anyopaque) !*T {
    const self = try general_allocator.create(T);
    self.* = std.mem.zeroInit(T, .{});
    self.base = .{ .godot_object = obj };
    core.objectSetInstance(self.base.godot_object, @ptrCast(getClassName(T)), @ptrCast(self));
    core.objectSetInstanceBinding(self.base.godot_object, core.p_library, @ptrCast(self), @ptrCast(&dummy_callbacks));
    if (@hasDecl(T, "init")) {
        self.init();
    }
    return self;
}

pub fn destroy(instance: anytype) void {
    if (@hasField(@TypeOf(instance), "godot_object")) {
        core.objectFreeInstanceBinding(instance.godot_object, core.p_library);
        core.objectDestroy(instance.godot_object);
    } else {
        @compileError("only engine object can be destroyed");
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

var registered_classes: std.StringHashMap(bool) = undefined;
pub fn registerClass(comptime T: type) void {
    const class_name = getBaseName(@typeName(T));
    //prevent duplicate registration
    if (registered_classes.contains(class_name)) return;
    registered_classes.put(class_name, true) catch unreachable;

    const P = std.meta.FieldType(T, .base);
    const parent_class_name = comptime getBaseName(@typeName(P));
    getParentClassName(T).* = core.StringName.initFromUtf8Chars(parent_class_name);
    getClassName(T).* = core.StringName.initFromUtf8Chars(class_name);

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
                .get_property_list_func = if (@hasDecl(T, "_get_property_list")) getPropertyListBind else null,
                .property_can_revert_func = if (@hasDecl(T, "_property_can_revert")) propertyCanRevertBind else null,
                .property_get_revert_func = if (@hasDecl(T, "_property_get_revert")) propertyGetRevertBind else null,
                .validate_property_func = if (@hasDecl(T, "_validate_property")) validatePropertyBind else null,
                .notification_func = if (@hasDecl(T, "_notification")) notificationBind else null,
                .to_string_func = if (@hasDecl(T, "_to_string")) toStringBind else null,
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
                const property_list = T._get_property_list(ptr);

                const count: u32 = @intCast(property_list.len);

                const propertyies: [*c]c.GDExtensionPropertyInfo = @ptrCast(@alignCast(alloc(@sizeOf(c.GDExtensionPropertyInfo) * count)));
                for (property_list, 0..) |*property, i| {
                    propertyies[i].type = property.type;
                    propertyies[i].hint = property.hint;
                    propertyies[i].usage = property.usage;
                    propertyies[i].name = @ptrCast(@constCast(&property.name.value));
                    propertyies[i].class_name = @ptrCast(@constCast(&property.class_name.value));
                    propertyies[i].hint_string = @ptrCast(@constCast(&property.hint_string.value));
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
            if (@hasDecl(T, "_free_property_list")) {
                if (p_instance) |p| {
                    T._free_property_list(@ptrCast(@alignCast(p)), p_list); //fn _free_property_list(self:*Self, p_list:[*c]const c.GDExtensionPropertyInfo) void {}
                }
            }
            if (p_list) |list| {
                free(@ptrCast(@constCast(list)));
            }
        }

        pub fn freePropertyListBind2(p_instance: c.GDExtensionClassInstancePtr, p_list: [*c]const c.GDExtensionPropertyInfo, p_count: u32) callconv(.C) void {
            if (@hasDecl(T, "_free_property_list")) {
                if (p_instance) |p| {
                    T._free_property_list(@ptrCast(@alignCast(p)), p_list, p_count); //fn _free_property_list(self:*Self, p_list:[*c]const c.GDExtensionPropertyInfo, p_count:u32) void {}
                }
            }
            if (p_list) |list| {
                free(@ptrCast(@constCast(list)));
            }
        }

        pub fn propertyCanRevertBind(p_instance: c.GDExtensionClassInstancePtr, p_name: c.GDExtensionConstStringNamePtr) callconv(.C) c.GDExtensionBool {
            if (p_instance) |p| {
                return if (T._property_can_revert(@ptrCast(@alignCast(p)), @as(*core.StringName, @ptrCast(@constCast(p_name))).*)) 1 else 0; //fn _property_can_revert(self:*Self, name: core.StringName) bool
            } else {
                return 0;
            }
        }

        pub fn propertyGetRevertBind(p_instance: c.GDExtensionClassInstancePtr, p_name: c.GDExtensionConstStringNamePtr, r_ret: c.GDExtensionVariantPtr) callconv(.C) c.GDExtensionBool {
            if (p_instance) |p| {
                return if (T._property_get_revert(@ptrCast(@alignCast(p)), @as(*core.StringName, @ptrCast(@constCast(p_name))).*, @as(*Variant, @ptrCast(@alignCast(r_ret))))) 1 else 0; //fn _property_get_revert(self:*Self, name: core.StringName, ret:*Variant) bool
            } else {
                return 0;
            }
        }

        pub fn validatePropertyBind(p_instance: c.GDExtensionClassInstancePtr, p_property: [*c]c.GDExtensionPropertyInfo) callconv(.C) c.GDExtensionBool {
            if (p_instance) |p| {
                return if (T._validate_property(@ptrCast(@alignCast(p)), p_property)) 1 else 0; //fn _validate_property(self:*Self, p_property: [*c]c.GDExtensionPropertyInfo) bool
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
                const ret: ?core.String = T._to_string(@ptrCast(@alignCast(p))); //fn _to_string(self:*Self) ?Godot.core.String {}
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
            const ret = create(T) catch unreachable;
            return @ptrCast(ret.base.godot_object);
        }

        pub fn recreateInstanceBind(p_class_userdata: ?*anyopaque, p_object: c.GDExtensionObjectPtr) callconv(.C) c.GDExtensionClassInstancePtr {
            _ = p_class_userdata;
            const ret = recreate(T, p_object) catch unreachable;
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
            return T._get_rid(@ptrCast(@alignCast(p_instance)));
        }
    };

    const classdbRegisterExtensionClass = if (@hasDecl(core, "classdbRegisterExtensionClass3"))
        core.classdbRegisterExtensionClass3
    else if (@hasDecl(core, "classdbRegisterExtensionClass2"))
        core.classdbRegisterExtensionClass2
    else
        @compileError("Godot 4.2 or higher is required.");

    classdbRegisterExtensionClass(@ptrCast(core.p_library), @ptrCast(getClassName(T)), @ptrCast(getParentClassName(T)), @ptrCast(&PerClassData.class_info));

    if (@hasDecl(T, "_bind_methods")) {
        T._bind_methods();
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
            switch (@typeInfo(T)) {
                // .pointer => |pointer| {
                //     const ObjectType = pointer.child;
                //     const ObjectTypeName = comptime getBaseName(@typeName(ObjectType));
                //     const callbacks = @field(ObjectType, "callbacks_" ++ ObjectTypeName);
                //     if (@hasDecl(ObjectType, "reference") and @hasDecl(ObjectType, "unreference")) { //RefCounted
                //         const obj = core.refGetObject(p_arg);
                //         return @ptrCast(@alignCast(core.objectGetInstanceBinding(obj, core.p_library, @ptrCast(&callbacks))));
                //     } else { //normal Object*
                //         return @ptrCast(@alignCast(core.objectGetInstanceBinding(p_arg, core.p_library, @ptrCast(&callbacks))));
                //     }
                // },
                .@"struct" => {
                    if (@hasDecl(T, "reference") and @hasDecl(T, "unreference")) { //RefCounted
                        const obj = core.refGetObject(p_arg);
                        return .{ .godot_object = obj };
                    } else if (@hasField(T, "godot_object")) {
                        return .{ .godot_object = p_arg };
                    } else {
                        return @as(*T, @ptrCast(@constCast(@alignCast(p_arg)))).*;
                    }
                },
                else => {
                    return @as(*T, @ptrCast(@constCast(@alignCast(p_arg)))).*;
                },
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

var registered_methods: std.StringHashMap(bool) = undefined;
pub fn registerMethod(comptime T: type, comptime name: [:0]const u8) void {
    //prevent duplicate registration
    const fullname = std.mem.concat(general_allocator, u8, &[_][]const u8{ getBaseName(@typeName(T)), "::", name }) catch unreachable;
    if (registered_methods.contains(fullname)) {
        general_allocator.free(fullname);
        return;
    }
    registered_methods.put(fullname, true) catch unreachable;

    const p_method = @field(T, name);
    const MethodBinder = MethodBinderT(@TypeOf(p_method));

    MethodBinder.method_name = core.StringName.initFromLatin1Chars(name);
    MethodBinder.arg_metadata[0] = c.GDEXTENSION_METHOD_ARGUMENT_METADATA_NONE;
    MethodBinder.arg_properties[0] = c.GDExtensionPropertyInfo{
        .type = @intFromEnum(Variant.Tag.forType(MethodBinder.ReturnType.?)),
        .name = @ptrCast(@constCast(&core.StringName.init())),
        .class_name = @ptrCast(@constCast(&core.StringName.init())),
        .hint = @intFromEnum(global.PropertyHint.property_hint_none),
        .hint_string = @ptrCast(@constCast(&core.String.init())),
        .usage = @bitCast(global.PropertyUsage.property_usage_none),
    };

    inline for (1..MethodBinder.ArgCount) |i| {
        MethodBinder.arg_properties[i] = c.GDExtensionPropertyInfo{
            .type = @intFromEnum(Variant.Tag.forType(MethodBinder.ArgsTuple[i].type)),
            .name = @ptrCast(@constCast(&core.StringName.init())),
            .class_name = getClassName(MethodBinder.ArgsTuple[i].type),
            .hint = @intFromEnum(global.PropertyHint.property_hint_none),
            .hint_string = @ptrCast(@constCast(&core.String.init())),
            .usage = @bitCast(global.PropertyUsage.property_usage_none),
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

    core.classdbRegisterExtensionClassMethod(core.p_library, getClassName(T), &MethodBinder.method_info);
}

var registered_signals: std.StringHashMap(bool) = undefined;
pub fn registerSignal(comptime T: type, comptime signal_name: [:0]const u8, arguments: []const PropertyInfo) void {
    //prevent duplicate registration
    const fullname = std.mem.concat(general_allocator, u8, &[_][]const u8{ getBaseName(@typeName(T)), "::", signal_name }) catch unreachable;
    if (registered_signals.contains(fullname)) {
        general_allocator.free(fullname);
        return;
    }
    registered_signals.put(fullname, true) catch unreachable;

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
        core.classdbRegisterExtensionClassSignal(core.p_library, getClassName(T), &core.StringName.initFromLatin1Chars(signal_name), &propertyies[0], @intCast(arguments.len));
    } else {
        core.classdbRegisterExtensionClassSignal(core.p_library, getClassName(T), &core.StringName.initFromLatin1Chars(signal_name), null, 0);
    }
}

pub fn connect(godot_object: anytype, signal_name: [:0]const u8, instance: anytype, comptime method_name: [:0]const u8) void {
    if (@typeInfo(@TypeOf(instance)) != .pointer) {
        @compileError("pointer type expected for parameter 'instance'");
    }
    registerMethod(std.meta.Child(@TypeOf(instance)), method_name);
    const callable = core.Callable.initFromObjectStringName(instance, method_name);
    _ = godot_object.connect(signal_name, callable, 0);
}

pub fn init() void {
    registered_classes = std.StringHashMap(bool).init(general_allocator);
    registered_methods = std.StringHashMap(bool).init(general_allocator);
    registered_signals = std.StringHashMap(bool).init(general_allocator);
}

pub fn deinit() void {
    var key_iter = registered_classes.keyIterator();
    while (key_iter.next()) |it| {
        var class_name = core.StringName.initFromUtf8Chars(it.*);
        core.classdbUnregisterExtensionClass(core.p_library, @ptrCast(&class_name));
    }

    var key_iter1 = registered_methods.keyIterator();
    while (key_iter1.next()) |it| {
        general_allocator.free(it.*);
    }

    var key_iter2 = registered_signals.keyIterator();
    while (key_iter2.next()) |it| {
        general_allocator.free(it.*);
    }
    //core.deinitCore();
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
    usage: u32 = @bitCast(global.PropertyUsage.property_usage_default),
    const Self = @This();

    pub fn init(@"type": c.GDExtensionVariantType, name: core.StringName) Self {
        return .{
            .type = @"type",
            .name = name,
            .hint_string = core.String.initFromUtf8Chars("test property"),
            .class_name = core.StringName.initFromLatin1Chars(""),
            .hint = @intFromEnum(global.PropertyHint.property_hint_none),
            .usage = @bitCast(global.PropertyUsage.property_usage_default),
        };
    }

    pub fn initFull(@"type": c.GDExtensionVariantType, name: core.StringName, class_name: core.StringName, hint: global.PropertHint, hint_string: core.String, usage: global.PropertyUsage) Self {
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
