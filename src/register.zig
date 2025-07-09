const PluginCallback = ?*const fn (userdata: ?*anyopaque, p_level: c.GDExtensionInitializationLevel) void;

pub fn registerClass(
    comptime T: type,
    opt: RegisterClassOpts(T, void),
) void {
    return registerClassWithUserdata(T, {}, opt);
}

pub fn registerClassWithUserdata(
    comptime T: type,
    userdata: anytype,
    opt: RegisterClassOpts(T, @TypeOf(userdata)),
) void {
    const base_name = meta.getNamePtr(meta.BaseOf(T));
    const class_name = meta.getNamePtr(T);
    class_name.* = StringName.fromComptimeLatin1(comptime meta.getTypeShortName(T));

    // Create a new ClassCreationInfo object with extended userdata
    const Userdata = struct {
        class_name: StringName,
        userdata: @TypeOf(userdata),
    };
    const Info = comptime godot.api.classdb.ClassCreationInfo(T, Userdata);
    var info: Info = undefined;

    // Copy the fields from opt into info
    inline for (@typeInfo(Info).@"struct".fields) |field| {
        if (comptime std.mem.eql(u8, "class_userdata", field.name)) continue;
        if (@FieldType(@TypeOf(info), field.name) == @FieldType(@TypeOf(opt), field.name)) {
            @field(info, field.name) = @field(opt, field.name);
        }
    }

    // Virtual function defaults
    info.set = info.set orelse if (@hasDecl(T, "_set")) &T._set else null;
    info.get = info.get orelse if (@hasDecl(T, "_get")) &T._get else null;
    info.get_property_list = info.get_property_list orelse if (@hasDecl(T, "_getPropertyList")) &T._getPropertyList else null;
    info.free_property_list = info.free_property_list orelse if (@hasDecl(T, "_freePropertyList")) &T._freePropertyList else null;
    info.property_can_revert = info.property_can_revert orelse if (@hasDecl(T, "_propertyCanRevert")) &T._propertyCanRevert else null;
    info.property_get_revert = info.property_get_revert orelse if (@hasDecl(T, "_propertyGetRevert")) &T._propertyGetRevert else null;
    if (@hasDecl(godot.c, "GDExtensionClassValidateProperty")) { // added in Godot 4.2
        info.validate_property = info.validate_property orelse if (@hasDecl(T, "_validateProperty")) &T._validateProperty else null;
    }
    info.notification = info.notification orelse if (@hasDecl(T, "_notification")) &T._notification else null;
    info.to_string = info.to_string orelse if (@hasDecl(T, "_toString")) &T._toString else null;
    info.reference = info.reference orelse if (@hasDecl(T, "_reference")) &T._reference else null;
    info.unreference = info.unreference orelse if (@hasDecl(T, "_unreference")) &T._unreference else null;
    if (@hasField(Info, "get_rid")) { // removed in Godot 4.4
        info.get_rid = info.get_rid orelse if (@hasDecl(T, "_getRid")) &T._getRid else null;
    }

    @compileLog(@FieldType(Info, "create_instance"), @FieldType(@TypeOf(opt), "create_instance"));
    @compileLog(@FieldType(Info, "create_instance"), @FieldType(@TypeOf(opt), "create_instance"));

    // Object lifecycle defaults
    // TODO: allow overrides for these methods
    if (comptime @hasDecl(godot.c, "GDExtensionClassCreateInstance2")) { // added in Godot 4.4
        info.create_instance = struct {
            fn create(_: *Userdata, _: bool) *Object {
                const ret = object.create(T) catch unreachable;
                return @ptrCast(meta.asObject(ret));
            }
        }.create;
    } else {
        info.create_instance = struct {
            fn create(_: *Userdata) *Object {
                const ret = object.create(T) catch unreachable;
                return @ptrCast(@alignCast(meta.asObject(ret)));
            }
        }.create;
    }
    info.recreate_instance = struct {
        fn recreate(_: *Userdata, _: *Object) *T {
            @panic("Extension reloading is not currently supported");
        }
    }.recreate;
    info.free_instance = struct {
        fn free(_: *Userdata, instance: *T) void {
            if (@hasDecl(T, "deinit")) {
                instance.deinit();
            }
            // TODO: should this be left to the deinit function?
            heap.general_allocator.destroy(instance);
        }
    }.free;

    // Setup class userdata
    info.class_userdata = @constCast(&Userdata{
        .class_name = class_name.*,
        .userdata = userdata,
    });

    // Register the type in the ClassDB
    godot.api.classdb.registerClass(T, Userdata, class_name, base_name, info);

    // This hook allows the user to register additional methods or properties
    if (@hasDecl(T, "_bindMethods")) {
        T._bindMethods();
    }
}

/// Extends and modifies ClassCreationInfo(T, Userdata) by:
///
/// - making create_instance nullable, with default null value
/// - making recreate_instance nullable, with default null value
/// - making free_instance nullable, with default null value
///
pub fn RegisterClassOpts(comptime T: type, comptime Userdata: type) type {
    const Original = godot.api.classdb.ClassCreationInfo(T, Userdata);
    const original_info = @typeInfo(Original);
    const original_fields = original_info.@"struct".fields;

    comptime var new_fields: [original_fields.len]std.builtin.Type.StructField = undefined;

    inline for (original_fields, 0..) |field, i| {
        if (comptime std.mem.eql(u8, field.name, "create_instance") or
            std.mem.eql(u8, field.name, "recreate_instance") or
            std.mem.eql(u8, field.name, "free_instance"))
        {
            new_fields[i] = std.builtin.Type.StructField{
                .name = field.name,
                .type = ?field.type,
                .default_value_ptr = @ptrCast(&@as(?field.type, null)),
                .is_comptime = field.is_comptime,
                .alignment = field.alignment,
            };
        } else {
            new_fields[i] = field;
        }
    }

    return @Type(std.builtin.Type{
        .@"struct" = .{
            .layout = original_info.@"struct".layout,
            .fields = &new_fields,
            .decls = &.{},
            .is_tuple = original_info.@"struct".is_tuple,
        },
    });
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

pub fn init() void {
    registered_methods = std.StringHashMap(void).init(heap.general_allocator);
    registered_signals = std.StringHashMap(void).init(heap.general_allocator);
}

pub fn deinit() void {
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
const heap = godot.heap;
const Interface = godot.Interface;
const meta = godot.meta;
const Object = godot.class.Object;
const object = godot.object;
const PropertyHint = godot.global.PropertyHint;
const PropertyUsageFlags = godot.global.PropertyUsageFlags;
const String = godot.builtin.String;
const StringName = godot.builtin.StringName;
const support = godot.support;
const Variant = godot.builtin.Variant;
