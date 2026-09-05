const std = @import("std");
const DeclEnum = std.meta.DeclEnum;

const casez = @import("casez");
const common = @import("common");
const godot_case = common.godot_case;

const gdzig = @import("gdzig");
const class = gdzig.class;
const ptrcall = @import("../class/ptrcall.zig");
const classdb = gdzig.class.ClassDb;
const MethodFlags = gdzig.global.MethodFlags;
const StringName = gdzig.builtin.StringName;
const Variant = gdzig.builtin.Variant;

const Registry = @import("Registry.zig");

/// Registers a method on a class.
///
/// Example:
/// ```
/// godot.registerMethod(MyClass, .decl(.myMethod));
/// ```
pub fn registerMethod(comptime Class: type, comptime config: MethodConfig(Class)) void {
    var class_name: StringName = .fromType(Class);
    var method_name: StringName = .fromComptimeLatin1(config.name);

    classdb.registerMethod(Class, void, &class_name, .{
        .name = &method_name,
        .flags = config.flags,
        .return_value_info = config.return_value_info,
        .return_value_metadata = config.return_value_metadata,
        .argument_info = config.argument_info,
        .argument_metadata = config.argument_metadata,
        .default_arguments = config.default_arguments,
    }, .{
        .call = config.call,
        .ptr_call = config.ptr_call,
    });
}

pub fn MethodConfig(comptime Class: type) type {
    return struct {
        name: [:0]const u8,
        return_type: type = void,
        flags: MethodFlags = .{},
        return_value_info: ?*classdb.PropertyInfo = null,
        return_value_metadata: classdb.MethodArgumentMetadata = .none,
        argument_info: []const classdb.PropertyInfo = &.{},
        argument_metadata: []const classdb.MethodArgumentMetadata = &.{},
        default_arguments: []const *const Variant = &.{},
        call: ?classdb.Call(Class, void) = null,
        ptr_call: ?classdb.PtrCall(Class, void) = null,

        const Self = @This();

        /// Creates a MethodConfig from a method name and decl name.
        /// The name is what Godot sees (snake_case), decl_name is the Zig decl.
        pub fn fromName(comptime name: [:0]const u8, comptime decl_name: [:0]const u8, comptime options: Registry.Method(Class).CreateOptions) Self {
            const MethodType = @TypeOf(@field(Class, decl_name));
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
                const method = @field(Class, decl_name);

                fn call(instance: *Class, args: []const *const Variant) gdzig.CallError!Variant {
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
                        const variant = Variant.init(ReturnType, result);
                        releaseVarReturn(ReturnType, result);
                        return variant;
                    }
                }

                fn ptrCall(instance: *Class, args: [*]const *const anyopaque, ret: ?*anyopaque) void {
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
                        if (ret) |r| {
                            writePtrReturn(ReturnType, r, result);
                        }
                    }
                }
            };

            return .{
                .name = name,
                .return_type = ReturnType,
                .flags = options.flags,
                .return_value_info = if (ReturnType != void) @constCast(&return_value) else null,
                .argument_info = @constCast(&arg_infos),
                .argument_metadata = @constCast(&arg_metas),
                .default_arguments = options.default_arguments,
                .call = Callbacks.call,
                .ptr_call = Callbacks.ptrCall,
            };
        }

        /// Creates a getter method for a class field.
        /// name: the method name Godot sees (e.g., "get_health")
        /// field_name: the Zig field name (e.g., "health")
        pub fn getter(comptime name: [:0]const u8, comptime field_name: [:0]const u8) Self {
            const FieldType = @FieldType(Class, field_name);

            const return_value: classdb.PropertyInfo = .{ .type = .forType(FieldType) };

            const Callbacks = struct {
                fn call(instance: *Class, _: []const *const Variant) gdzig.CallError!Variant {
                    return Variant.init(FieldType, @field(instance, field_name));
                }

                fn ptrCall(instance: *Class, _: [*]const *const anyopaque, ret: ?*anyopaque) void {
                    if (ret) |r| {
                        writePtrReturn(FieldType, r, @field(instance, field_name));
                    }
                }
            };

            return .{
                .name = name,
                .return_type = FieldType,
                .return_value_info = @constCast(&return_value),
                .call = Callbacks.call,
                .ptr_call = Callbacks.ptrCall,
            };
        }

        /// Creates a setter method for a class field.
        /// name: the method name Godot sees (e.g., "set_health")
        /// field_name: the Zig field name (e.g., "health")
        pub fn setter(comptime name: [:0]const u8, comptime field_name: [:0]const u8) Self {
            const FieldType = @FieldType(Class, field_name);

            const arg_info: [1]classdb.PropertyInfo = .{.{ .type = .forType(FieldType) }};
            const arg_meta: [1]classdb.MethodArgumentMetadata = .{.none};

            const Callbacks = struct {
                fn call(instance: *Class, args: []const *const Variant) gdzig.CallError!Variant {
                    if (args.len < 1) return error.TooFewArguments;
                    const value = args[0].as(FieldType) orelse return error.InvalidArgument;
                    @field(instance, field_name) = value;
                    return Variant.nil;
                }

                fn ptrCall(instance: *Class, args: [*]const *const anyopaque, _: ?*anyopaque) void {
                    @field(instance, field_name) = ptrToArg(FieldType, args[0]);
                }
            };

            return .{
                .name = name,
                .argument_info = @constCast(&arg_info),
                .argument_metadata = @constCast(&arg_meta),
                .call = Callbacks.call,
                .ptr_call = Callbacks.ptrCall,
            };
        }
    };
}

/// Decode one extension-method ptrcall argument. RefCounted values travel
/// through Godot's Ref ABI, including extension classes and nullable Refs;
/// their slot is not the raw object pointer represented by the Zig type.
fn ptrToArg(comptime ArgType: type, p_arg: *const anyopaque) ArgType {
    if (comptime class.isRefCountedPtr(ArgType)) {
        const Ptr = class.ClassPtrOf(ArgType);
        const object = gdzig.raw.refGetObject(@ptrCast(p_arg)) orelse {
            if (comptime class.isNullableClassPtr(ArgType)) return null;
            @panic("non-null RefCounted ptrcall argument contained a null Ref");
        };

        const value: Ptr = if (comptime class.isOpaqueClassPtr(Ptr))
            @ptrCast(@alignCast(object))
        else blk: {
            const Class = std.meta.Child(Ptr);
            const Base = class.BaseOf(Class);
            const base: *Base = @ptrCast(@alignCast(object));
            break :blk base.asInstance(Class) orelse @panic("Ref ptrcall argument has the wrong extension class");
        };
        return @as(ArgType, value);
    }

    if (comptime class.isOpaqueClassPtr(ArgType)) {
        return @ptrCast(@constCast(p_arg));
    }
    return ptrcall.readArg(ArgType, p_arg);
}

/// Encode one extension-method ptrcall return. Godot supplies storage for a
/// Ref wrapper when the declared type is RefCounted, so populate that wrapper
/// instead of writing the Zig object pointer directly into it.
fn writePtrReturn(comptime ReturnType: type, p_ret: *anyopaque, value: ReturnType) void {
    if (comptime class.isRefCountedPtr(ReturnType)) {
        const object: ?*gdzig.class.Object = if (comptime class.isNullableClassPtr(ReturnType))
            if (value) |object_value| .upcast(object_value) else null
        else
            .upcast(value);
        gdzig.raw.refSetObject(@ptrCast(p_ret), if (object) |obj| @ptrCast(obj) else null);
        return;
    }
    ptrcall.writeReturn(ReturnType, p_ret, value);
}

/// Drop the callee's own reference to a value it just returned through the varcall path, so
/// that both entry points registered for a bound method agree on who owns the return value.
///
/// `ptrcall` sets the convention for builtins: `ptrcall.writeReturn` writes the struct into
/// the engine's return slot bitwise, which is a move — ownership transfers to the caller and
/// the callee's local is dead afterwards. `varcall` cannot move, because `Variant.init` goes
/// through Godot's copy constructor and takes a reference of its own. Without this call the
/// callee's reference is never dropped, so a method returning a freshly built `Array` leaks
/// it on `varcall` while being correct on `ptrcall`, and a method returning a borrowed one is
/// a use-after-free on `ptrcall` — no return value is correct on both paths.
///
/// Only builtins with a Godot destructor are released. Godot reports that through
/// `has_destructor`, and bindgen emits `deinit` exactly for those, so `@hasDecl` is the
/// type-driven form of that flag: `Array`, `Dictionary`, `String`, `StringName`, `NodePath`,
/// `Callable`, `Signal` and the `Packed*Array` family have one; `Vector2`, `Color`, `Rect2`,
/// `Transform3d`, `Basis`, `Projection`, `Aabb` and friends do not. Restricting to structs
/// keeps `@hasDecl` off scalars, enums and pointers, where it would not compile.
///
/// Object pointers are deliberately *not* released. Both paths already agree on them:
/// `writePtrReturn` hands a RefCounted return to `refSetObject`, which calls Godot's
/// `reference_ptr` and takes a reference for the caller, exactly as `Variant.init` does. They
/// are both copies, so releasing here would leave the caller holding the only reference to an
/// object the callee still believes it owns. Non-refcounted object pointers are never
/// referenced by either path and own nothing.
///
/// `Variant` itself has a `deinit` and would match the struct-with-`deinit` predicate below, but
/// it is unreachable as a `ReturnType` today because `Variant.Tag.forType` has no `Variant` case
/// and `@compileError`s first. If a pass-through `Variant` return is ever added, releasing it
/// here would double-free: exempt it explicitly, or re-derive its ownership from scratch.
fn releaseVarReturn(comptime ReturnType: type, value: ReturnType) void {
    if (comptime @typeInfo(ReturnType) == .@"struct" and @hasDecl(ReturnType, "deinit")) {
        var owned: ReturnType = value;
        owned.deinit();
    }
}
