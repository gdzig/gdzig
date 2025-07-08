const PluginCallback = ?*const fn (userdata: ?*anyopaque, p_level: c.GDExtensionInitializationLevel) void;

pub fn registerClass(
    comptime T: type,
    userdata: anytype,
    opt: godot.api.classdb.ClassCreationInfo(T, @TypeOf(userdata)),
) void {
    const base_name = meta.getNamePtr(meta.BaseOf(T));
    const class_name = meta.getNamePtr(T);
    class_name.* = StringName.fromComptimeLatin1(comptime meta.getTypeShortName(T));

    const CustomClassUserdata = @TypeOf(userdata);
    const GdzigClassUserdata = struct {
        class_name: StringName,
        userdata: CustomClassUserdata,
    };

    var info = opt;

    info.set = opt.set orelse if (@hasDecl(T, "_set")) &T._set else null;
    info.get = opt.get orelse if (@hasDecl(T, "_get")) &T._get else null;
    info.get_property_list = opt.get_property_list orelse if (@hasDecl(T, "_getPropertyList")) &T._getPropertyList else null;
    info.free_property_list = opt.free_property_list orelse if (@hasDecl(T, "_freePropertyList")) &T._freePropertyList else null;
    info.property_can_revert = opt.property_can_revert orelse if (@hasDecl(T, "_propertyCanRevert")) &T._propertyCanRevert else null;
    info.property_get_revert = opt.property_get_revert orelse if (@hasDecl(T, "_propertyGetRevert")) &T._propertyGetRevert else null;
    info.validate_property = opt.validate_property orelse if (@hasDecl(T, "_validateProperty")) &T._validateProperty else null;
    info.notification = opt.notification orelse if (@hasDecl(T, "_notification")) &T._notification else null;
    info.to_string = opt.to_string orelse if (@hasDecl(T, "_toString")) &T._toString else null;
    info.reference = opt.reference orelse if (@hasDecl(T, "_reference")) &T._reference else null;
    info.unreference = opt.unreference orelse if (@hasDecl(T, "_unreference")) &T._unreference else null;
    info.create_instance = opt.create_instance orelse struct {
        fn create() void {
            // ..
        }
    }.create;
    info.recreate_instance = opt.recreate_instance orelse struct {
        fn create() void {
            // ..
        }
    }.create;
    info.free_instance = opt.free_instance orelse struct {
        fn create() void {
            // ..
        }
    }.create;
    info.get_rid = opt.get_rid orelse if (@hasDecl(T, "_getRid")) &T._getRid else null;

    godot.api.classdb.registerClass(
        T,
        void,
        class_name,
        base_name,
        .{
            .is_virtual = opt.is_virtual,
            .is_abstract = opt.is_abstract,
            .is_exposed = opt.is_exposed,
            .is_runtime = opt.is_runtime,
            .set_func = opt.set_func,
            .get_func = opt.get_func,
            .get_property_list_func = opt.get_property_list_func,
            .free_property_list_func = opt.free_property_list_func,
            .property_can_revert_func = opt.property_can_revert_func,
            .property_get_revert_func = opt.property_get_revert_func,
            .validate_property_func = opt.validate_property_func,
            .notification_func = opt.notification_func,
            .to_string_func = opt.to_string_func,
            .reference_func = opt.reference_func,
            .unreference_func = opt.unreference_func,
            .create_instance_func = opt.create_instance_func,
            .free_instance_func = opt.free_instance_func,
            .recreate_instance_func = opt.recreate_instance_func,
            .get_virtual_func = opt.get_virtual_func,
            .get_virtual_call_data_func = opt.get_virtual_call_data_func,
            .call_virtual_with_data_func = opt.call_virtual_with_data_func,
            .get_rid_func = opt.get_rid_func,
            .class_userdata = @constCast(@ptrCast(&GdzigClassUserdata{
                .class_name = class_name.*,
                .userdata = userdata,
            })),
        },
    );

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

    var properties: [32]c.GDExtensionPropertyInfo = undefined;
    if (arguments.len > 32) {
        std.log.err("why you need so many arguments for a single signal? whatever, you can increase the upper limit as you want", .{});
    }

    for (arguments, 0..) |*a, i| {
        properties[i].type = @intFromEnum(a.type);
        properties[i].hint = @intCast(@intFromEnum(a.hint));
        properties[i].usage = @bitCast(a.usage);
        properties[i].name = @ptrCast(@constCast(&a.name));
        properties[i].class_name = @ptrCast(@constCast(&a.class_name));
        properties[i].hint_string = @ptrCast(@constCast(&a.hint_string));
    }

    if (arguments.len > 0) {
        godot.interface.classdbRegisterExtensionClassSignal(godot.interface.library, meta.getNamePtr(T), &StringName.fromLatin1(signal_name), &properties[0], @intCast(arguments.len));
    } else {
        godot.interface.classdbRegisterExtensionClassSignal(godot.interface.library, meta.getNamePtr(T), &StringName.fromLatin1(signal_name), null, 0);
    }
}

fn init() void {
    registered_methods = std.StringHashMap(void).init(heap.general_allocator);
    registered_signals = std.StringHashMap(void).init(heap.general_allocator);
}

fn deinit() void {
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
}

const std = @import("std");
const DebugAllocator = std.heap.DebugAllocator;

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
