pub const Type = union(enum) {
    void: void,

    /// Basic types with no special handling
    basic: []const u8,
    /// Godot Strings, used for string coercion
    string: void,
    /// Godot StringNames, used for string coercion
    string_name: void,
    /// Godot NodePaths, used for string coercion
    node_path: void,
    /// Godot Variants, used for dynamic typing
    variant: void,
    /// A class type, used for polymorphic parameters
    class: []const u8,
    /// Some properties accept more than one type, like "ParticleProcessMaterial,ShaderMaterial"
    many: []Type,

    const string_map: std.StaticStringMap(Type) = .initComptime(.{
        .{ "String", .string },
        .{ "StringName", .string_name },
        .{ "NodePath", .node_path },
        .{ "Variant", .variant },
        .{ "float", Type{ .basic = "f64" } },
        .{ "double", Type{ .basic = "f64" } },
        .{ "char32", Type{ .basic = "u32" } },
        .{ "float", Type{ .basic = "f32" } },
        .{ "double", Type{ .basic = "f64" } },
        .{ "int", Type{ .basic = "i64" } },
        .{ "int8", Type{ .basic = "i8" } },
        .{ "int16", Type{ .basic = "i16" } },
        .{ "int32", Type{ .basic = "i32" } },
        .{ "int64", Type{ .basic = "i64" } },
        .{ "uint8", Type{ .basic = "u8" } },
        .{ "uint16", Type{ .basic = "u16" } },
        .{ "uint32", Type{ .basic = "u32" } },
        .{ "uint64", Type{ .basic = "u64" } },
    });

    const meta_overrides: std.StaticStringMap(Type) = .initComptime(.{
        .{ "float", Type{ .basic = "f32" } },
    });

    pub fn from(allocator: Allocator, name: []const u8, is_meta: bool, ctx: *const Context) !Type {
        const n = mem.count(u8, name, ",");
        if (n > 0) {
            const types = try allocator.alloc(Type, n);
            // TODO: allocate list and generate
            return .{ .many = types };
        }

        if (is_meta) {
            if (meta_overrides.get(name)) |@"type"| {
                return @"type";
            }
        }
        if (string_map.get(name)) |@"type"| {
            return @"type";
        }

        if (ctx.isClass(name)) {
            return .{
                .class = try allocator.dupe(u8, name),
            };
        }

        return .{
            .basic = try allocator.dupe(u8, name),
        };
    }

    pub fn deinit(self: *Type, allocator: Allocator) void {
        switch (self.*) {
            .basic => |name| {
                allocator.free(name);
            },
            .class => |name| {
                allocator.free(name);
            },
            .many => |types| {
                allocator.free(types);
            },
            else => {},
        }

        self.* = .void;
    }
};

const std = @import("std");
const Allocator = mem.Allocator;
const mem = std.mem;

const precision = @import("build_options").precision;

const Context = @import("../Context.zig");
