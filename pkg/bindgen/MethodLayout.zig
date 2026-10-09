//! Compare ptrcall layouts from independently extracted API records.

pub const Result = union(enum) {
    identical,
    trailing_defaults: struct { added_arguments: []const []const u8 },
    abi_compatible: Reason,
    return_added,
    incompatible: []const u8,
};

pub const Reason = enum {
    const_flag,
    renamed_enum,
};

pub const Class = std.meta.Tag(Result);

fn mismatch(allocator: Allocator, comptime format: []const u8, args: anytype) !Result {
    return .{
        .incompatible = try std.fmt.allocPrint(allocator, format, args),
    };
}

fn enumTable(tables: []const Records.Enum, type_name: []const u8) ?Records.Enum {
    const prefix: usize = if (std.mem.startsWith(u8, type_name, "enum::"))
        6
    else if (std.mem.startsWith(u8, type_name, "bitfield::"))
        10
    else
        return null;
    for (tables) |table| {
        if (std.mem.eql(u8, table.name, type_name[prefix..])) return table;
    }
    return null;
}

fn isEnum(type_name: []const u8) bool {
    return std.mem.startsWith(u8, type_name, "enum::") or
        std.mem.startsWith(u8, type_name, "bitfield::");
}

fn sameEnum(before: Records.Enum, after: Records.Enum) bool {
    if (before.is_bitfield != after.is_bitfield or before.values.len != after.values.len) {
        return false;
    }
    for (before.values) |value| {
        var matches: usize = 0;
        for (after.values) |candidate| {
            if (std.mem.eql(u8, value.name, candidate.name) and value.value == candidate.value) {
                matches += 1;
            }
        }
        if (matches != 1) return false;
    }
    return true;
}

fn compatibleType(
    before: []const u8,
    after: []const u8,
    old_enums: []const Records.Enum,
    new_enums: []const Records.Enum,
) bool {
    if (isEnum(before) or isEnum(after)) {
        const old = enumTable(old_enums, before) orelse return false;
        const new = enumTable(new_enums, after) orelse return false;
        if (std.mem.eql(u8, before, after)) return true;
        return std.mem.startsWith(u8, before, "bitfield::") ==
            std.mem.startsWith(u8, after, "bitfield::") and sameEnum(old, new);
    }
    return std.mem.eql(u8, before, after);
}

/// Classify measured layouts without suppressing differences requiring a shim.
/// Enum renames require complete, identical name-to-value sets on both sides.
pub fn classify(
    allocator: Allocator,
    before: Records.Record,
    after: Records.Record,
    old_enums: []const Records.Enum,
    new_enums: []const Records.Enum,
) !Result {
    // Static and vararg changes alter invocation shape, unlike constness alone.
    if (before.is_static != after.is_static) {
        return mismatch(allocator, "is_static: {} -> {}", .{ before.is_static, after.is_static });
    }
    if (before.is_vararg != after.is_vararg) {
        return mismatch(allocator, "is_vararg: {} -> {}", .{ before.is_vararg, after.is_vararg });
    }

    const old_return = before.@"return" orelse Records.Return{ .type = "void", .meta = "" };
    const new_return = after.@"return" orelse Records.Return{ .type = "void", .meta = "" };
    if (!compatibleType(old_return.type, new_return.type, old_enums, new_enums) or
        !std.mem.eql(u8, old_return.meta, new_return.meta))
    {
        if (std.mem.eql(u8, old_return.type, "void") and
            !std.mem.eql(u8, new_return.type, "void"))
        {
            return .return_added;
        }
        return mismatch(allocator, "return: {s}/{s} -> {s}/{s}", .{
            old_return.type,
            old_return.meta,
            new_return.type,
            new_return.meta,
        });
    }
    var renamed_enum = !std.mem.eql(u8, old_return.type, new_return.type);

    // Compare every original argument before considering trailing defaults.
    if (before.arguments.len > after.arguments.len) {
        return mismatch(allocator, "argument count: {d} -> {d}", .{
            before.arguments.len,
            after.arguments.len,
        });
    }
    for (before.arguments, after.arguments[0..before.arguments.len], 0..) |old, new, index| {
        if (!compatibleType(old.type, new.type, old_enums, new_enums) or
            !std.mem.eql(u8, old.meta, new.meta))
        {
            return mismatch(allocator, "argument {d}: {s}/{s} -> {s}/{s}", .{
                index,
                old.type,
                old.meta,
                new.type,
                new.meta,
            });
        }
        renamed_enum = renamed_enum or !std.mem.eql(u8, old.type, new.type);
    }
    const extra = after.arguments[before.arguments.len..];
    for (extra, before.arguments.len..) |argument, index| {
        if (!argument.has_default) {
            return mismatch(allocator, "argument {d} ({s}): added without default", .{
                index,
                argument.name,
            });
        }
    }
    if (extra.len != 0) {
        const names = try allocator.alloc([]const u8, extra.len);
        for (extra, names) |argument, *name| {
            name.* = argument.name;
        }
        return .{ .trailing_defaults = .{ .added_arguments = names } };
    }
    if (renamed_enum) return .{ .abi_compatible = .renamed_enum };
    if (before.is_const != after.is_const) {
        return .{ .abi_compatible = .const_flag };
    }
    return .identical;
}

fn probe() Records.Record {
    return .{
        .kind = .class,
        .owner = "Probe",
        .method = "probe",
        .hash = 1,
        .compatibility = &.{},
        .virtual = false,
        .is_const = false,
        .is_static = false,
        .is_vararg = false,
        .arguments = &.{},
        .@"return" = null,
    };
}

test "identical trailing default and required trailing arguments" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const old = probe();
    try std.testing.expectEqual(Class.identical, std.meta.activeTag(try classify(allocator, old, old, &.{}, &.{})));
    var current = old;
    current.arguments = &.{.{ .name = "enabled", .type = "bool", .has_default = true }};
    const result = try classify(allocator, old, current, &.{}, &.{});
    try std.testing.expectEqual(Class.trailing_defaults, std.meta.activeTag(result));
    try std.testing.expectEqualStrings("enabled", result.trailing_defaults.added_arguments[0]);
    current.arguments = &.{.{ .name = "enabled", .type = "bool" }};
    const incompatible = try classify(allocator, old, current, &.{}, &.{});
    try std.testing.expectEqual(Class.incompatible, std.meta.activeTag(incompatible));
    try std.testing.expectEqualStrings("argument 0 (enabled): added without default", incompatible.incompatible);
}

test "argument return meta static vararg and const changes remain visible" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var old = probe();
    old.arguments = &.{.{ .type = "int", .meta = "int64" }};
    var current = old;
    current.arguments = &.{.{ .type = "float", .meta = "double" }};
    try std.testing.expectEqual(Class.incompatible, std.meta.activeTag(try classify(allocator, old, current, &.{}, &.{})));
    current.arguments = &.{.{ .type = "int", .meta = "int32" }};
    try std.testing.expectEqual(Class.incompatible, std.meta.activeTag(try classify(allocator, old, current, &.{}, &.{})));
    current.arguments = &.{};
    try std.testing.expectEqual(Class.incompatible, std.meta.activeTag(try classify(allocator, old, current, &.{}, &.{})));
    current = old;
    current.@"return" = .{ .type = "bool", .meta = "" };
    try std.testing.expectEqual(Class.return_added, std.meta.activeTag(try classify(allocator, old, current, &.{}, &.{})));
    current = old;
    current.is_static = true;
    try std.testing.expectEqual(Class.incompatible, std.meta.activeTag(try classify(allocator, old, current, &.{}, &.{})));
    current = old;
    current.is_vararg = true;
    try std.testing.expectEqual(Class.incompatible, std.meta.activeTag(try classify(allocator, old, current, &.{}, &.{})));
    current = old;
    current.is_const = true;
    const result = try classify(allocator, old, current, &.{}, &.{});
    try std.testing.expectEqual(Class.abi_compatible, std.meta.activeTag(result));
    try std.testing.expectEqual(Reason.const_flag, result.abi_compatible);
}

test "enum renames require equal values and missing tables fail even for unchanged names" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const values: []const Records.EnumValue = &.{
        .{ .name = "OFF", .value = 0 },
        .{ .name = "ON", .value = 1 },
    };
    const old_enums = &.{Records.Enum{ .name = "Old.Mode", .is_bitfield = false, .values = values }};
    const new_enums = &.{Records.Enum{ .name = "New.Mode", .is_bitfield = false, .values = values }};
    var old = probe();
    old.@"return" = .{ .type = "enum::Old.Mode", .meta = "" };
    var current = old;
    current.@"return" = .{ .type = "enum::New.Mode", .meta = "" };
    const result = try classify(allocator, old, current, old_enums, new_enums);
    try std.testing.expectEqual(Class.abi_compatible, std.meta.activeTag(result));
    try std.testing.expectEqual(Reason.renamed_enum, result.abi_compatible);
    try std.testing.expectEqual(Class.incompatible, std.meta.activeTag(try classify(allocator, old, old, &.{}, &.{})));
    const changed = &.{Records.Enum{
        .name = "New.Mode",
        .is_bitfield = false,
        .values = &.{.{ .name = "ON", .value = 2 }},
    }};
    try std.testing.expectEqual(Class.incompatible, std.meta.activeTag(try classify(allocator, old, current, old_enums, changed)));
}

test "layout result stores only its active classification payload" {
    try std.testing.expectEqual(.@"union", std.meta.activeTag(@typeInfo(Result)));
}

const std = @import("std");
const Allocator = std.mem.Allocator;

const Records = @import("CompatRecords.zig");
