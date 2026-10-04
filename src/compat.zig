//! Compatibility shims for Zig APIs that changed shape between the pinned
//! stable release and zig master. See docs/adr/0001-zig-version-compat.md.
//!
//! Gates probe API *shape* (comptime `@hasDecl`/`@hasField`), not version
//! numbers, so they keep working across future releases until the old-shape
//! branch is deleted. Discover all gates with:
//! `git grep -E "comptime !?@has(Decl|Field)"`.

const std = @import("std");

/// Uniform view of a struct field: name and type.
pub const StructField = struct {
    name: [:0]const u8,
    type: type,
};

/// Struct fields of `T` as `{ name, type }` pairs.
pub inline fn structFields(comptime T: type) []const StructField {
    return comptime blk: {
        const info = @typeInfo(T).@"struct";
        var result: [info.field_names.len]StructField = undefined;
        for (info.field_names, info.field_types, 0..) |name, field_type, i| {
            result[i] = .{ .name = name, .type = field_type };
        }
        const final = result;
        break :blk &final;
    };
}

/// Uniform view of an enum field: name and value.
pub const EnumField = struct {
    name: [:0]const u8,
    value: comptime_int,
};

/// Enum fields of `T` as `{ name, value }` pairs.
pub inline fn enumFields(comptime T: type) []const EnumField {
    return comptime blk: {
        const info = @typeInfo(T).@"enum";
        var result: [info.field_names.len]EnumField = undefined;
        for (info.field_names, info.field_values, 0..) |name, value, i| {
            result[i] = .{ .name = name, .value = value };
        }
        const final = result;
        break :blk &final;
    };
}
