pub const Type = union(enum) {
    void: void,

    /// Integer types (i8, i16, i32, i64, u8, u16, u32, u64)
    int: []const u8,
    /// Floating point types (f32, f64)
    float: []const u8,
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
        .{ "char32", Type{ .int = "u32" } },
        .{ "f32", Type{ .float = "f32" } },
        .{ "f64", Type{ .float = "f64" } },
        .{ "float", Type{ .float = "f64" } },
        .{ "double", Type{ .float = "f64" } },
        .{ "i8", Type{ .int = "i8" } },
        .{ "i16", Type{ .int = "i16" } },
        .{ "i32", Type{ .int = "i32" } },
        .{ "i64", Type{ .int = "i64" } },
        .{ "u8", Type{ .int = "u8" } },
        .{ "u16", Type{ .int = "u16" } },
        .{ "u32", Type{ .int = "u32" } },
        .{ "u64", Type{ .int = "u64" } },
        .{ "int", Type{ .int = "i64" } },
        .{ "int8", Type{ .int = "i8" } },
        .{ "int16", Type{ .int = "i16" } },
        .{ "int32", Type{ .int = "i32" } },
        .{ "int64", Type{ .int = "i64" } },
        .{ "uint8_t", Type{ .int = "u8" } },
        .{ "uint8", Type{ .int = "u8" } },
        .{ "uint16", Type{ .int = "u16" } },
        .{ "uint32", Type{ .int = "u32" } },
        .{ "uint64", Type{ .int = "u64" } },
    });

    // TODO: may no longer be needed
    const meta_overrides: std.StaticStringMap(Type) = .initComptime(.{});

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
            inline .int,
            .float,
            .basic,
            .class,
            .@"enum",
            .flag,
            .@"union",
            => |name| allocator.free(name),
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
            inline .int,
            .float,
            .basic,
            .class,
            .@"enum",
            .flag,
            => |name| try writer.writeAll(name),
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
            .@"enum", .flag, .int, .float, .basic, .class => |name| switch (other) {
                .@"enum" => |other_name| std.mem.eql(u8, name, other_name),
                .flag => |other_name| std.mem.eql(u8, name, other_name),
                .int => |other_name| std.mem.eql(u8, name, other_name),
                .float => |other_name| std.mem.eql(u8, name, other_name),
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

    /// Checks if two types are approximately equal, allowing numeric conversions
    /// within the same category (int-to-int or float-to-float).
    /// This enables comptime initialization for constructors like Vector2i.initXY(i64, i64)
    /// where the struct has i32 fields.
    pub fn approxEql(self: Type, other: Type) bool {
        // First check exact equality
        if (self.eql(other)) return true;

        // Allow conversions between any integer types
        if (self == .int and other == .int) return true;

        // Allow conversions between any float types
        if (self == .float and other == .float) return true;

        return false;
    }

    /// Returns the name of the Zig cast operator (@intCast or @floatCast) for this type,
    /// or null if no cast is needed. Used in code generation to emit type casts for
    /// constructor parameter initialization.
    pub fn castFunction(self: Type) ?[]const u8 {
        return switch (self) {
            .int => "@intCast",
            .float => "@floatCast",
            else => null,
        };
    }

    pub fn getName(self: Type) ?[]const u8 {
        return switch (self) {
            inline .int, .float, .basic, .class, .@"enum", .flag => |name| name,
            .@"union" => std.debug.panic("Can't get name for union type", .{}),
            .array => |array| {
                if (array) |arr| {
                    return arr.getName();
                }
                return null;
            },
            .void => "void",
            .string => "String",
            .node_path => "NodePath",
            .string_name => "StringName",
            .variant => "Variant",
            .pointer => |t| t.getName(),
        };
    }

    /// Returns the default initializer expression for this type when used as a return value.
    /// Returns null if no default initializer is defined.
    ///
    /// Note: Do not use for constructors.
    pub fn getDefaultInitializer(self: Type, ctx: *const Context) ?[]const u8 {
        return switch (self) {
            // String and StringName always use .init() since they require runtime initialization
            .string, .string_name => ".init()",

            .int => |type_name| {
                // Map for integer types
                const int_init_map = std.StaticStringMap([]const u8).initComptime(.{
                    .{ "i8", "0" },
                    .{ "i16", "0" },
                    .{ "i32", "0" },
                    .{ "i64", "0" },
                    .{ "u8", "0" },
                    .{ "u16", "0" },
                    .{ "u32", "0" },
                    .{ "u64", "0" },
                });
                return int_init_map.get(type_name);
            },

            .float => |type_name| {
                // Map for float types
                const float_init_map = std.StaticStringMap([]const u8).initComptime(.{
                    .{ "f32", "0.0" },
                    .{ "f64", "0.0" },
                });
                return float_init_map.get(type_name);
            },

            .basic => |type_name| {
                // Static map for well-known builtin types with specific initializers
                const builtin_init_map = std.StaticStringMap([]const u8).initComptime(.{
                    .{ "Vector2", ".zero" },
                    .{ "Vector3", ".zero" },
                    .{ "Vector4", ".zero" },
                    .{ "Vector2i", ".zero" },
                    .{ "Vector3i", ".zero" },
                    .{ "Vector4i", ".zero" },
                    .{ "Basis", ".identity" },
                    .{ "Transform2D", ".identity" },
                    .{ "Transform3D", ".identity" },
                    .{ "Projection", ".identity" },
                    .{ "bool", "false" },
                });

                // Check static map first
                if (builtin_init_map.get(type_name)) |initializer| {
                    return initializer;
                }

                // Check if this builtin type has an 'init' constant in its mixin
                // Note: constants are stored with name_api keys (e.g., "INIT" not "init")
                if (ctx.builtins.get(type_name)) |builtin| {
                    if (builtin.constants.contains("INIT")) {
                        return ".init"; // Use constant reference
                    }
                }

                // Default: assume it's a function call
                return ".init()";
            },

            .variant => ".nil",
            .void => "undefined",

            // Other types don't have default initializers
            else => null,
        };
    }

    /// Returns true if wrapping this type in a Variant requires heap allocation.
    /// Packed arrays use a refcounted wrapper (PackedArrayRef) that cannot be stack-allocated
    /// safely, as Godot may copy the Variant and hold a reference to the wrapper.
    /// Note: This must stay in sync with Variant.Tag.allocates() in the runtime.
    pub fn allocatesAsVariant(self: Type, ctx: *const Context) bool {
        _ = ctx;
        const name = switch (self) {
            .basic => |n| n,
            else => return false,
        };
        return std.mem.startsWith(u8, name, "Packed");
    }
};

const std = @import("std");
const Allocator = mem.Allocator;
const mem = std.mem;

const Context = @import("../Context.zig");
