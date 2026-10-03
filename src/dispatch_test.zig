test "Godot 4.6 dispatch does not request 4.7 interfaces" {
    Resolver.reset(6);
    var library: u8 = 0;
    const table: DispatchTable = .init(Resolver.getProcAddress, &library);

    try std.testing.expectEqual(@as(usize, 0), Resolver.newer_lookups);
    try std.testing.expect(table.variantGetTypeByName == null);
    try std.testing.expect(table.classdbConstructObject3 == null);
    try std.testing.expect(table.classdbRegisterExtensionClass6 == null);
    try std.testing.expect(table.classdbConstructObject2 != null);
    try std.testing.expect(table.classdbRegisterExtensionClass5 != null);
    try std.testing.expectEqual(@as(usize, 1), Resolver.version_lookups);
    try std.testing.expect(!Resolver.lookup_before_version);
}

test "Godot 4.7 dispatch loads newer interfaces and reinitialization clears them" {
    Resolver.reset(7);
    var library: u8 = 0;
    var table: DispatchTable = .init(Resolver.getProcAddress, &library);

    try std.testing.expectEqual(@as(usize, 3), Resolver.newer_lookups);
    try std.testing.expect(table.variantGetTypeByName != null);
    try std.testing.expect(table.classdbConstructObject3 != null);
    try std.testing.expect(table.classdbRegisterExtensionClass6 != null);
    try std.testing.expectEqual(@as(u32, 7), table.version.minor);
    try std.testing.expectEqualStrings("mock", std.mem.span(table.version.string));
    try std.testing.expectEqual(@as(usize, 1), Resolver.version_lookups);
    try std.testing.expect(!Resolver.lookup_before_version);

    Resolver.reset(6);
    table = .init(Resolver.getProcAddress, &library);
    try std.testing.expectEqual(@as(usize, 0), Resolver.newer_lookups);
    try std.testing.expect(table.variantGetTypeByName == null);
    try std.testing.expect(table.classdbConstructObject3 == null);
    try std.testing.expect(table.classdbRegisterExtensionClass6 == null);
    try std.testing.expectEqual(@as(u32, 6), table.version.minor);
}

test "Godot 4.1 dispatch bootstraps without requesting optional interfaces" {
    Resolver.reset(1);
    var library: u8 = 0;
    const table: DispatchTable = .init(Resolver.getProcAddress, &library);

    inline for (compat.structFields(DispatchTable)) |field| {
        if (@typeInfo(field.type) == .optional) {
            try std.testing.expect(@field(table, field.name) == null);
        }
    }
    // The interface metadata contains 136 baseline functions, including the getter.
    try std.testing.expectEqual(@as(usize, 136), Resolver.total_lookups);
    try std.testing.expectEqual(@as(usize, 1), Resolver.version_lookups);
    try std.testing.expect(!Resolver.lookup_before_version);
}

/// The resolver is the engine boundary. Non-bootstrap pointers are never called.
const Resolver = struct {
    var minor: u32 = undefined;
    var newer_lookups: usize = undefined;
    var total_lookups: usize = undefined;
    var version_lookups: usize = undefined;
    var version_initialized: bool = undefined;
    var lookup_before_version: bool = undefined;

    fn reset(runtime_minor: u32) void {
        minor = runtime_minor;
        newer_lookups = 0;
        total_lookups = 0;
        version_lookups = 0;
        version_initialized = false;
        lookup_before_version = false;
    }

    fn getVersion(out: [*c]c.GDExtensionGodotVersion) callconv(.c) void {
        out.* = .{ .major = 4, .minor = minor, .patch = 1, .string = "mock" };
        version_initialized = true;
    }

    fn placeholder() callconv(.c) void {}

    fn getProcAddress(name: [*c]const u8) callconv(.c) c.GDExtensionInterfaceFunctionPtr {
        total_lookups += 1;
        const symbol = std.mem.span(name);
        if (std.mem.eql(u8, symbol, "get_godot_version")) {
            version_lookups += 1;
            return @ptrCast(&getVersion);
        }
        if (!version_initialized) lookup_before_version = true;
        for ([_][]const u8{
            "variant_get_type_by_name",
            "classdb_construct_object3",
            "classdb_register_extension_class6",
        }) |newer| {
            if (std.mem.eql(u8, symbol, newer)) newer_lookups += 1;
        }
        return @ptrCast(&placeholder);
    }
};

const std = @import("std");
const compat = @import("compat.zig");

const c = @import("gdextension");
const DispatchTable = @import("DispatchTable.zig");
