//! Build positional legacy functions from measured old signatures.

/// Convert an old measured signature with the same mapping as ordinary API methods.
pub fn build(
    allocator: Allocator,
    modern: Context.Function,
    group: version_dispatch.Group,
    ctx: *const Context,
) !Context.Function {
    const signature = group.signature;
    const flags = signature.flags;
    const old_arguments = signature.arguments;
    var notes: std.ArrayList(u8) = .empty;
    defer notes.deinit(allocator);

    // Preserve old positional names and types, without applying old defaults.
    const arguments = try allocator.alloc(GodotApi.Class.Method.Argument, old_arguments.len);
    defer allocator.free(arguments);
    for (old_arguments, arguments) |old, *argument| {
        const type_name = try mapEnum(allocator, old.type, ctx, &notes);
        argument.* = .{
            .name = old.name,
            .type = type_name,
            .meta = if (std.mem.eql(u8, type_name, old.type)) old.meta else "",
        };
    }
    const return_value: ?GodotApi.Class.Method.ReturnValue = if (signature.@"return") |old| blk: {
        const type_name = try mapEnum(allocator, old.type, ctx, &notes);
        break :blk .{
            .type = type_name,
            .meta = if (std.mem.eql(u8, type_name, old.type)) old.meta else "",
        };
    } else null;

    // Reuse ordinary signature mapping and original owner/singleton identity.
    var legacy = try Context.Function.fromClass(
        allocator,
        modern.base orelse return error.MissingLegacyOwner,
        modern.self == .singleton,
        .{
            .name = modern.name_api,
            .hash = group.old_hash,
            .is_const = flags.is_const,
            .is_static = flags.is_static,
            .is_vararg = flags.is_vararg,
            .is_virtual = false,
            .arguments = arguments,
            .return_value = return_value,
        },
        ctx,
    );
    allocator.free(legacy.name);
    legacy.name = try std.fmt.allocPrint(allocator, "{s}_legacy", .{group.adapter});
    legacy.legacy_range = group;
    legacy.doc = try std.fmt.allocPrint(
        allocator,
        "Old layout of `{s}.{s}`; use `{s}` for the modern layout.\n" ++
            "Valid only on Godot [{d}.{d}.{d}, {d}.{d}.{d}).\n{s}",
        .{
            modern.base.?,
            modern.name_api,
            modern.name,
            group.lower.major,
            group.lower.minor,
            group.lower.patch,
            group.upper.major,
            group.upper.minor,
            group.upper.patch,
            notes.items,
        },
    );
    return legacy;
}

fn mapEnum(
    allocator: Allocator,
    name: []const u8,
    ctx: *const Context,
    notes: *std.ArrayList(u8),
) ![]const u8 {
    const prefix: usize = if (std.mem.startsWith(u8, name, "enum::"))
        6
    else if (std.mem.startsWith(u8, name, "bitfield::"))
        10
    else
        return name;
    if (ctx.symbol_lookup.contains(name[prefix..])) return name;
    try notes.print(allocator, "Old enum `{s}` is absent from the current API; represented as `i64`.\n", .{
        name[prefix..],
    });
    return "int";
}

test "legacy signatures retain positional old types flags hash and range" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const ctx: Context = .{
        .arena = &arena,
        .api = undefined,
        .config = undefined,
        .metadata = compatibility.manifest,
    };
    const modern: Context.Function = .{
        .name = "probe",
        .name_api = "probe",
        .base = "Probe",
        .hash = 222,
        .return_type = .{ .basic = "bool" },
    };
    const signature: manifest.Legacy = .{
        .difference = "void -> bool",
        .arguments = &.{.{
            .name = "name",
            .type = "String",
            .has_default = true,
        }},
        .@"return" = null,
        .flags = .{
            .is_const = true,
            .is_static = false,
            .is_vararg = false,
        },
    };
    const group: version_dispatch.Group = .{
        .lower = Version.parse("4.6.0"),
        .upper = Version.parse("4.7.0"),
        .old_hash = 111,
        .layout = .return_added,
        .adapter = "probe_4_6",
        .available = false,
        .signature = signature,
    };
    const legacy = try build(allocator, modern, group, &ctx);
    try std.testing.expectEqualStrings("probe_4_6_legacy", legacy.name);
    try std.testing.expectEqual(@as(?u64, 111), legacy.hash);
    try std.testing.expectEqual(@as(usize, 1), legacy.parameters.count());
    try std.testing.expect(legacy.parameters.values()[0].type == .string);
    try std.testing.expect(legacy.parameters.values()[0].default == null);
    try std.testing.expect(legacy.return_type == .void);
    try std.testing.expect(legacy.self == .constant);
    try std.testing.expectEqual(@as(usize, 0), legacy.hash_compatibility.items.len);
    try std.testing.expect(legacy.legacy_range.?.lower.range(.@"4.6", .@"4.7"));
    try std.testing.expect(std.mem.indexOf(u8, legacy.doc.?, "[4.6.0, 4.7.0)") != null);
}

test "missing old enums become i64 while existing enum names retain normal mapping" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    var ctx: Context = .{
        .arena = &arena,
        .api = undefined,
        .config = undefined,
        .metadata = compatibility.manifest,
    };
    try ctx.symbol_lookup.put(arena.allocator(), "Probe.Mode", .{
        .path = "Probe.Mode",
        .label = "Probe.Mode",
    });
    var notes: std.ArrayList(u8) = .empty;
    defer notes.deinit(arena.allocator());
    try std.testing.expectEqualStrings(
        "enum::Probe.Mode",
        try mapEnum(arena.allocator(), "enum::Probe.Mode", &ctx, &notes),
    );
    try std.testing.expectEqualStrings(
        "int",
        try mapEnum(arena.allocator(), "enum::Gone.Mode", &ctx, &notes),
    );
    try std.testing.expect(std.mem.indexOf(u8, notes.items, "represented as `i64`") != null);
    const mapped = try Context.Type.from(arena.allocator(), "int", false, &ctx);
    try std.testing.expectEqualStrings("i64", mapped.int);
}

test "missing enum argument and return signatures use i64 regardless of old metadata" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const ctx: Context = .{
        .arena = &arena,
        .api = undefined,
        .config = undefined,
        .metadata = compatibility.manifest,
    };
    const function: Context.Function = .{
        .name = "probe",
        .name_api = "probe",
        .base = "Probe",
    };
    const group: version_dispatch.Group = .{
        .lower = .@"4.6",
        .upper = .@"4.7",
        .old_hash = 111,
        .layout = .incompatible,
        .adapter = "probe_4_6",
        .available = false,
        .signature = .{
            .difference = "fixture",
            .arguments = &.{.{
                .name = "mode",
                .type = "bitfield::Gone.Flags",
                .meta = "int32",
            }},
            .@"return" = .{ .type = "enum::Gone.Mode", .meta = "int32" },
            .flags = .{
                .is_const = false,
                .is_static = true,
                .is_vararg = false,
            },
        },
    };
    const legacy = try build(arena.allocator(), function, group, &ctx);
    try std.testing.expectEqualStrings("i64", legacy.parameters.values()[0].type.int);
    try std.testing.expectEqualStrings("i64", legacy.return_type.int);
    try std.testing.expect(std.mem.indexOf(u8, legacy.doc.?, "Gone.Flags") != null);
    try std.testing.expect(std.mem.indexOf(u8, legacy.doc.?, "Gone.Mode") != null);
    try std.testing.expect(legacy.self == .static);
}

const std = @import("std");
const Allocator = std.mem.Allocator;

const Version = @import("common").Version;
const GodotApi = @import("common").GodotApi;
const Context = @import("Context.zig");
const manifest = @import("compat").manifest;
const compatibility = @import("compatibility.zig");
const version_dispatch = @import("version_dispatch.zig");
