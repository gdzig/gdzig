/// Comptime vtable for virtual method dispatch using StaticStringMap.
/// method_names is an array of Zig method names (camelCase with _ prefix).
/// The VTable computes snake_case keys at comptime for O(1) lookup.
pub fn VTable(comptime T: type, comptime method_names: anytype) type {
    return struct {
        // Zig calling convention for user implementation
        const CallVirtual = gdzig.class.ClassDB.CallVirtual(T);
        // C calling convention wrapper for Godot
        const CCallVirtual = fn (self: *T, args: [*]const *const anyopaque, ret: *anyopaque) callconv(.c) void;
        const implemented_count = countImplemented();
        const map: std.StaticStringMap(c.GDExtensionClassCallVirtual) = .initComptime(blk: {
            var kvs: [implemented_count]struct { []const u8, c.GDExtensionClassCallVirtual } = undefined;
            var idx: usize = 0;
            for (method_names) |method_name| {
                if (findMethod(method_name)) |wrapper| {
                    // Convert _camelCase method name to _snake_case for lookup key
                    kvs[idx] = .{ casez.comptimeConvert(godot_case.virtual_method, method_name), wrapper };
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
            @setEvalBranchQuota(100_000);
            inline for (class.selfAndAncestorsOf(T)) |Owner| {
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

const std = @import("std");

const c = @import("gdextension");
const casez = @import("casez");
const gdzig = @import("gdzig");
const common = @import("common");
const godot_case = common.godot_case;
const class = gdzig.class;
