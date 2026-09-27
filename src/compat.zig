//! Compatibility shims for Zig APIs that changed shape between the pinned
//! stable release and zig master. See docs/adr/0001-zig-version-compat.md.
//!
//! Gates probe API *shape* (comptime `@hasDecl`/`@hasField`), not version
//! numbers, so they keep working across future releases until the old-shape
//! branch is deleted. `zig_016` is reserved for language-rule changes that
//! have no API shape to probe. Discover all gates with:
//! `git grep -E "comptime !?@has(Decl|Field)"`.
//!
// TODO(zig 0.16.0): when 0.16.x support is dropped, delete the old-shape
// branches; each helper reduces to the other branch's plain std call.

const std = @import("std");
const builtin = @import("builtin");

/// Whether the current compiler is a 0.16.x release. Only for gates with
/// no API shape to probe (language rule changes).
pub const zig_016 = builtin.zig_version.major == 0 and builtin.zig_version.minor == 16;

/// Uniform view of a struct field: name and type.
pub const StructField = struct {
    name: [:0]const u8,
    type: type,
};

/// Struct fields of `T` as `{ name, type }` pairs.
pub inline fn structFields(comptime T: type) []const StructField {
    if (comptime @hasField(std.builtin.Type.Struct, "field_names")) {
        // New shape: parallel field_names / field_types arrays.
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
    // Old shape: []StructField.
    return comptime blk: {
        const fields = @typeInfo(T).@"struct".fields;
        var result: [fields.len]StructField = undefined;
        for (fields, 0..) |field, i| {
            result[i] = .{ .name = field.name, .type = field.type };
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
    if (comptime @hasField(std.builtin.Type.Enum, "field_names")) {
        // New shape: parallel field_names / field_values arrays.
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
    // Old shape: []EnumField.
    return comptime blk: {
        const fields = @typeInfo(T).@"enum".fields;
        var result: [fields.len]EnumField = undefined;
        for (fields, 0..) |field, i| {
            result[i] = .{ .name = field.name, .value = field.value };
        }
        const final = result;
        break :blk &final;
    };
}

/// Declaration names of `T`, public and private.
pub inline fn declNames(comptime T: type) []const [:0]const u8 {
    if (comptime !@hasDecl(std.builtin.Type, "Declaration")) {
        // New shape: std.meta.declarations returns names only.
        return std.meta.declarations(T);
    }
    // Old shape: []Type.Declaration structs with `.name`.
    return comptime blk: {
        const decls = std.meta.declarations(T);
        var names: [decls.len][:0]const u8 = undefined;
        for (decls, 0..) |decl, i| {
            names[i] = decl.name;
        }
        const final = names;
        break :blk &final;
    };
}

/// Function parameter types of the function type `T` (`null` for `anytype`
/// or generic parameters).
pub inline fn fnParamTypes(comptime T: type) []const ?type {
    if (comptime @hasField(std.builtin.Type.Fn, "param_types")) {
        // New shape: param_types array, parameter names dropped.
        return @typeInfo(T).@"fn".param_types;
    }
    // Old shape: []FnParam with `.type`.
    return comptime blk: {
        const params = @typeInfo(T).@"fn".params;
        var result: [params.len]?type = undefined;
        for (params, 0..) |param, i| {
            result[i] = param.type;
        }
        const final = result;
        break :blk &final;
    };
}
