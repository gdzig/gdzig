const ClassUserData = struct {
    class_name: []const u8,
};

var registered_classes: StringHashMap(void) = .empty;
pub fn registerClass(comptime T: type) void {
    const class_name = comptime meta.typeShortName(T);

    if (registered_classes.contains(class_name)) return;
    registered_classes.putNoClobber(godot.heap.general_allocator, class_name, {}) catch unreachable;

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
                heap.general_allocator.free(list[0..p_count]);
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
            return @ptrCast(object.asObject(ret));
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
            const virtual_bind = @field(object.BaseOf(T), "getVirtualDispatch");
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

    classdbRegisterExtensionClass(
        @ptrCast(godot.interface.library),
        @ptrCast(godot.typeName(T)),
        @ptrCast(godot.typeName(object.BaseOf(T))),
        @ptrCast(&PerClassData.class_info),
    );

    if (@hasDecl(T, "_bindMethods")) {
        T._bindMethods();
    }
}

var registered_methods: StringHashMap(void) = .empty;
pub fn registerMethod(comptime T: type, comptime name: [:0]const u8) void {
    //prevent duplicate registration
    const fullname = comptime meta.typeShortName(T) ++ "::" ++ name;
    if (registered_methods.contains(fullname)) return;
    registered_methods.putNoClobber(godot.heap.general_allocator, fullname, {}) catch unreachable;

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
            .class_name = meta.typeName(MethodBinder.ArgsTuple[i].type),
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

    godot.interface.classdbRegisterExtensionClassMethod(godot.interface.library, meta.typeName(T), &MethodBinder.method_info);
}

var registered_signals: StringHashMap(void) = .empty;
pub fn registerSignal(comptime T: type, comptime S: type) void {
    //prevent duplicate registration
    const fullname = comptime meta.typeShortName(T) ++ "::" ++ meta.typeShortName(S);
    if (registered_signals.contains(fullname)) return;
    registered_signals.putNoClobber(godot.heap.general_allocator, fullname, {}) catch unreachable;

    if (@typeInfo(S) != .@"struct") {
        @compileError("Signal '" ++ meta.typeShortName(S) ++ "' for '" ++ meta.typeShortName(T) ++ "' must be a struct");
    }

    const signal_name = meta.signalName(S);

    var arguments: [std.meta.fields(S).len]object.PropertyInfo = undefined;
    inline for (std.meta.fields(S), 0..) |field, i| {
        arguments[i] = object.PropertyInfo.init(godot.heap.general_allocator, .string, field.name) catch unreachable;
    }

    var properties: [32]c.GDExtensionPropertyInfo = undefined;
    if (comptime arguments.len > 32) {
        @compileError("why you need so many arguments for a single signal? whatever, you can increase the upper limit as you want");
    }

    inline for (arguments, 0..) |a, i| {
        properties[i].type = @intFromEnum(a.type);
        properties[i].hint = @intCast(@intFromEnum(a.hint));
        properties[i].usage = @bitCast(a.usage);
        properties[i].name = @ptrCast(@constCast(&a.name));
        properties[i].class_name = @ptrCast(@constCast(&a.class_name));
        properties[i].hint_string = @ptrCast(@constCast(&a.hint_string));
    }

    if (comptime arguments.len > 0) {
        godot.interface.classdbRegisterExtensionClassSignal(godot.interface.library, meta.typeName(T), &StringName.fromComptimeLatin1(signal_name), &properties[0], @intCast(arguments.len));
    } else {
        godot.interface.classdbRegisterExtensionClassSignal(godot.interface.library, meta.typeName(T), &StringName.fromComptimeLatin1(signal_name, false), null, 0);
    }

    std.debug.print("Signal registered: {s}\n", .{signal_name});
}

pub fn init() void {}

pub fn deinit() void {
    registered_signals.deinit(godot.heap.general_allocator);
    registered_methods.deinit(godot.heap.general_allocator);
    registered_classes.deinit(godot.heap.general_allocator);
}

const std = @import("std");
const StringHashMap = std.StringHashMapUnmanaged;

const godot = @import("gdzig.zig");
const c = godot.c;
const heap = godot.heap;
const meta = godot.meta;
const object = godot.object;
const support = godot.support;
const String = godot.builtin.String;
const StringName = godot.builtin.StringName;
const Variant = godot.builtin.Variant;
const PropertyUsageFlags = godot.global.PropertyUsageFlags;
const PropertyHint = godot.global.PropertyHint;
const Interface = godot.Interface;
