pub fn registerClass(
    allocator: Allocator,
    comptime T: type,
    comptime opt: struct {
        virtual: bool = false,
        abstract: bool = false,
        exposed: bool = true,
        runtime: bool = false,
    },
) void {
    const Static = struct {
        comptime {
            _ = .{T};
        }
        var class_allocator: Allocator = undefined;
    };
    Static.class_allocator = allocator;

    const class_name = StringName.fromComptimeLatin1(meta.typeShortName(T));
    const base_name = StringName.fromComptimeLatin1(meta.typeShortName(object.BaseOf(T)));
    const callbacks = comptime makeClassCallbacks(T);
    const version = GodotVersion.current();

    if (version.gte(.@"4.4")) {
        classdb.registerClass4(T, *Allocator, void, &class_name, &base_name, .{
            .userdata = &Static.class_allocator,
            .is_virtual = opt.virtual,
            .is_abstract = opt.abstract,
            .is_exposed = opt.exposed,
            .is_runtime = opt.runtime,
        }, callbacks.v4);
    } else if (version.gte(.@"4.3")) {
        classdb.registerClass3(T, *Allocator, void, &class_name, &base_name, .{
            .userdata = &Static.class_allocator,
            .is_virtual = opt.virtual,
            .is_abstract = opt.abstract,
            .is_exposed = opt.exposed,
            .is_runtime = opt.runtime,
        }, callbacks.v3);
    } else if (version.gte(.@"4.2")) {
        classdb.registerClass2(T, *Allocator, void, &class_name, &base_name, .{
            .userdata = &Static.class_allocator,
            .is_virtual = opt.virtual,
            .is_abstract = opt.abstract,
            .is_exposed = opt.exposed,
        }, callbacks.v2);
    } else if (version.gte(.@"4.1")) {
        classdb.registerClass1(T, *Allocator, &class_name, &base_name, .{
            .userdata = &Static.class_allocator,
            .is_virtual = opt.virtual,
            .is_abstract = opt.abstract,
        }, callbacks.v1);
    } else {
        @panic("Unsupported Godot version");
    }

    if (@hasDecl(T, "_bindMethods")) {
        T._bindMethods();
    }
}

fn makeClassCallbacks(comptime T: type) struct {
    v1: classdb.ClassCallbacks1(T, *Allocator),
    v2: classdb.ClassCallbacks2(T, *Allocator, void),
    v3: classdb.ClassCallbacks3(T, *Allocator, void),
    v4: classdb.ClassCallbacks4(T, *Allocator, void),
} {
    // Assert that we can initialize the user type
    comptime {
        if (!@hasDecl(T, "init")) {
            for (@typeInfo(T).@"struct".fields) |field| {
                if (std.mem.eql(u8, "base", field.name)) continue;
                if (field.default_value_ptr == null) {
                    @compileError("The type '" ++ meta.typeShortName(T) ++ "' should either have an 'fn init(base: *" ++ meta.typeShortName(object.BaseOf(T)) ++ ") " ++ meta.typeShortName(T) ++ "' function, or a default value for the field '" ++ field.name ++ "', but it has neither.");
                }
            }
        }
    }

    const Callbacks = struct {
        fn create(allocator: *Allocator) *T {
            const base: *godot.class.Object = @ptrCast(godot.interface.classdbConstructObject2(@ptrCast(meta.typeName(object.BaseOf(T)))).?);
            return recreate(allocator, base);
        }

        fn create2(allocator: *Allocator, notify: bool) *T {
            const self = create(allocator);
            if (notify) {
                self.base.notification(godot.class.Object.NOTIFICATION_POSTINITIALIZE, .{});
            }
            return self;
        }

        fn destroy(allocator: *Allocator, instance: *T) void {
            if (@hasDecl(T, "deinit")) {
                const fn_info = @typeInfo(@TypeOf(T.deinit)).@"fn";
                if (fn_info.params.len == 2 and fn_info.params[1].type == Allocator) {
                    instance.deinit(allocator.*);
                } else {
                    instance.deinit();
                }
            }
            allocator.destroy(instance);
        }

        fn recreate(allocator: *Allocator, obj: *godot.class.Object) *T {
            const base: *object.BaseOf(T) = @ptrCast(obj);

            const self: *T = allocator.create(T) catch @panic("out of memory");
            godot.interface.objectSetInstance(@ptrCast(base), @ptrCast(meta.typeName(T)), @ptrCast(self));
            godot.interface.objectSetInstanceBinding(@ptrCast(base), godot.interface.library, @ptrCast(self), &object.dummy_callbacks);

            if (@hasDecl(T, "init")) {
                const init_info = @typeInfo(@TypeOf(T.init)).@"fn";
                const takes_allocator = init_info.params.len == 2 and init_info.params[1].type == Allocator;
                const returns_error = init_info.return_type != null and @typeInfo(init_info.return_type.?) == .error_union;

                if (takes_allocator and returns_error) {
                    self.* = T.init(base, allocator.*) catch @panic("out of memory");
                } else if (takes_allocator) {
                    self.* = T.init(base, allocator.*);
                } else {
                    self.* = T.init(base);
                }
            } else {
                self.* = .{ .base = base };
            }

            return self;
        }

        fn notification1(instance: *T, what: i32) void {
            T._notification(instance, what, false);
        }

        fn getVirtual(name: *const StringName) ?classdb.CallVirtual(T) {
            const Base = object.BaseOf(T);
            const raw_ptr = Base.getVirtualDispatch(T, null, @ptrCast(name));
            return @ptrCast(raw_ptr);
        }

        fn getVirtual2(name: *const StringName, hash: u32) ?classdb.CallVirtual(T) {
            _ = hash;
            return getVirtual(name);
        }
    };

    return .{
        .v1 = .{
            .create = Callbacks.create,
            .destroy = Callbacks.destroy,

            .get_virtual = Callbacks.getVirtual,

            .set = if (@hasDecl(T, "_set")) T._set else null,
            .get = if (@hasDecl(T, "_get")) T._get else null,
            .get_property_list = if (@hasDecl(T, "_getPropertyList")) T._getPropertyList else null,
            .destroy_property_list = if (@hasDecl(T, "_destroyPropertyList")) T._destroyPropertyList else null,
            .property_can_revert = if (@hasDecl(T, "_propertyCanRevert")) T._propertyCanRevert else null,
            .property_get_revert = if (@hasDecl(T, "_propertyGetRevert")) T._propertyGetRevert else null,
            .notification = if (@hasDecl(T, "_notification")) Callbacks.notification1 else null,
            .to_string = if (@hasDecl(T, "_toString")) T._toString else null,
            .reference = if (@hasDecl(T, "_reference")) T._reference else null,
            .unreference = if (@hasDecl(T, "_unreference")) T._unreference else null,
            .get_rid = if (@hasDecl(T, "_getRid")) T._getRid else null,
        },
        .v2 = .{
            .create = Callbacks.create,
            .destroy = Callbacks.destroy,
            .recreate = Callbacks.recreate,

            .get_virtual = Callbacks.getVirtual,
            // .get_virtual_call_data - not yet supported
            // .call_virtual_with_data - not yet supported

            .set = if (@hasDecl(T, "_set")) T._set else null,
            .get = if (@hasDecl(T, "_get")) T._get else null,
            .get_property_list = if (@hasDecl(T, "_getPropertyList")) T._getPropertyList else null,
            .destroy_property_list = if (@hasDecl(T, "_destroyPropertyList")) T._destroyPropertyList else null,
            .property_can_revert = if (@hasDecl(T, "_propertyCanRevert")) T._propertyCanRevert else null,
            .property_get_revert = if (@hasDecl(T, "_propertyGetRevert")) T._propertyGetRevert else null,
            .validate_property = if (@hasDecl(T, "_validateProperty")) T._validateProperty else null,
            .notification = if (@hasDecl(T, "_notification")) T._notification else null,
            .to_string = if (@hasDecl(T, "_toString")) T._toString else null,
            .reference = if (@hasDecl(T, "_reference")) T._reference else null,
            .unreference = if (@hasDecl(T, "_unreference")) T._unreference else null,
            .get_rid = if (@hasDecl(T, "_getRid")) T._getRid else null,
        },
        .v3 = .{
            .create = Callbacks.create,
            .destroy = Callbacks.destroy,
            .recreate = Callbacks.recreate,

            .get_virtual = Callbacks.getVirtual,
            // .get_virtual_call_data - not yet supported
            // .call_virtual_with_data - not yet supported

            .set = if (@hasDecl(T, "_set")) T._set else null,
            .get = if (@hasDecl(T, "_get")) T._get else null,
            .get_property_list = if (@hasDecl(T, "_getPropertyList")) T._getPropertyList else null,
            .destroy_property_list = if (@hasDecl(T, "_destroyPropertyList")) T._destroyPropertyList else null,
            .property_can_revert = if (@hasDecl(T, "_propertyCanRevert")) T._propertyCanRevert else null,
            .property_get_revert = if (@hasDecl(T, "_propertyGetRevert")) T._propertyGetRevert else null,
            .validate_property = if (@hasDecl(T, "_validateProperty")) T._validateProperty else null,
            .notification = if (@hasDecl(T, "_notification")) T._notification else null,
            .to_string = if (@hasDecl(T, "_toString")) T._toString else null,
            .reference = if (@hasDecl(T, "_reference")) T._reference else null,
            .unreference = if (@hasDecl(T, "_unreference")) T._unreference else null,
            .get_rid = if (@hasDecl(T, "_getRid")) T._getRid else null,
        },
        .v4 = .{
            .create = Callbacks.create2,
            .destroy = Callbacks.destroy,
            .recreate = Callbacks.recreate,

            .get_virtual = Callbacks.getVirtual2,
            // .get_virtual_call_data - not yet supported
            // .call_virtual_with_data - not yet supported

            .set = if (@hasDecl(T, "_set")) T._set else null,
            .get = if (@hasDecl(T, "_get")) T._get else null,
            .get_property_list = if (@hasDecl(T, "_getPropertyList")) T._getPropertyList else null,
            .destroy_property_list = if (@hasDecl(T, "_destroyPropertyList")) T._destroyPropertyList else null,
            .property_can_revert = if (@hasDecl(T, "_propertyCanRevert")) T._propertyCanRevert else null,
            .property_get_revert = if (@hasDecl(T, "_propertyGetRevert")) T._propertyGetRevert else null,
            .validate_property = if (@hasDecl(T, "_validateProperty")) T._validateProperty else null,
            .notification = if (@hasDecl(T, "_notification")) T._notification else null,
            .to_string = if (@hasDecl(T, "_toString")) T._toString else null,
            .reference = if (@hasDecl(T, "_reference")) T._reference else null,
            .unreference = if (@hasDecl(T, "_unreference")) T._unreference else null,
        },
    };
}

pub fn registerMethod(comptime T: type, comptime name: DeclEnum(T)) void {
    const class_name = StringName.fromComptimeLatin1(meta.typeShortName(T));
    const method_name = StringName.fromComptimeLatin1(@tagName(name));

    const MethodType = @TypeOf(@field(T, @tagName(name)));
    const fn_info = @typeInfo(MethodType).@"fn";
    const Args = fn_info.params;
    const ReturnType = fn_info.return_type orelse void;
    const arg_count = Args.len - 1;

    const return_value: classdb.PropertyInfo = .{
        .type = .forType(ReturnType),
        .name = &StringName.empty,
        .class_name = &StringName.empty,
        .hint = .property_hint_none,
        .hint_string = &String.empty,
        .usage = .property_usage_none,
    };

    const arg_infos: [arg_count]classdb.PropertyInfo = comptime blk: {
        var infos: [arg_count]classdb.PropertyInfo = undefined;
        for (0..arg_count) |i| {
            const ArgType = Args[i + 1].type.?;
            infos[i] = .{
                .type = Variant.Tag.forType(ArgType),
                .name = &StringName.empty,
                .class_name = &StringName.empty,
                .hint = .property_hint_none,
                .hint_string = &String.empty,
                .usage = .property_usage_none,
            };
        }
        break :blk infos;
    };

    const arg_metas: [arg_count]classdb.MethodArgumentMetadata = comptime blk: {
        var metas: [arg_count]classdb.MethodArgumentMetadata = undefined;
        for (0..arg_count) |i| {
            metas[i] = .none;
        }
        break :blk metas;
    };

    const Callbacks = struct {
        fn call(instance: *T, args: []const *const Variant) godot.CallError!Variant {
            _ = instance;
            _ = args;
            // TODO: implement variant call
            return Variant.nil;
        }

        fn ptrCall(instance: *T, args: [*]const *const anyopaque, ret: *anyopaque) void {
            _ = instance;
            _ = args;
            _ = ret;
            // TODO: implement ptr call
        }
    };

    classdb.registerMethod(T, void, &class_name, .{
        .name = &method_name,
        .return_value_info = if (ReturnType != void) &return_value else null,
        .argument_info = &arg_infos,
        .argument_metadata = &arg_metas,
    }, .{
        .call = Callbacks.call,
        .ptr_call = Callbacks.ptrCall,
    });
}

pub fn registerSignal(comptime T: type, comptime S: type) void {
    const class_name = StringName.fromComptimeLatin1(meta.typeShortName(T));
    const signal_name = StringName.fromComptimeLatin1(meta.signalName(S));

    const fields = @typeInfo(S).@"struct".fields;
    const arg_info = comptime blk: {
        var infos: [fields.len]classdb.PropertyInfo = undefined;
        for (fields, 0..) |field, i| {
            const name = StringName.fromComptimeLatin1(field.name);
            infos[i] = .{
                .type = .forType(field.type),
                .name = &name,
                .class_name = &StringName.empty,
                .hint = .property_hint_none,
                .hint_string = &String.empty,
                .usage = .property_usage_none,
            };
        }
        break :blk infos;
    };

    classdb.registerSignal(&class_name, &signal_name, &arg_info);
}

const std = @import("std");
const Allocator = std.mem.Allocator;
const DeclEnum = std.meta.DeclEnum;

const godot = @import("gdzig.zig");
const classdb = godot.classdb;
const meta = godot.meta;
const object = godot.object;
const GodotVersion = godot.GodotVersion;
const StringName = godot.builtin.StringName;
const String = godot.builtin.String;
const Variant = godot.builtin.Variant;
