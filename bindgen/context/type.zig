pub const Type = union(enum) {
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

    const special_types: std.StaticStringMap(Type) = .initComptime(.{
        .{ "String", .string },
        .{ "StringName", .string_name },
        .{ "NodePath", .node_path },
        .{ "Variant", .variant },
    });

    pub fn from(allocator: Allocator, name: []const u8, ctx: *const Context) !Type {
        const n = mem.count(u8, name, ",");
        if (n > 0) {
            const types = try allocator.alloc(Type, n);
            // TODO: allocate list and generate
            return .{ .many = types };
        }

        if (special_types.get(name)) |@"type"| {
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

    pub fn deinit(self: Type, allocator: Allocator) void {
        switch (self) {
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
    }
};

const std = @import("std");
const Allocator = mem.Allocator;
const mem = std.mem;

const Context = @import("../Context.zig");
