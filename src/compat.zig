//! Compatibility shims for Zig compiler introspection APIs that changed
//! shape between Zig 0.16.0 and zig master (0.17).
//!
//! Call sites import this module directly, so no per-site markers are
//! needed: deleting or changing a helper here surfaces as a build error at
//! every call site when 0.16.x support is dropped.
//!
// TODO(zig 0.16.0): delete this entire module when 0.16.x support is
// dropped; each helper's `else` branch is the plain 0.17+ std call.

const std = @import("std");
const builtin = @import("builtin");

/// Whether the current compiler is a 0.16.x release.
pub const zig_016 = builtin.zig_version.major == 0 and builtin.zig_version.minor == 16;

/// Uniform view of a struct field: name and type.
pub const StructField = struct {
    name: [:0]const u8,
    type: type,
};

/// Struct fields of `T` as `{ name, type }` pairs.
pub inline fn structFields(comptime T: type) []const StructField {
    if (comptime zig_016) {
        return comptime blk: {
            const fields = @typeInfo(T).@"struct".fields;
            var result: [fields.len]StructField = undefined;
            for (fields, 0..) |field, i| {
                result[i] = .{ .name = field.name, .type = field.type };
            }
            const final = result;
            break :blk &final;
        };
    } else {
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
}

/// Uniform view of an enum field: name and value.
pub const EnumField = struct {
    name: [:0]const u8,
    value: comptime_int,
};

/// Enum fields of `T` as `{ name, value }` pairs.
pub inline fn enumFields(comptime T: type) []const EnumField {
    if (comptime zig_016) {
        return comptime blk: {
            const fields = @typeInfo(T).@"enum".fields;
            var result: [fields.len]EnumField = undefined;
            for (fields, 0..) |field, i| {
                result[i] = .{ .name = field.name, .value = field.value };
            }
            const final = result;
            break :blk &final;
        };
    } else {
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
}

/// Declaration names of `T`, public and private.
pub inline fn declNames(comptime T: type) []const [:0]const u8 {
    if (comptime zig_016) {
        return comptime blk: {
            const decls = std.meta.declarations(T);
            var names: [decls.len][:0]const u8 = undefined;
            for (decls, 0..) |decl, i| {
                names[i] = decl.name;
            }
            const final = names;
            break :blk &final;
        };
    } else {
        return std.meta.declarations(T);
    }
}

/// Function parameter types of the function type `T` (`null` for `anytype`
/// or generic parameters).
pub inline fn fnParamTypes(comptime T: type) []const ?type {
    if (comptime zig_016) {
        return comptime blk: {
            const params = @typeInfo(T).@"fn".params;
            var result: [params.len]?type = undefined;
            for (params, 0..) |param, i| {
                result[i] = param.type;
            }
            const final = result;
            break :blk &final;
        };
    } else {
        return @typeInfo(T).@"fn".param_types;
    }
}
