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
    heap.general_allocator = allocator;
    godot.interface = .init(p_get_proc_address.?, p_library.?);
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

    meta.getNamePtr(T).* = StringName.fromComptimeLatin1(class_name);

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
                .free_property_list_func = freePropertyListBind,
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
                @compileError("Unsupported version of Godot");
            } else if (t == c.GDExtensionClassFreePropertyList2) {
                info.free_property_list_func = freePropertyListBind;
            } else {
                @compileError(".free_property_list_func is an unknown type.");
            }
            break :init_blk info;
        };

        pub fn setBind(p_instance: c.GDExtensionClassInstancePtr, name: c.GDExtensionConstStringNamePtr, value: c.GDExtensionConstVariantPtr) callconv(.C) c.GDExtensionBool {
            if (p_instance) |p| {
                return if (T._set(@ptrCast(@alignCast(p)), @as(*StringName, @ptrCast(@constCast(name))).*, @as(*Variant, @ptrCast(@alignCast(@constCast(value)))).*)) 1 else 0; //fn _set(_: *Self, name: Godot.StringName, _: Godot.Variant) bool
            } else {
                return 0;
            }
        }

        pub fn getBind(p_instance: c.GDExtensionClassInstancePtr, name: c.GDExtensionConstStringNamePtr, value: c.GDExtensionVariantPtr) callconv(.C) c.GDExtensionBool {
            if (p_instance) |p| {
                return if (T._get(@ptrCast(@alignCast(p)), @as(*StringName, @ptrCast(@constCast(name))).*, @as(*Variant, @ptrCast(@alignCast(value))))) 1 else 0; //fn _get(self:*Self, name: StringName, value:*Variant) bool
            } else {
                return 0;
            }
        }

        pub fn getPropertyListBind(p_instance: c.GDExtensionClassInstancePtr, r_count: [*c]u32) callconv(.C) [*c]const c.GDExtensionPropertyInfo {
            if (p_instance) |p| {
                const ptr: *T = @ptrCast(@alignCast(p));

                var builder = object.PropertyBuilder{
                    .allocator = godot.heap.general_allocator,
                };
                ptr._getPropertyList(&builder) catch @panic("Failed to get property list");
                r_count.* = @intCast(builder.properties.items.len);

                return @ptrCast(@alignCast(builder.properties.items.ptr));
            } else {
                if (r_count) |r| {
                    r.* = 0;
                }
                return null;
            }
        }

        pub fn freePropertyListBind(p_instance: c.GDExtensionClassInstancePtr, p_list: [*c]const c.GDExtensionPropertyInfo, p_count: u32) callconv(.C) void {
            if (@hasDecl(T, "_freePropertyList")) {
                if (p_instance) |p| {
                    T._freePropertyList(@ptrCast(@alignCast(p)), p_list[0..p_count]); //fn _freePropertyList(self:*Self, p_list:[]const c.GDExtensionPropertyInfo) void {}
                }
            }
            if (p_list) |list| {
                heap.free(@ptrCast(@constCast(list)));
            }
        }

        pub fn propertyCanRevertBind(p_instance: c.GDExtensionClassInstancePtr, p_name: c.GDExtensionConstStringNamePtr) callconv(.C) c.GDExtensionBool {
            if (p_instance) |p| {
                return if (T._propertyCanRevert(@ptrCast(@alignCast(p)), @as(*StringName, @ptrCast(@constCast(p_name))).*)) 1 else 0; //fn _property_can_revert(self:*Self, name: StringName) bool
            } else {
                return 0;
            }
        }

        pub fn propertyGetRevertBind(p_instance: c.GDExtensionClassInstancePtr, p_name: c.GDExtensionConstStringNamePtr, r_ret: c.GDExtensionVariantPtr) callconv(.C) c.GDExtensionBool {
            if (p_instance) |p| {
                return if (T._propertyGetRevert(@ptrCast(@alignCast(p)), @as(*StringName, @ptrCast(@constCast(p_name))).*, @as(*Variant, @ptrCast(@alignCast(r_ret))))) 1 else 0; //fn _property_get_revert(self:*Self, name: StringName, ret:*Variant) bool
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
                const ret: ?String = T._toString(@ptrCast(@alignCast(p))); //fn _to_string(self:*Self) ?Godot.builtin.String {}
                if (ret) |r| {
                    r_is_valid.* = 1;
                    @as(*String, @ptrCast(p_out)).* = r;
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
            return @ptrCast(meta.asObject(ret));
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
            heap.general_allocator.destroy(@as(*T, @ptrCast(@alignCast(p_instance))));
            _ = p_userdata;
        }

        fn getClassDataFromOpaque(p_class_userdata: ?*anyopaque) *const ClassUserData {
            return @alignCast(@ptrCast(p_class_userdata));
        }

        pub fn getVirtualBind(p_class_userdata: ?*anyopaque, p_name: c.GDExtensionConstStringNamePtr) callconv(.C) c.GDExtensionClassCallVirtual {
            const virtual_bind = @field(meta.BaseOf(T), "getVirtualDispatch");
            return virtual_bind(T, p_class_userdata, p_name);
        }

        pub fn getRidBind(p_instance: c.GDExtensionClassInstancePtr) callconv(.C) u64 {
            return T._getRid(@ptrCast(@alignCast(p_instance)));
        }
    };

    const classdbRegisterExtensionClass = if (@hasField(Interface, "classdbRegisterExtensionClass3"))
        godot.interface.classdbRegisterExtensionClass3
    else if (@hasField(Interface, "classdbRegisterExtensionClass2"))
        godot.interface.classdbRegisterExtensionClass2
    else
        @compileError("Godot 4.2 or higher is required.");

    classdbRegisterExtensionClass(@ptrCast(godot.interface.library), @ptrCast(meta.getNamePtr(T)), @ptrCast(meta.getNamePtr(meta.BaseOf(T))), @ptrCast(&PerClassData.class_info));

    if (@hasDecl(T, "_bindMethods")) {
        T._bindMethods();
    }
}

var registered_methods: std.StringHashMap(void) = undefined;
pub fn registerMethod(comptime T: type, comptime name: [:0]const u8) void {
    //prevent duplicate registration
    const fullname = std.mem.concat(heap.general_allocator, u8, &[_][]const u8{ meta.getTypeShortName(T), "::", name }) catch unreachable;
    if (registered_methods.contains(fullname)) {
        heap.general_allocator.free(fullname);
        return;
    }
    registered_methods.put(fullname, {}) catch unreachable;

    const p_method = @field(T, name);
    const MethodBinder = support.MethodBinderT(@TypeOf(p_method));

    MethodBinder.method_name = StringName.fromComptimeLatin1(name);
    MethodBinder.arg_metadata[0] = c.GDEXTENSION_METHOD_ARGUMENT_METADATA_NONE;
    MethodBinder.arg_properties[0] = c.GDExtensionPropertyInfo{
        .type = @intFromEnum(Variant.Tag.forType(MethodBinder.ReturnType.?)),
        .name = @ptrCast(@constCast(&StringName.init())),
        .class_name = @ptrCast(@constCast(&StringName.init())),
        .hint = @intFromEnum(PropertyHint.property_hint_none),
        .hint_string = @ptrCast(@constCast(&String.init())),
        .usage = @bitCast(PropertyUsageFlags.property_usage_none),
    };

    inline for (1..MethodBinder.ArgCount) |i| {
        MethodBinder.arg_properties[i] = c.GDExtensionPropertyInfo{
            .type = @intFromEnum(Variant.Tag.forType(MethodBinder.ArgsTuple[i].type)),
            .name = @ptrCast(@constCast(&StringName.init())),
            .class_name = meta.getNamePtr(MethodBinder.ArgsTuple[i].type),
            .hint = @intFromEnum(PropertyHint.property_hint_none),
            .hint_string = @ptrCast(@constCast(&String.init())),
            .usage = @bitCast(PropertyUsageFlags.property_usage_none),
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

    godot.interface.classdbRegisterExtensionClassMethod(godot.interface.library, meta.getNamePtr(T), &MethodBinder.method_info);
}

var registered_signals: std.StringHashMap(void) = undefined;
pub fn registerSignal(comptime T: type, comptime signal_name: [:0]const u8, arguments: []const object.PropertyInfo) void {
    //prevent duplicate registration
    const fullname = std.mem.concat(heap.general_allocator, u8, &[_][]const u8{ meta.getTypeShortName(T), "::", signal_name }) catch unreachable;
    if (registered_signals.contains(fullname)) {
        heap.general_allocator.free(fullname);
        return;
    }
    registered_signals.put(fullname, {}) catch unreachable;

    var propertyies: [32]c.GDExtensionPropertyInfo = undefined;
    if (arguments.len > 32) {
        std.log.err("why you need so many arguments for a single signal? whatever, you can increase the upper limit as you want", .{});
    }

    for (arguments, 0..) |*a, i| {
        propertyies[i].type = @intFromEnum(a.type);
        propertyies[i].hint = @intCast(@intFromEnum(a.hint));
        propertyies[i].usage = @bitCast(a.usage);
        propertyies[i].name = @ptrCast(@constCast(&a.name));
        propertyies[i].class_name = @ptrCast(@constCast(&a.class_name));
        propertyies[i].hint_string = @ptrCast(@constCast(&a.hint_string));
    }

    if (arguments.len > 0) {
        godot.interface.classdbRegisterExtensionClassSignal(godot.interface.library, meta.getNamePtr(T), &StringName.fromLatin1(signal_name), &propertyies[0], @intCast(arguments.len));
    } else {
        godot.interface.classdbRegisterExtensionClassSignal(godot.interface.library, meta.getNamePtr(T), &StringName.fromLatin1(signal_name), null, 0);
    }
}

fn init() void {
    registered_classes = std.StringHashMap(void).init(heap.general_allocator);
    registered_methods = std.StringHashMap(void).init(heap.general_allocator);
    registered_signals = std.StringHashMap(void).init(heap.general_allocator);
}

fn deinit() void {
    {
        var keys = registered_classes.keyIterator();
        while (keys.next()) |it| {
            var class_name = StringName.fromUtf8(it.*);
            defer class_name.deinit();
            godot.interface.classdbUnregisterExtensionClass(godot.interface.library, @ptrCast(&class_name));
        }
    }

    {
        var keys = registered_methods.keyIterator();
        while (keys.next()) |it| {
            heap.general_allocator.free(it.*);
        }
    }

    {
        var keys = registered_signals.keyIterator();
        while (keys.next()) |it| {
            heap.general_allocator.free(it.*);
        }
    }

    registered_signals.deinit();
    registered_methods.deinit();
    registered_classes.deinit();
}

const std = @import("std");

const godot = @import("gdzig.zig");
const c = godot.c;
const PropertyUsageFlags = godot.global.PropertyUsageFlags;
const PropertyHint = godot.global.PropertyHint;
const heap = godot.heap;
const Interface = godot.Interface;
const meta = godot.meta;
const object = godot.object;
const String = godot.builtin.String;
const StringName = godot.builtin.StringName;
const support = godot.support;
const Variant = godot.builtin.Variant;
