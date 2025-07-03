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
    @"enum": []const u8,
    flag: []const u8,
    array: ?*Type,
    pointer: *Type,

    /// A type union - some properties accept more than one type, like "ParticleProcessMaterial,ShaderMaterial"
    @"union": []Type,

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
        .{ "uint8_t", Type{ .basic = "u8" } },
        .{ "uint8", Type{ .basic = "u8" } },
        .{ "uint16", Type{ .basic = "u16" } },
        .{ "uint32", Type{ .basic = "u32" } },
        .{ "uint64", Type{ .basic = "u64" } },
    });

    const meta_overrides: std.StaticStringMap(Type) = .initComptime(.{
        .{ "float", Type{ .basic = "f32" } },
    });

    pub fn from(allocator: Allocator, name: []const u8, is_meta: bool, ctx: *const Context) !Type {
        var normalized = name;

        const n = mem.count(u8, normalized, ",");
        if (n > 0) {
            const types = try allocator.alloc(Type, n);
            // TODO: allocate list and generate
            return .{ .@"union" = types };
        }

        if (is_meta) {
            if (meta_overrides.get(normalized)) |@"type"| {
                return @"type";
            }
        }
        if (string_map.get(normalized)) |@"type"| {
            return @"type";
        }

        var parts = std.mem.splitSequence(u8, normalized, "::");
        if (parts.next()) |k| {
            if (std.mem.eql(u8, "bitfield", k)) {
                return .{
                    .flag = try allocator.dupe(u8, parts.next().?),
                };
            }
            if (std.mem.eql(u8, "enum", k)) {
                return .{
                    .@"enum" = try allocator.dupe(u8, parts.next().?),
                };
            }
            if (std.mem.eql(u8, "typedarray", k)) {
                const elem = try allocator.create(Type);
                elem.* = try Type.from(allocator, parts.next().?, false, ctx);
                return .{
                    .array = elem,
                };
            }
        }

        if (std.mem.startsWith(u8, normalized, "const ")) {
            normalized = normalized[6..];
        }

        if (normalized[normalized.len - 1] == '*') {
            const child = try allocator.create(Type);
            child.* = try Type.from(allocator, normalized[0 .. normalized.len - 1], false, ctx);
            return .{
                .pointer = child,
            };
        }

        if (std.mem.eql(u8, "Array", normalized)) {
            return .{
                .array = null,
            };
        }

        if (ctx.isClass(normalized)) {
            return .{
                .class = try allocator.dupe(u8, normalized),
            };
        }

        return .{
            .basic = try allocator.dupe(u8, normalized),
        };
    }

    pub fn deinit(self: *Type, allocator: Allocator) void {
        switch (self.*) {
            .array => |elem| if (elem) |t| t.deinit(allocator),
            .basic => |name| allocator.free(name),
            .class => |name| allocator.free(name),
            .@"enum" => |name| allocator.free(name),
            .flag => |name| allocator.free(name),
            .@"union" => |types| allocator.free(types),
            else => {},
        }

        self.* = .void;
    }

    pub fn format(self: Type, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        switch (self) {
            .array => |elem| if (elem) |t| {
                try writer.writeAll("[");
                try t.format(fmt, options, writer);
                try writer.writeAll("]");
            },
            .basic => |name| try writer.writeAll(name),
            .class => |name| try writer.writeAll(name),
            .@"enum" => |name| try writer.writeAll(name),
            .flag => |name| try writer.writeAll(name),
            .@"union" => |types| {
                try writer.writeAll("union(");
                for (types, 0..) |t, i| {
                    if (i > 0) try writer.writeAll(", ");
                    try t.format(fmt, options, writer);
                }
                try writer.writeAll(")");
            },
            .void => try writer.writeAll("void"),
            .string => try writer.writeAll("string"),
            .node_path => try writer.writeAll("node_path"),
            .string_name => try writer.writeAll("string_name"),
            .variant => try writer.writeAll("variant"),
            .pointer => |t| {
                try writer.writeAll("pointer(");
                try t.format(fmt, options, writer);
                try writer.writeAll(")");
            },
        }
    }

    pub fn eql(self: Type, other: Type) bool {
        return switch (self) {
            .@"enum", .flag, .basic, .class => |name| switch (other) {
                .@"enum" => |other_name| std.mem.eql(u8, name, other_name),
                .flag => |other_name| std.mem.eql(u8, name, other_name),
                .basic => |other_name| std.mem.eql(u8, name, other_name),
                .class => |other_name| std.mem.eql(u8, name, other_name),
                else => false,
            },
            .@"union" => |types| switch (other) {
                .@"union" => |other_types| {
                    if (types.len != other_types.len) return false;

                    for (types, other_types) |t, ot| {
                        if (!t.eql(ot)) return false;
                    }

                    return true;
                },
                else => false,
            },
            .array => @panic("type.eql for array type not implemented"),
            .void => switch (other) {
                .void => true,
                else => false,
            },
            .string => switch (other) {
                .string => true,
                else => false,
            },
            .node_path => switch (other) {
                .node_path => true,
                else => false,
            },
            .string_name => switch (other) {
                .string_name => true,
                else => false,
            },
            .variant => switch (other) {
                .variant => true,
                else => false,
            },
            .pointer => |t| switch (other) {
                .pointer => |other_t| t.eql(other_t.*),
                else => false,
            },
        };
    }
};

const std = @import("std");
const Allocator = mem.Allocator;
const mem = std.mem;

const Context = @import("../Context.zig");
