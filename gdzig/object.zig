pub fn connect(obj: anytype, comptime S: type, callable: Callable) void {
    var signal_name: StringName = .fromComptimeLatin1(comptime meta.signalName(S));
    defer signal_name.deinit();

    _ = obj.connect(signal_name, callable, .{});
}

/// Downcast a value to a child type in the class hierarchy. Has some compile time checks, but returns null at runtime if the cast fails.
///
/// Expects pointer types, e.g `*Node` or `*MyClass`, not `Node` or `MyClass`.
pub fn downcast(comptime T: type, value: anytype) blk: {
    const U = @TypeOf(value);

    if (!isClassPtr(T)) {
        @compileError("downcast expects a class pointer type as the target type, found '" ++ @typeName(T) ++ "'");
    }
    if (!isClassPtr(U)) {
        @compileError("downcast expects a class pointer type as the source value, found '" ++ @typeName(U) ++ "'");
    }

    assertIsA(Child(U), Child(T));

    break :blk ?*Child(T);
} {
    const U = @TypeOf(value);

    if (@typeInfo(U) == .optional and value == null) {
        return null;
    }

    const name = typeName(Child(T));
    const tag = godot.interface.classdbGetClassTag(@ptrCast(name));
    const result = godot.interface.objectCastTo(@ptrCast(value), tag);

    if (result) |ptr| {
        if (isOpaqueClassPtr(T)) {
            return @ptrCast(@alignCast(ptr));
        } else {
            const obj: *anyopaque = godot.interface.objectGetInstanceBinding(ptr, godot.interface.library, null) orelse return null;
            return @ptrCast(@alignCast(obj));
        }
    } else {
        return null;
    }
}

/// Returns true if a type is a reference counted type.
///
/// Expects a class type, e.g. `Node` or `MyClass`, not `*Node` or `*MyClass`.
pub fn isRefCounted(comptime T: type) bool {
    return isA(RefCounted, T);
}

/// Returns true if a type is a pointer to a reference counted type.
///
/// Expects a pointer type, e.g. `*Node` or `*MyClass`, not `Node` or `MyClass`.
pub fn isRefCountedPtr(comptime T: type) bool {
    return isA(RefCounted, Child(T));
}

/// Upcasts a pointer to an object type.
///
/// Expects a pointer type, e.g. `*Node` or `*MyClass`, not `Node` or `MyClass`.
pub fn asObject(value: anytype) *Object {
    return upcast(*Object, value);
}

/// Upcasts a pointer to a reference counted type.
///
/// Expects a pointer type, e.g. `*Node` or `*MyClass`, not `Node` or `MyClass`.
pub fn asRefCounted(value: anytype) RefCounted {
    return upcast(*RefCounted, value);
}

fn assertCanInitialize(comptime T: type) void {
    comptime {
        if (@hasDecl(T, "init")) return;
        for (@typeInfo(T).@"struct".fields) |field| {
            if (std.mem.eql(u8, "base", field.name)) continue;
            if (field.default_value_ptr == null) {
                @compileError("The type '" ++ meta.typeShortName(T) ++ "' should either have an 'fn init(base: *" ++ meta.typeShortName(meta.BaseOf(T)) ++ ") " ++ meta.typeShortName(T) ++ "' function, or a default value for the field '" ++ field.name ++ "', but it has neither.");
            }
        }
    }
}

/// Comptime vtable for virtual method dispatch using StaticStringMap.
/// method_names is an array of Zig method names (camelCase with _ prefix).
/// The VTable computes snake_case keys at comptime for O(1) lookup.
pub fn VTable(comptime T: type, comptime method_names: anytype) type {
    return struct {
        // Zig calling convention for user implementation
        const CallVirtual = godot.class.ClassDB.CallVirtual(T);
        // C calling convention wrapper for Godot
        const CCallVirtual = fn (self: *T, args: [*]const *const anyopaque, ret: *anyopaque) callconv(.c) void;
        const implemented_count = countImplemented();
        const map: std.StaticStringMap(c.GDExtensionClassCallVirtual) = .initComptime(blk: {
            var kvs: [implemented_count]struct { []const u8, c.GDExtensionClassCallVirtual } = undefined;
            var idx: usize = 0;
            for (method_names) |method_name| {
                if (findMethod(method_name)) |wrapper| {
                    // Convert camelCase method name to snake_case for lookup key
                    kvs[idx] = .{ toSnakeCase(method_name), wrapper };
                    idx += 1;
                }
            }
            break :blk &kvs;
        });

        fn countImplemented() usize {
            @setEvalBranchQuota(20000);
            var count: usize = 0;
            for (method_names) |name| {
                if (findMethod(name) != null) count += 1;
            }
            return count;
        }

        fn findMethod(comptime method_name: []const u8) c.GDExtensionClassCallVirtual {
            @setEvalBranchQuota(20000);
            inline for (selfAndAncestorsOf(T)) |Owner| {
                if (@hasDecl(Owner, method_name)) {
                    const method = @field(Owner, method_name);
                    const FnType = @TypeOf(method);
                    const fn_info = @typeInfo(FnType).@"fn";
                    const ReturnType = fn_info.return_type orelse void;

                    const param_count = fn_info.params.len;
                    if (param_count == 1) {
                        // Only self parameter - generate simpler wrapper
                        const Wrapper = struct {
                            fn call(p_instance: c.GDExtensionClassInstancePtr, _: [*]const c.GDExtensionConstTypePtr, p_ret: c.GDExtensionTypePtr) callconv(.c) void {
                                const instance: *Owner = @ptrCast(@alignCast(p_instance));
                                if (ReturnType == void) {
                                    method(instance);
                                } else {
                                    const result = method(instance);
                                    const ret: *ReturnType = @ptrCast(@alignCast(p_ret));
                                    ret.* = result;
                                }
                            }
                        };
                        return @ptrCast(&Wrapper.call);
                    } else {
                        // Multiple parameters - build args tuple
                        const Wrapper = struct {
                            fn call(p_instance: c.GDExtensionClassInstancePtr, p_args: [*]const c.GDExtensionConstTypePtr, p_ret: c.GDExtensionTypePtr) callconv(.c) void {
                                const instance: *Owner = @ptrCast(@alignCast(p_instance));
                                var args: std.meta.ArgsTuple(FnType) = undefined;
                                args[0] = instance;
                                inline for (1..param_count) |j| {
                                    const Arg = fn_info.params[j].type.?;
                                    args[j] = @as(*const Arg, @ptrCast(@alignCast(p_args[j - 1]))).*;
                                }
                                if (ReturnType == void) {
                                    @call(.always_inline, method, args);
                                } else {
                                    const result = @call(.always_inline, method, args);
                                    const ret: *ReturnType = @ptrCast(@alignCast(p_ret));
                                    ret.* = result;
                                }
                            }
                        };
                        return @ptrCast(&Wrapper.call);
                    }
                }
            }
            return null;
        }

        /// Convert _camelCase to _snake_case at comptime.
        /// Handles acronyms: consecutive uppercase letters are grouped,
        /// but the last one starts a new word if followed by lowercase.
        /// e.g., "_enterTree" -> "_enter_tree"
        ///       "_getHTTPResponse" -> "_get_http_response"
        ///       "_parseURLString" -> "_parse_url_string"
        ///       "_getID" -> "_get_id"
        fn toSnakeCase(comptime input: []const u8) []const u8 {
            return comptime &SnakeCaseConverter(input).value;
        }

        fn SnakeCaseConverter(comptime input: []const u8) type {
            const len = snakeCaseLen(input);
            return struct {
                const value: [len]u8 = blk: {
                    var result: [len]u8 = undefined;
                    var j: usize = 0;
                    for (0..input.len) |i| {
                        const ch = input[i];
                        if (ch >= 'A' and ch <= 'Z') {
                            const prev_lower = i > 0 and input[i - 1] >= 'a' and input[i - 1] <= 'z';
                            const next_lower = i + 1 < input.len and input[i + 1] >= 'a' and input[i + 1] <= 'z';
                            const prev_upper = i > 0 and input[i - 1] >= 'A' and input[i - 1] <= 'Z';
                            if (prev_lower or (prev_upper and next_lower)) {
                                result[j] = '_';
                                j += 1;
                            }
                            result[j] = ch - 'A' + 'a';
                        } else {
                            result[j] = ch;
                        }
                        j += 1;
                    }
                    break :blk result;
                };
            };
        }

        fn snakeCaseLen(comptime input: []const u8) usize {
            var extra: usize = 0;
            for (0..input.len) |i| {
                const ch = input[i];
                if (ch >= 'A' and ch <= 'Z') {
                    const prev_lower = i > 0 and input[i - 1] >= 'a' and input[i - 1] <= 'z';
                    const next_lower = i + 1 < input.len and input[i + 1] >= 'a' and input[i + 1] <= 'z';
                    const prev_upper = i > 0 and input[i - 1] >= 'A' and input[i - 1] <= 'Z';
                    if (prev_lower or (prev_upper and next_lower)) {
                        extra += 1;
                    }
                }
            }
            return input.len + extra;
        }

        pub fn has(name: []const u8) bool {
            return map.has(name);
        }

        pub fn get(name: []const u8) c.GDExtensionClassCallVirtual {
            return map.get(name) orelse null;
        }

        /// Extend this vtable with additional methods from a derived type.
        pub fn extend(comptime Derived: type, comptime override_names: anytype) type {
            return VTable(Derived, combineNames(override_names));
        }

        fn countNew(comptime override_names: anytype) usize {
            @setEvalBranchQuota(20000);
            var count: usize = 0;
            outer: for (override_names) |override_name| {
                for (method_names) |base_name| {
                    if (std.mem.eql(u8, override_name, base_name)) {
                        continue :outer;
                    }
                }
                count += 1;
            }
            return count;
        }

        fn combineNames(comptime override_names: anytype) [method_names.len + countNew(override_names)][]const u8 {
            @setEvalBranchQuota(20000);
            var combined: [method_names.len + countNew(override_names)][]const u8 = undefined;

            // Copy base names
            for (0..method_names.len) |i| {
                combined[i] = method_names[i];
            }

            // Add override names that aren't already in base
            var i: usize = 0;
            outer: for (override_names) |override_name| {
                for (method_names) |base_name| {
                    if (std.mem.eql(u8, override_name, base_name)) {
                        continue :outer;
                    }
                }
                combined[method_names.len + i] = override_name;
                i += 1;
            }

            return combined;
        }
    };
}

const std = @import("std");
const Allocator = std.mem.Allocator;

const oopz = @import("oopz");
pub const assertIsA = oopz.assertIsA;
pub const assertIsAny = oopz.assertIsAny;
pub const isClass = oopz.isClass;
pub const isOpaqueClass = oopz.isOpaqueClass;
pub const isStructClass = oopz.isStructClass;
pub const isClassPtr = oopz.isClassPtr;
pub const isOpaqueClassPtr = oopz.isOpaqueClassPtr;
pub const isStructClassPtr = oopz.isStructClassPtr;
pub const BaseOf = oopz.BaseOf;
pub const depthOf = oopz.depthOf;
pub const ancestorsOf = oopz.ancestorsOf;
pub const selfAndAncestorsOf = oopz.selfAndAncestorsOf;
pub const isA = oopz.isA;
pub const isAny = oopz.isAny;
pub const upcast = oopz.upcast;

const godot = @import("gdzig.zig");
const Child = godot.meta.RecursiveChild;
const c = godot.c;
const meta = godot.meta;
const PropertyHint = godot.global.PropertyHint;
const PropertyUsageFlags = godot.global.PropertyUsageFlags;
const typeName = meta.typeName;
const Object = godot.class.Object;
const RefCounted = godot.class.RefCounted;
const Callable = godot.builtin.Callable;
const String = godot.builtin.String;
const StringName = godot.builtin.StringName;
const Variant = godot.builtin.Variant;

test "VTable snake_case conversion" {
    const TestVTable = VTable(struct {
        pub fn _enterTree(_: *@This()) void {}
        pub fn _getHTTPResponse(_: *@This()) void {}
        pub fn _parseURLString(_: *@This()) void {}
        pub fn _getID(_: *@This()) void {}
        pub fn _ready(_: *@This()) void {}
        pub fn _physics2DProcess(_: *@This()) void {}
        pub fn _physics3DProcess(_: *@This()) void {}
        pub fn _get2DPosition(_: *@This()) void {}
    }, .{ "_enterTree", "_getHTTPResponse", "_parseURLString", "_getID", "_ready", "_physics2DProcess", "_physics3DProcess", "_get2DPosition" });

    try std.testing.expect(TestVTable.has("_enter_tree"));
    try std.testing.expect(TestVTable.has("_get_http_response"));
    try std.testing.expect(TestVTable.has("_parse_url_string"));
    try std.testing.expect(TestVTable.has("_get_id"));
    try std.testing.expect(TestVTable.has("_ready"));
    try std.testing.expect(TestVTable.has("_physics2d_process"));
    try std.testing.expect(TestVTable.has("_physics3d_process"));
    try std.testing.expect(TestVTable.has("_get2d_position"));
    try std.testing.expect(!TestVTable.has("_not_implemented"));
}

test "VTable extend combines method names" {
    const BaseType = struct {
        pub fn _ready(_: *@This()) void {}
        pub fn _process(_: *@This()) void {}
    };
    const Base = VTable(BaseType, .{ "_ready", "_process" });

    // Derived implements _ready (override) and _enterTree (new), but also _process (inherited)
    const DerivedType = struct {
        pub fn _ready(_: *@This()) void {}
        pub fn _process(_: *@This()) void {}
        pub fn _enterTree(_: *@This()) void {}
    };
    const Derived = Base.extend(DerivedType, .{ "_ready", "_enterTree" });

    // All methods should be findable
    try std.testing.expect(Derived.has("_ready"));
    try std.testing.expect(Derived.has("_process")); // from base method_names
    try std.testing.expect(Derived.has("_enter_tree")); // new in derived
}
