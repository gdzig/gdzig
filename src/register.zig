const PluginCallback = ?*const fn (userdata: ?*anyopaque, p_level: c.GDExtensionInitializationLevel) void;

pub fn registerClass(
    comptime T: type,
    opt: ClassCreationInfo,
) void {
    const base_name = meta.getNamePtr(meta.BaseOf(T));
    const class_name = meta.getNamePtr(T);
    class_name.* = StringName.fromComptimeLatin1(comptime meta.getTypeShortName(T));

    var vtable = &struct {
        pub const Class = T;
        var vtable: ClassUserdata.VTable = undefined;
    }.vtable;

    // Virtual function defaults
    vtable.set = opt.vtable.set orelse if (@hasDecl(T, "_set")) @ptrCast(&T._set) else null;
    vtable.get = opt.vtable.get orelse if (@hasDecl(T, "_get")) @ptrCast(&T._get) else null;
    vtable.getPropertyList = opt.vtable.getPropertyList orelse if (@hasDecl(T, "_getPropertyList")) @ptrCast(&T._getPropertyList) else null;
    vtable.freePropertyList = opt.vtable.freePropertyList orelse if (@hasDecl(T, "_freePropertyList")) @ptrCast(&T._freePropertyList) else null;
    vtable.propertyCanRevert = opt.vtable.propertyCanRevert orelse if (@hasDecl(T, "_propertyCanRevert")) @ptrCast(&T._propertyCanRevert) else null;
    vtable.propertyGetRevert = opt.vtable.propertyGetRevert orelse if (@hasDecl(T, "_propertyGetRevert")) @ptrCast(&T._propertyGetRevert) else null;
    vtable.notification = opt.vtable.notification orelse if (@hasDecl(T, "_notification")) @ptrCast(&T._notification) else null;
    vtable.toString = opt.vtable.toString orelse if (@hasDecl(T, "_toString")) @ptrCast(&T._toString) else null;
    vtable.reference = opt.vtable.reference orelse if (@hasDecl(T, "_reference")) @ptrCast(&T._reference) else null;
    vtable.unreference = opt.vtable.unreference orelse if (@hasDecl(T, "_unreference")) @ptrCast(&T._unreference) else null;

    if (@hasField(ClassUserdata.VTable, "validateProperty")) { // added in Godot 4.2
        vtable.validateProperty = opt.vtable.validateProperty orelse if (@hasDecl(T, "_validateProperty")) &T._validateProperty else null;
    }

    if (@hasField(ClassUserdata.VTable, "getRid")) { // removed in Godot 4.4
        vtable.getRid = opt.vtable.getRid orelse if (@hasDecl(T, "_getRid")) &T._getRid else null;
    }

    // TODO: allow overrides for these methods
    if (comptime @hasDecl(godot.c, "GDExtensionClassCreateInstance2")) { // added in Godot 4.4
        vtable.createInstance = @ptrCast(&struct {
            fn create(_: *ClassUserdata, _: bool) *Object {
                const ret = object.create(T) catch unreachable;
                return @ptrCast(meta.asObject(ret));
            }
        }.create);
    } else {
        vtable.createInstance = @ptrCast(&struct {
            fn create(_: *ClassUserdata) *Object {
                const ret = object.create(T) catch unreachable;
                return @ptrCast(@alignCast(meta.asObject(ret)));
            }
        }.create);
    }

    if (comptime @hasDecl(godot.c, "GDExtensionClassRecreateInstance")) { // added in Godot 4.2
        vtable.recreateInstance = @ptrCast(&struct {
            fn recreate(_: *ClassUserdata, _: *Object) *T {
                @panic("Extension reloading is not currently supported");
            }
        }.recreate);
    }

    vtable.freeInstance = @ptrCast(&struct {
        fn free(_: *ClassUserdata, instance: *T) void {
            if (@hasDecl(T, "deinit")) {
                instance.deinit();
            }
            // TODO: should this be left to the deinit function?
            heap.general_allocator.destroy(instance);
        }
    }.free);

    // Store class userdata statically
    var info: ClassCreationInfo = opt;
    info.vtable = vtable;

    std.debug.print("{}\n", .{info.vtable.*});

    // Register the type in the ClassDB
    godot.api.classdb.registerClass(class_name, base_name, info);

    // This hook allows the user to register additional methods or properties
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
const ClassCreationInfo = godot.api.classdb.ClassCreationInfo;
const ClassUserdata = godot.api.classdb.ClassUserdata;
