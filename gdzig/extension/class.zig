const std = @import("std");
const Allocator = std.mem.Allocator;
const MemoryPool = std.heap.MemoryPool;
const assert = std.debug.assert;

const c = @import("gdextension");
const common = @import("common");
const GeneralPurposeAllocator = common.GeneralPurposeAllocator;
const gdzig = @import("gdzig");
const class = gdzig.class;
const classdb = gdzig.class.ClassDb;
const ClassInfo4 = gdzig.class.ClassDb.ClassInfo4;
const String = gdzig.builtin.String;
const StringName = gdzig.builtin.StringName;
const Object = gdzig.class.Object;

pub fn registerClass(comptime T: type, info: ClassInfo4(ClassUserdataOf(T))) void {
    const class_name: StringName = .fromType(T);
    const base_name: StringName = .fromType(class.BaseOf(T));
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
pub fn ClassUserdataOf(comptime T: type) type {
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
pub const PropertyListInstanceBinding = struct {
    len: usize = 0,

    var gpa: GeneralPurposeAllocator = .init(gdzig.engine_allocator);
    const allocator = gpa.allocator();
    var pool: MemoryPool(PropertyListInstanceBinding) = .init(allocator);

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

    pub fn cleanup() void {
        pool.deinit();
        assert(gpa.deinit() == .ok);
    }
};

/// Tracks destruction state to prevent double-free.
pub const DestroyInstanceBinding = struct {
    user_destroying: bool = false,
    engine_destroying: bool = false,

    var gpa: GeneralPurposeAllocator = .init(gdzig.engine_allocator);
    const allocator = gpa.allocator();
    var pool: MemoryPool(PropertyListInstanceBinding) = .init(allocator);

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

    pub fn get(obj: *Object) ?*DestroyInstanceBinding {
        const raw_ptr = gdzig.raw.objectGetInstanceBinding(obj, @ptrCast(@constCast(&callbacks)), &callbacks);
        return @ptrCast(@alignCast(raw_ptr));
    }

    pub fn cleanup() void {
        pool.deinit();
        assert(gpa.deinit() == .ok);
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

    const Base = class.BaseOf(T);

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
            if (DestroyInstanceBinding.get(obj)) |destroy_meta| {
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
                gdzig.class.Node3d.NOTIFICATION_EXIT_WORLD,
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
            const name_str = String.fromStringName(name.*).toLatin1Buf(buf[0..]);
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
            const raw_ptr = gdzig.raw.objectGetInstanceBinding(obj, @ptrCast(@constCast(&PropertyListInstanceBinding.callbacks)), &PropertyListInstanceBinding.callbacks);
            const ptr: *PropertyListInstanceBinding = @ptrCast(@alignCast(raw_ptr orelse return error.OutOfMemory));
            ptr.len = list.len;

            return list;
        }

        /// Wraps `_destroyPropertyList` to fetch the list length from a `PropertyListMeta` instance binding.
        ///
        /// @since 4.1
        /// @until 4.3
        fn destroyPropertyList1(self: *T, list: [*]const classdb.PropertyInfo) void {
            const obj = Object.upcast(self);
            const raw_ptr = gdzig.raw.objectGetInstanceBinding(obj, @ptrCast(@constCast(&PropertyListInstanceBinding.callbacks)), &PropertyListInstanceBinding.callbacks);
            const ptr: *PropertyListInstanceBinding = @ptrCast(@alignCast(raw_ptr orelse @panic("Failed to get property list metadata")));
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
