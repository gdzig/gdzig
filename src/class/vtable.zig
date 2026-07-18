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
                                    ptrcall.writeReturn(ReturnType, p_ret, result);
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
                                    args[j] = ptrcall.readArg(Arg, p_args[j - 1]);
                                }
                                if (ReturnType == void) {
                                    @call(.always_inline, method, args);
                                } else {
                                    const result = @call(.always_inline, method, args);
                                    ptrcall.writeReturn(ReturnType, p_ret, result);
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

// The integer/enum/flag assertions below are over-read/portability defense: on a
// little-endian host, a narrow 4-byte read of a valid int64 slot's low word happens to
// reproduce the value anyway, so those cases can't actually fail here. The f32 case is the
// one that discriminates: a narrow read there would misinterpret the low 4 bytes of the
// double-width slot as bit pattern, so it's the regression guard that actually exercises
// the width handling.
test "VTable ptrcall marshals virtual params at engine width" {
    const ProbeEnum = enum(i32) {
        zero = 0,
        one = 1,
        negative = -7,
    };

    const Flags = packed struct(u32) {
        alpha: bool = false,
        beta: bool = false,
        _padding: u30 = 0,
    };

    const Probe = struct {
        got_i32: i32 = 0,
        got_u32: u32 = 0,
        got_f32: f32 = 0,
        got_bool: bool = false,
        got_enum: ProbeEnum = .zero,
        got_flags: Flags = .{},

        pub fn _probeParams(self: *@This(), a: i32, b: u32, c_: f32, d: bool, e: ProbeEnum, f: Flags) void {
            self.got_i32 = a;
            self.got_u32 = b;
            self.got_f32 = c_;
            self.got_bool = d;
            self.got_enum = e;
            self.got_flags = f;
        }
    };

    const ProbeVTable = VTable(Probe, .{"_probeParams"});
    const wrapper = ProbeVTable.get("_probe_params").?;

    // Simulate the engine's ptrcall argument slots: every scalar travels in
    // a full 8-byte slot (int64/double/uint8), with unused high bytes left
    // as stack garbage. Poison everything first so a narrow read/write
    // would be caught reading (or leaving) garbage.
    var slot_i32: [8]u8 align(8) = .{0xAA} ** 8;
    std.mem.writeInt(i64, &slot_i32, -12345, .little);

    var slot_u32: [8]u8 align(8) = .{0xAA} ** 8;
    std.mem.writeInt(i64, &slot_u32, 4_000_000_000, .little); // > i32 max

    var slot_f32: [8]u8 align(8) = .{0xAA} ** 8;
    std.mem.writeInt(u64, &slot_f32, @as(u64, @bitCast(@as(f64, 3.5))), .little);

    var slot_bool: [8]u8 align(8) = .{0xAA} ** 8;
    slot_bool[0] = 1;

    var slot_enum: [8]u8 align(8) = .{0xAA} ** 8;
    std.mem.writeInt(i64, &slot_enum, -7, .little);

    var slot_flags: [8]u8 align(8) = .{0xAA} ** 8;
    std.mem.writeInt(i64, &slot_flags, 0b10, .little); // beta set, alpha clear

    var args: [6]c.GDExtensionConstTypePtr = .{
        @ptrCast(&slot_i32),
        @ptrCast(&slot_u32),
        @ptrCast(&slot_f32),
        @ptrCast(&slot_bool),
        @ptrCast(&slot_enum),
        @ptrCast(&slot_flags),
    };

    var probe: Probe = .{};
    var ret_slot: [8]u8 align(8) = .{0xAA} ** 8;

    wrapper(@ptrCast(&probe), &args, @ptrCast(&ret_slot));

    try std.testing.expectEqual(@as(i32, -12345), probe.got_i32);
    try std.testing.expectEqual(@as(u32, 4_000_000_000), probe.got_u32);
    try std.testing.expectEqual(@as(f32, 3.5), probe.got_f32);
    try std.testing.expectEqual(true, probe.got_bool);
    try std.testing.expectEqual(ProbeEnum.negative, probe.got_enum);
    try std.testing.expect(probe.got_flags.beta);
    try std.testing.expect(!probe.got_flags.alpha);
}

test "VTable ptrcall marshals virtual returns at engine width" {
    const ProbeEnum = enum(i16) {
        neg = -300,
    };

    const Flags = packed struct(u16) {
        a: bool = false,
        b: bool = false,
        _padding: u14 = 0,
    };

    const Returns = struct {
        pub fn _retI32(_: *@This()) i32 {
            return -123456;
        }
        pub fn _retU32(_: *@This()) u32 {
            return 4_111_222_333;
        }
        pub fn _retF32(_: *@This()) f32 {
            return -2.5;
        }
        pub fn _retBool(_: *@This()) bool {
            return true;
        }
        pub fn _retEnum(_: *@This()) ProbeEnum {
            return .neg;
        }
        pub fn _retFlags(_: *@This()) Flags {
            return .{ .b = true };
        }
        pub fn _retU64(_: *@This()) u64 {
            return 0xFFFF_FFFF_FFFF_FFFF;
        }
        pub fn _addAndReturn(_: *@This(), x: i32) i32 {
            return x + 1;
        }
    };

    const ReturnsVTable = VTable(Returns, .{
        "_retI32", "_retU32", "_retF32", "_retBool", "_retEnum", "_retFlags", "_retU64", "_addAndReturn",
    });
    var instance: Returns = .{};
    const instance_ptr: c.GDExtensionClassInstancePtr = @ptrCast(&instance);
    var no_args: [0]c.GDExtensionConstTypePtr = .{};

    {
        var ret: [8]u8 align(8) = .{0xAA} ** 8;
        ReturnsVTable.get("_ret_i32").?(instance_ptr, &no_args, @ptrCast(&ret));
        try std.testing.expectEqual(@as(i64, -123456), std.mem.readInt(i64, &ret, .little));
    }
    {
        var ret: [8]u8 align(8) = .{0xAA} ** 8;
        ReturnsVTable.get("_ret_u32").?(instance_ptr, &no_args, @ptrCast(&ret));
        try std.testing.expectEqual(@as(i64, 4_111_222_333), std.mem.readInt(i64, &ret, .little));
    }
    {
        var ret: [8]u8 align(8) = .{0xAA} ** 8;
        ReturnsVTable.get("_ret_f32").?(instance_ptr, &no_args, @ptrCast(&ret));
        const bits = std.mem.readInt(u64, &ret, .little);
        try std.testing.expectEqual(@as(f64, -2.5), @as(f64, @bitCast(bits)));
    }
    {
        var ret: [8]u8 align(8) = .{0xAA} ** 8;
        ReturnsVTable.get("_ret_bool").?(instance_ptr, &no_args, @ptrCast(&ret));
        try std.testing.expectEqual(@as(u8, 1), ret[0]);
    }
    {
        var ret: [8]u8 align(8) = .{0xAA} ** 8;
        ReturnsVTable.get("_ret_enum").?(instance_ptr, &no_args, @ptrCast(&ret));
        try std.testing.expectEqual(@as(i64, -300), std.mem.readInt(i64, &ret, .little));
    }
    {
        var ret: [8]u8 align(8) = .{0xAA} ** 8;
        ReturnsVTable.get("_ret_flags").?(instance_ptr, &no_args, @ptrCast(&ret));
        try std.testing.expectEqual(@as(i64, 0b10), std.mem.readInt(i64, &ret, .little));
    }
    {
        var ret: [8]u8 align(8) = .{0xAA} ** 8;
        ReturnsVTable.get("_ret_u64").?(instance_ptr, &no_args, @ptrCast(&ret));
        try std.testing.expectEqual(@as(u64, 0xFFFF_FFFF_FFFF_FFFF), std.mem.readInt(u64, &ret, .little));
    }
    {
        var arg_slot: [8]u8 align(8) = .{0xAA} ** 8;
        std.mem.writeInt(i64, &arg_slot, 41, .little);
        var args: [1]c.GDExtensionConstTypePtr = .{@ptrCast(&arg_slot)};
        var ret: [8]u8 align(8) = .{0xAA} ** 8;
        ReturnsVTable.get("_add_and_return").?(instance_ptr, &args, @ptrCast(&ret));
        try std.testing.expectEqual(@as(i64, 42), std.mem.readInt(i64, &ret, .little));
    }
}

const std = @import("std");

const c = @import("gdextension");
const casez = @import("casez");
const gdzig = @import("gdzig");
const common = @import("common");
const godot_case = common.godot_case;
const class = gdzig.class;
const ptrcall = @import("ptrcall.zig");
