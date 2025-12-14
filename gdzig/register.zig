pub const ExtensionOptions = struct {
    entry_symbol: []const u8,
    minimum_initialization_level: InitializationLevel = .core,
};

pub fn registerExtension(comptime T: type, comptime opt: ExtensionOptions) void {
    const return_type = @typeInfo(@TypeOf(T.create)).@"fn".return_type.?;
    const actual_type = switch (@typeInfo(return_type)) {
        .error_union => |eu| eu.payload,
        else => return_type,
    };

    assert(@typeInfo(actual_type) == .pointer);
    assert(@typeInfo(actual_type).pointer.child == T);

    @export(&struct {
        fn entrypoint(
            p_get_proc_address: c.GDExtensionInterfaceGetProcAddress,
            p_library: c.GDExtensionClassLibraryPtr,
            r_initialization: [*c]c.GDExtensionInitialization,
        ) callconv(.c) c.GDExtensionBool {
            raw.* = .init(p_get_proc_address.?, p_library.?);
            raw.getGodotVersion(@ptrCast(&gdzig.version));

            const self = if (@typeInfo(return_type) == .error_union)
                T.create() catch return @intFromBool(false)
            else
                T.create();

            r_initialization.*.userdata = @ptrCast(@constCast(self));
            r_initialization.*.initialize = @ptrCast(&init);
            r_initialization.*.deinitialize = @ptrCast(&deinit);
            r_initialization.*.minimum_initialization_level = @intFromEnum(opt.minimum_initialization_level);

            return @intFromBool(true);
        }

        fn init(userdata: ?*anyopaque, p_level: c.GDExtensionInitializationLevel) callconv(.c) void {
            const self: *T = @ptrCast(@alignCast(userdata.?));
            const level: InitializationLevel = @enumFromInt(p_level);

            if (@hasDecl(T, "init")) {
                self.init(level);
            }
        }

        fn deinit(userdata: ?*anyopaque, p_level: c.GDExtensionInitializationLevel) callconv(.c) void {
            const self: *T = @ptrCast(@alignCast(userdata.?));
            const level: InitializationLevel = @enumFromInt(p_level);

            if (@hasDecl(T, "deinit")) {
                self.deinit(level);
            }

            if (level == opt.minimum_initialization_level) {
                PropertyListMeta.cleanup();
                DestroyMeta.cleanup();
                if (@hasDecl(T, "destroy")) self.destroy();
            }
        }
    }.entrypoint, .{
        .name = opt.entry_symbol,
        .linkage = .strong,
    });
}

pub const InitializationLevel = enum(c_int) {
    core = 0,
    servers = 1,
    scene = 2,
    editor = 3,
};

pub fn registerClass(comptime T: type, info: ClassInfo4(ClassUserdataOf(T))) void {
    const class_name = StringName.fromComptimeLatin1(meta.typeShortName(T));
    const base_name = StringName.fromComptimeLatin1(meta.typeShortName(object.BaseOf(T)));
    const callbacks = comptime makeClassCallbacks(T);

    if (gdzig.version.gte(.@"4.4")) {
        classdb.registerClass4(T, ClassUserdataOf(T), void, &class_name, &base_name, .{
            .userdata = info.userdata,
            .is_virtual = info.is_virtual,
            .is_abstract = info.is_abstract,
            .is_exposed = info.is_exposed,
            .is_runtime = info.is_runtime,
        }, callbacks.v4);
    } else if (gdzig.version.gte(.@"4.3")) {
        classdb.registerClass3(T, ClassUserdataOf(T), void, &class_name, &base_name, .{
            .userdata = info.userdata,
            .is_virtual = info.is_virtual,
            .is_abstract = info.is_abstract,
            .is_exposed = info.is_exposed,
            .is_runtime = info.is_runtime,
        }, callbacks.v3);
    } else if (gdzig.version.gte(.@"4.2")) {
        classdb.registerClass2(T, ClassUserdataOf(T), void, &class_name, &base_name, .{
            .userdata = info.userdata,
            .is_virtual = info.is_virtual,
            .is_abstract = info.is_abstract,
            .is_exposed = info.is_exposed,
        }, callbacks.v2);
    } else if (gdzig.version.gte(.@"4.1")) {
        classdb.registerClass1(T, ClassUserdataOf(T), &class_name, &base_name, .{
            .userdata = info.userdata,
            .is_virtual = info.is_virtual,
            .is_abstract = info.is_abstract,
        }, callbacks.v1);
    } else {
        @panic("Unsupported Godot version");
    }
}

/// Extracts the `ClassUserdata` type from a type `T` by inspecting its `create` function.
fn ClassUserdataOf(comptime T: type) type {
    if (!@hasDecl(T, "create")) {
        @compileError("Type '" ++ @typeName(T) ++ "' must have a 'create' function");
    }
    const params = @typeInfo(@TypeOf(T.create)).@"fn".params;
    return switch (params.len) {
        0 => void,
        1 => params[0].type.?,
        inline else => @compileError("Type '" ++ @typeName(T) ++ "'.create must take zero or one parameters"),
    };
}

/// This instance binding is only used in Godot 4.1 through 4.3; versions 4.4+
/// properly store and pass around the list lengths. Allocations are backed by a
/// memory pool and cleaned up at extension deinitialization.
const PropertyListMeta = struct {
    len: usize = 0,

    var gpa: if (builtin.is_test) void else DebugAllocator(.{}) = if (builtin.is_test) {} else .init;
    var pool: MemoryPool(PropertyListMeta) = .init(gpa.allocator());

    const callbacks: c.GDExtensionInstanceBindingCallbacks = .{
        .create_callback = &create,
        .free_callback = &free,
    };

    fn allocator() Allocator {
        return if (builtin.is_test) std.testing.allocator else gpa.allocator();
    }

    fn create(_: ?*anyopaque, _: ?*anyopaque) callconv(.c) ?*anyopaque {
        return @ptrCast(pool.create() catch return null);
    }

    fn free(_: ?*anyopaque, _: ?*anyopaque, binding: ?*anyopaque) callconv(.c) void {
        if (binding) |self| pool.destroy(@ptrCast(@alignCast(self)));
    }

    pub fn cleanup() void {
        pool.deinit();
        if (!builtin.is_test) assert(gpa.deinit() == .ok);
    }
};

/// Tracks destruction state to prevent double-free.
pub const DestroyMeta = struct {
    user_destroying: bool = false,
    engine_destroying: bool = false,

    var gpa: if (builtin.is_test) void else DebugAllocator(.{}) = if (builtin.is_test) {} else .init;
    var pool: MemoryPool(DestroyMeta) = .init(gpa.allocator());

    pub const callbacks: c.GDExtensionInstanceBindingCallbacks = .{
        .create_callback = &create,
        .free_callback = &free,
    };

    fn create(_: ?*anyopaque, _: ?*anyopaque) callconv(.c) ?*anyopaque {
        return @ptrCast(pool.create() catch return null);
    }

    fn free(_: ?*anyopaque, _: ?*anyopaque, binding: ?*anyopaque) callconv(.c) void {
        if (binding) |self| pool.destroy(@ptrCast(@alignCast(self)));
    }

    pub fn get(obj: *Object) ?*DestroyMeta {
        const raw_ptr = raw.objectGetInstanceBinding(obj, @ptrCast(@constCast(&callbacks)), &callbacks);
        return @ptrCast(@alignCast(raw_ptr));
    }

    pub fn cleanup() void {
        pool.deinit();
        if (!builtin.is_test) assert(gpa.deinit() == .ok);
    }
};

fn makeClassCallbacks(comptime T: type) struct {
    v1: classdb.ClassCallbacks1(T, ClassUserdataOf(T)),
    v2: classdb.ClassCallbacks2(T, ClassUserdataOf(T), void),
    v3: classdb.ClassCallbacks3(T, ClassUserdataOf(T), void),
    v4: classdb.ClassCallbacks4(T, ClassUserdataOf(T), void),
} {
    comptime {
        if (!@hasDecl(T, "create")) {
            @compileError("Type '" ++ @typeName(T) ++ "' must have a 'create' function");
        }
        if (!@hasDecl(T, "destroy")) {
            @compileError("Type '" ++ @typeName(T) ++ "' must have a 'destroy' function");
        }
    }

    const Base = object.BaseOf(T);

    const Callbacks = struct {
        /// Wraps `create` to bind the instance.
        ///
        /// @since 4.1
        /// @until 4.4
        fn create1(userdata: ClassUserdataOf(T)) anyerror!*T {
            return create2(userdata, false);
        }

        /// Wraps `create` to bind the instance and send the POSTINITIALIZE notification.
        ///
        /// @since 4.4
        fn create2(userdata: ClassUserdataOf(T), notify: bool) anyerror!*T {
            const self = if (ClassUserdataOf(T) == void)
                try T.create()
            else
                try T.create(userdata);

            const obj = Object.upcast(self);

            if (notify) {
                obj.notification(Object.NOTIFICATION_POSTINITIALIZE, .{
                    .reversed = false,
                });
            }

            return self;
        }

        /// Wraps `destroy` to set `base` to `undefined`.
        ///
        /// Godot's ownership rules of the base object are broken; they expect you
        /// to create the Base type `create()`, but not to destroy it in `destroy()`.
        ///
        /// Setting it to `undefined` will make it extremely obvious to the user that
        /// they made a mistake in Debug/ReleaseSafe builds.
        ///
        /// @since 4.1
        fn destroy(self: *T, userdata: ClassUserdataOf(T)) void {
            const obj = Object.upcast(self);
            if (DestroyMeta.get(obj)) |destroy_meta| {
                if (destroy_meta.user_destroying) return;
                destroy_meta.engine_destroying = true;
            }
            T.destroy(self, userdata);
        }

        /// Wraps `_notification` to best-effort synthesize a "reversed" parameter.
        ///
        /// @since 4.1
        /// @until 4.2
        fn notification1(instance: *T, what: i32) void {
            // This is a best-effort synthesization of "reversed" for Godot v4.1 and v4.2;
            // it does not cover the unlikely edge case where users are sending notifications
            // that are reversed unexpectedly.
            const reversed = switch (what) {
                gdzig.class.Object.NOTIFICATION_PREDELETE,
                gdzig.class.Node.NOTIFICATION_EXIT_TREE,
                gdzig.class.CanvasItem.NOTIFICATION_EXIT_CANVAS,
                gdzig.class.Node3D.NOTIFICATION_EXIT_WORLD,
                gdzig.class.Control.NOTIFICATION_FOCUS_EXIT,
                => true,
                else => false,
            };
            T._notification(instance, what, reversed);
        }

        fn getVirtual(userdata: ClassUserdataOf(T), name: *const StringName) ?*const classdb.CallVirtual(T) {
            _ = userdata;
            const UserVTable = Base.VTable.extend(T, virtualMethodNames(T));
            var buf: [256]u8 = undefined;
            const name_str = string.stringNameToAscii(name.*, buf[0..]);
            const result = UserVTable.get(name_str);
            return @ptrCast(result);
        }

        fn getVirtual2(userdata: ClassUserdataOf(T), name: *const StringName, hash: u32) ?*const classdb.CallVirtual(T) {
            _ = hash;
            return getVirtual(userdata, name);
        }

        /// Wraps `_getPropertyList` to store the returned list length in a `PropertyListMeta` instance binding.
        ///
        /// @since 4.1
        /// @until 4.3
        fn getPropertyList1(self: *T) std.mem.Allocator.Error![]const classdb.PropertyInfo {
            const list = try T._getPropertyList(self);
            errdefer destroyPropertyList1(self, list.ptr);

            const obj = Object.upcast(self);
            const raw_ptr = raw.objectGetInstanceBinding(obj, @ptrCast(@constCast(&PropertyListMeta.callbacks)), &PropertyListMeta.callbacks);
            const ptr: *PropertyListMeta = @ptrCast(@alignCast(raw_ptr orelse return error.OutOfMemory));
            ptr.len = list.len;

            return list;
        }

        /// Wraps `_destroyPropertyList` to fetch the list length from a `PropertyListMeta` instance binding.
        ///
        /// @since 4.1
        /// @until 4.3
        fn destroyPropertyList1(self: *T, list: [*]const classdb.PropertyInfo) void {
            const obj = Object.upcast(self);
            const raw_ptr = raw.objectGetInstanceBinding(obj, @ptrCast(@constCast(&PropertyListMeta.callbacks)), &PropertyListMeta.callbacks);
            const ptr: *PropertyListMeta = @ptrCast(@alignCast(raw_ptr orelse @panic("Failed to get property list metadata")));
            T._destroyPropertyList(self, list[0..ptr.len]);
        }
    };

    return .{
        .v1 = .{
            .create = Callbacks.create1,
            .destroy = Callbacks.destroy,

            .get_virtual = Callbacks.getVirtual,

            .set = if (@hasDecl(T, "_set")) T._set else null,
            .get = if (@hasDecl(T, "_get")) T._get else null,
            .get_property_list = if (@hasDecl(T, "_getPropertyList")) Callbacks.getPropertyList1 else null,
            .destroy_property_list = if (@hasDecl(T, "_destroyPropertyList")) Callbacks.destroyPropertyList1 else null,
            .property_can_revert = if (@hasDecl(T, "_propertyCanRevert")) T._propertyCanRevert else null,
            .property_get_revert = if (@hasDecl(T, "_propertyGetRevert")) T._propertyGetRevert else null,
            .notification = if (@hasDecl(T, "_notification")) Callbacks.notification1 else null,
            .to_string = if (@hasDecl(T, "_toString")) T._toString else null,
            .reference = if (@hasDecl(T, "_reference")) T._reference else null,
            .unreference = if (@hasDecl(T, "_unreference")) T._unreference else null,
            .get_rid = if (@hasDecl(T, "_getRid")) T._getRid else null,
        },
        .v2 = .{
            .create = Callbacks.create1,
            .destroy = Callbacks.destroy,
            .recreate = if (@hasDecl(T, "recreate")) T.recreate else null,

            .get_virtual = Callbacks.getVirtual,
            // .get_virtual_call_data - not yet supported
            // .call_virtual_with_data - not yet supported

            .set = if (@hasDecl(T, "_set")) T._set else null,
            .get = if (@hasDecl(T, "_get")) T._get else null,
            .get_property_list = if (@hasDecl(T, "_getPropertyList")) Callbacks.getPropertyList1 else null,
            .destroy_property_list = if (@hasDecl(T, "_destroyPropertyList")) Callbacks.destroyPropertyList1 else null,
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
            .create = Callbacks.create1,
            .destroy = Callbacks.destroy,
            .recreate = if (@hasDecl(T, "recreate")) T.recreate else null,

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
            .recreate = if (@hasDecl(T, "recreate")) T.recreate else null,

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

fn virtualMethodNames(comptime T: type) []const []const u8 {
    const callbacks = [_][]const u8{
        "_destroyPropertyList",
        "_get",
        "_getPropertyList",
        "_getRid",
        "_notification",
        "_propertyCanRevert",
        "_propertyGetRevert",
        "_reference",
        "_set",
        "_toString",
        "_unreference",
        "_validateProperty",
    };

    const decls = @typeInfo(T).@"struct".decls;
    var names: [decls.len][]const u8 = undefined;
    var count: usize = 0;

    for (decls) |decl| {
        // Must start with _
        if (decl.name.len == 0 or decl.name[0] != '_') continue;

        // Must be a function
        const field = @field(T, decl.name);
        const field_type_info = @typeInfo(@TypeOf(field));
        if (field_type_info != .@"fn") continue;

        // Must have at least one parameter (self) to be a virtual method
        if (field_type_info.@"fn".params.len == 0) continue;

        // Must not be a callback
        const is_callback = for (callbacks) |cb| {
            if (std.mem.eql(u8, decl.name, cb)) break true;
        } else false;
        if (is_callback) continue;

        names[count] = decl.name;
        count += 1;
    }

    return names[0..count];
}

pub fn registerMethod(comptime T: type, comptime name: DeclEnum(T)) void {
    const name_str = @tagName(name);
    var class_name = StringName.fromComptimeLatin1(meta.typeShortName(T));
    var method_name = StringName.fromComptimeLatin1(name_str);

    const MethodType = @TypeOf(@field(T, name_str));
    const fn_info = @typeInfo(MethodType).@"fn";
    const Args = fn_info.params;
    const ReturnType = fn_info.return_type orelse void;
    const arg_count = Args.len - 1;

    const return_value: classdb.PropertyInfo = .{
        .type = .forType(ReturnType),
    };

    const arg_infos: [arg_count]classdb.PropertyInfo = comptime blk: {
        var infos: [arg_count]classdb.PropertyInfo = undefined;
        for (0..arg_count) |i| {
            const ArgType = Args[i + 1].type.?;
            infos[i] = .{ .type = .forType(ArgType) };
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
        const method = @field(T, name_str);

        fn call(instance: *T, args: []const *const Variant) gdzig.CallError!Variant {
            var call_args: std.meta.ArgsTuple(MethodType) = undefined;
            call_args[0] = instance;
            inline for (1..Args.len) |i| {
                const ArgType = Args[i].type.?;
                if (i - 1 < args.len) {
                    call_args[i] = args[i - 1].as(ArgType) orelse return error.InvalidArgument;
                }
            }
            if (ReturnType == void) {
                @call(.auto, method, call_args);
                return Variant.nil;
            } else {
                const result = @call(.auto, method, call_args);
                return Variant.init(result);
            }
        }

        fn ptrCall(instance: *T, args: [*]const *const anyopaque, ret: *anyopaque) void {
            var call_args: std.meta.ArgsTuple(MethodType) = undefined;
            call_args[0] = instance;
            inline for (1..Args.len) |i| {
                const ArgType = Args[i].type.?;
                call_args[i] = ptrToArg(ArgType, args[i - 1]);
            }
            if (ReturnType == void) {
                @call(.auto, method, call_args);
            } else {
                const result = @call(.auto, method, call_args);
                @as(*ReturnType, @ptrCast(@alignCast(ret))).* = result;
            }
        }

        fn ptrToArg(comptime ArgType: type, p_arg: *const anyopaque) ArgType {
            if (comptime object.isRefCountedPtr(ArgType) and object.isOpaqueClassPtr(ArgType)) {
                const obj = raw.refGetObject(@ptrCast(p_arg));
                return @ptrCast(obj.?);
            } else if (comptime object.isOpaqueClassPtr(ArgType)) {
                return @ptrCast(@constCast(p_arg));
            } else {
                return @as(*const ArgType, @ptrCast(@alignCast(p_arg))).*;
            }
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
    var arg_info: [fields.len]classdb.PropertyInfo = undefined;
    var names: [fields.len]StringName = undefined;
    inline for (fields, 0..) |field, i| {
        names[i] = StringName.fromComptimeLatin1(field.name);
        arg_info[i] = .{
            .type = .forType(field.type),
            .name = &names[i],
        };
    }

    classdb.registerSignal(&class_name, &signal_name, &arg_info);
}

const raw = &gdzig.raw;

const std = @import("std");
const Allocator = std.mem.Allocator;
const DebugAllocator = std.heap.DebugAllocator;
const DeclEnum = std.meta.DeclEnum;
const MemoryPool = std.heap.MemoryPool;
const assert = std.debug.assert;
const builtin = @import("builtin");

const c = @import("gdextension");
const gdzig = @import("gdzig");
const meta = gdzig.meta;
const string = gdzig.string;
const object = gdzig.object;
const classdb = gdzig.class.ClassDB;
const ClassInfo4 = gdzig.class.ClassDB.ClassInfo4;
const String = gdzig.builtin.String;
const StringName = gdzig.builtin.StringName;
const Variant = gdzig.builtin.Variant;
const Object = gdzig.class.Object;
const oopz = @import("oopz");
