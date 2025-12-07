const std = @import("std");
const godot = @import("gdzig.zig");

const String = godot.builtin.String;
const StringName = godot.builtin.StringName;
const Variant = godot.builtin.Variant;
const PropertyHint = godot.global.PropertyHint;
const PropertyUsageFlags = godot.global.PropertyUsageFlags;
const heap = godot.heap;
const c = godot.c;

pub const Export = union(enum) {
    const Field = @TypeOf(.enum_literal);

    property: struct {
        field: Field,
        hint: []const u8 = "",
    },

    range: struct {
        field: Field,
        min: f64,
        max: f64,
        step: ?f64 = null,
        extra_hints: []const []const u8 = &[_][]const u8{},
    },

    exp_easing: struct {
        field: Field,
    },

    @"enum": struct {
        field: Field,
        options: []const []const u8,
    },

    flags: struct {
        field: Field,
        options: []const []const u8,
    },

    flags_2d_physics: struct { field: Field },

    flags_2d_render: struct { field: Field },

    flags_2d_navigation: struct { field: Field },

    flags_3d_physics: struct { field: Field },

    flags_3d_render: struct { field: Field },

    flags_3d_navigation: struct { field: Field },

    file: struct {
        field: Field,
        filter: []const u8 = "",
    },

    dir: struct {
        field: Field,
    },

    global_file: struct {
        field: Field,
        filter: []const u8 = "",
    },

    global_dir: struct {
        field: Field,
    },

    multiline: struct {
        field: Field,
    },

    placeholder: struct {
        field: Field,
        placeholder_text: []const u8,
    },

    color_no_alpha: struct {
        field: Field,
    },

    node_path: struct {
        field: Field,
        valid_types: []const []const u8 = &[_][]const u8{},
    },

    storage: struct {
        field: Field,
    },

    tool_button: struct {
        field: Field,
        label: []const u8,
        icon: []const u8 = "Callable",
    },

    custom: struct {
        field: Field,
        hint: PropertyHint,
        hint_string: []const u8 = "",
        usage: ?PropertyUsageFlags = null,
    },

    group: struct {
        name: [:0]const u8,
        prefix: [:0]const u8 = "",
    },

    subgroup: struct {
        name: [:0]const u8,
        prefix: [:0]const u8 = "",
    },

    category: struct {
        name: [:0]const u8,
    },

    fn isFieldExport(self: Export) bool {
        return switch (self) {
            .group, .subgroup, .category => false,
            else => true,
        };
    }

    fn getFieldName(self: Export) ?[:0]const u8 {
        return switch (self) {
            .group, .subgroup, .category => null,
            inline else => |v| @tagName(v.field),
        };
    }

    fn getGroupName(self: Export) ?[:0]const u8 {
        return switch (self) {
            inline .group, .subgroup, .category => |v| v.name,
            else => null,
        };
    }

    fn getPropertyHint(self: Export) struct { hint: PropertyHint, hint_string: [:0]const u8 } {
        return switch (self) {
            .property => |v| .{
                .hint = .property_hint_placeholder_text,
                .hint_string = v.hint ++ "",
            },
            .range => |v| .{
                .hint = .property_hint_range,
                .hint_string = std.fmt.comptimePrint("{d},{d}", .{ v.min, v.max }) ++
                    (if (v.step) |s| std.fmt.comptimePrint(",{d}", .{s}) else "") ++
                    generateHint(v.extra_hints, true),
            },
            .exp_easing => .{ .hint = .property_hint_exp_easing, .hint_string = "" },
            .@"enum" => |v| .{
                .hint = .property_hint_enum,
                .hint_string = generateHint(v.options, false),
            },
            .flags => |v| .{
                .hint = .property_hint_flags,
                .hint_string = generateHint(v.options, false),
            },
            .flags_2d_physics => .{ .hint = .property_hint_layers_2_d_physics, .hint_string = "" },
            .flags_2d_render => .{ .hint = .property_hint_layers_2_d_render, .hint_string = "" },
            .flags_2d_navigation => .{ .hint = .property_hint_layers_2_d_navigation, .hint_string = "" },
            .flags_3d_physics => .{ .hint = .property_hint_layers_3_d_physics, .hint_string = "" },
            .flags_3d_render => .{ .hint = .property_hint_layers_3_d_render, .hint_string = "" },
            .flags_3d_navigation => .{ .hint = .property_hint_layers_3_d_navigation, .hint_string = "" },
            .file => |v| .{
                .hint = .property_hint_file,
                .hint_string = v.filter ++ "",
            },
            .dir => .{ .hint = .property_hint_dir, .hint_string = "" },
            .global_file => |v| .{
                .hint = .property_hint_global_file,
                .hint_string = v.filter ++ "",
            },
            .global_dir => .{ .hint = .property_hint_global_dir, .hint_string = "" },
            .multiline => .{ .hint = .property_hint_multiline_text, .hint_string = "" },
            .placeholder => |v| .{
                .hint = .property_hint_placeholder_text,
                .hint_string = v.placeholder_text ++ "",
            },
            .color_no_alpha => .{ .hint = .property_hint_color_no_alpha, .hint_string = "" },
            .node_path => |v| .{
                .hint = .property_hint_node_path_valid_types,
                .hint_string = generateHint(v.valid_types, false),
            },
            .storage => .{ .hint = .property_hint_none, .hint_string = "" },
            .tool_button => @compileError("tool_button export is not yet implemented"),
            .custom => |v| .{
                .hint = v.hint,
                .hint_string = v.hint_string ++ "",
            },
            .group, .subgroup, .category => .{
                .hint = .property_hint_none,
                .hint_string = "",
            },
        };
    }

    fn getPropertyUsage(self: Export) PropertyUsageFlags {
        return switch (self) {
            .storage => .{ .property_usage_storage = true },
            .group => .{ .property_usage_group = true },
            .subgroup => .{ .property_usage_subgroup = true },
            .category => .{ .property_usage_category = true },
            .custom => |v| v.usage orelse PropertyUsageFlags.property_usage_default,
            else => PropertyUsageFlags.property_usage_default,
        };
    }

    fn generateHint(comptime strings: []const []const u8, comptime prefix_comma: bool) [:0]const u8 {
        comptime var result: []const u8 = "";
        inline for (strings, 0..) |s, i| {
            if (i > 0 or prefix_comma) result = result ++ ",";
            result = result ++ s;
        }
        return result ++ "";
    }
};

fn validateExports(comptime T: type) void {
    if (!@hasDecl(T, "__exports")) {
        @compileError("Type must have '__exports' declaration");
    }

    inline for (T.__exports) |entry| {
        if (entry.isFieldExport()) {
            const field_name = entry.getFieldName().?;
            if (!@hasField(T, field_name)) {
                @compileError("Export references non-existent field '" ++ field_name ++ "'");
            }
        }
    }
}

pub fn hasExports(comptime T: type) bool {
    return @hasDecl(T, "__exports");
}

fn countProperties(comptime T: type) usize {
    if (!hasExports(T)) return 0;
    return T.__exports.len;
}

pub fn generateGetPropertyListBind(comptime T: type) fn (c.GDExtensionClassInstancePtr, [*c]u32) callconv(.c) [*c]const c.GDExtensionPropertyInfo {
    comptime validateExports(T);

    return struct {
        pub fn func(p_instance: c.GDExtensionClassInstancePtr, r_count: [*c]u32) callconv(.c) [*c]const c.GDExtensionPropertyInfo {
            _ = p_instance;

            const property_count = comptime countProperties(T);

            const properties = heap.general_allocator.alloc(c.GDExtensionPropertyInfo, property_count) catch {
                if (r_count) |r| r.* = 0;
                return null;
            };

            comptime var idx: usize = 0;
            inline for (T.__exports) |entry| {
                if (comptime entry.isFieldExport()) {
                    const field_name = comptime entry.getFieldName().?;
                    const hint_info = comptime entry.getPropertyHint();
                    const usage = comptime entry.getPropertyUsage();

                    const name_ptr = heap.general_allocator.create(StringName) catch @panic("OOM");
                    name_ptr.* = StringName.fromComptimeLatin1(field_name);

                    const hint_ptr = heap.general_allocator.create(String) catch @panic("OOM");
                    hint_ptr.* = String.fromLatin1(hint_info.hint_string);

                    properties[idx] = .{
                        .type = @intFromEnum(Variant.Tag.forType(@FieldType(T, field_name))),
                        .name = @ptrCast(name_ptr),
                        .class_name = @ptrCast(godot.typeName(T)),
                        .hint = @intFromEnum(hint_info.hint),
                        .hint_string = @ptrCast(hint_ptr),
                        .usage = @bitCast(usage),
                    };
                } else {
                    const group_name = comptime entry.getGroupName().?;
                    const usage = comptime entry.getPropertyUsage();

                    const name_ptr = heap.general_allocator.create(StringName) catch @panic("OOM");
                    name_ptr.* = StringName.fromComptimeLatin1(group_name);

                    const hint_ptr = heap.general_allocator.create(String) catch @panic("OOM");
                    hint_ptr.* = String.init();

                    properties[idx] = .{
                        .type = @intFromEnum(Variant.Tag.nil),
                        .name = @ptrCast(name_ptr),
                        .class_name = @ptrCast(@constCast(&StringName.empty())),
                        .hint = @intFromEnum(PropertyHint.property_hint_none),
                        .hint_string = @ptrCast(hint_ptr),
                        .usage = @bitCast(usage),
                    };
                }
                idx += 1;
            }

            r_count.* = @intCast(property_count);
            return @ptrCast(properties.ptr);
        }
    }.func;
}

pub fn generateSetBind(comptime T: type) fn (c.GDExtensionClassInstancePtr, c.GDExtensionConstStringNamePtr, c.GDExtensionConstVariantPtr) callconv(.c) c.GDExtensionBool {
    comptime validateExports(T);

    return struct {
        pub fn func(p_instance: c.GDExtensionClassInstancePtr, name: c.GDExtensionConstStringNamePtr, value: c.GDExtensionConstVariantPtr) callconv(.c) c.GDExtensionBool {
            if (p_instance == null) return 0;

            const self: *T = @ptrCast(@alignCast(p_instance));
            const prop_name = @as(*StringName, @ptrCast(@constCast(name))).*;
            const prop_value = @as(*Variant, @ptrCast(@alignCast(@constCast(value)))).*;

            inline for (T.__exports) |entry| {
                if (comptime entry.isFieldExport()) {
                    const field_name = comptime entry.getFieldName().?;

                    var field_str = String.fromLatin1(field_name);
                    defer field_str.deinit();

                    if (prop_name.casecmpTo(field_str) == 0) {
                        const FieldType = @FieldType(T, field_name);
                        if (prop_value.as(FieldType)) |v| {
                            @field(self, field_name) = v;
                            return 1;
                        }
                    }
                }
            }
            return 0;
        }
    }.func;
}

pub fn generateGetBind(comptime T: type) fn (c.GDExtensionClassInstancePtr, c.GDExtensionConstStringNamePtr, c.GDExtensionVariantPtr) callconv(.c) c.GDExtensionBool {
    comptime validateExports(T);

    return struct {
        pub fn func(p_instance: c.GDExtensionClassInstancePtr, name: c.GDExtensionConstStringNamePtr, value: c.GDExtensionVariantPtr) callconv(.c) c.GDExtensionBool {
            if (p_instance == null) return 0;

            const self: *T = @ptrCast(@alignCast(p_instance));
            const prop_name = @as(*StringName, @ptrCast(@constCast(name))).*;

            inline for (T.__exports) |entry| {
                if (comptime entry.isFieldExport()) {
                    const field_name = comptime entry.getFieldName().?;

                    var field_str = String.fromLatin1(field_name);
                    defer field_str.deinit();

                    if (prop_name.casecmpTo(field_str) == 0) {
                        @as(*Variant, @ptrCast(@alignCast(value))).* = Variant.init(@field(self, field_name));
                        return 1;
                    }
                }
            }
            return 0;
        }
    }.func;
}

pub fn generatePropertyCanRevertBind(comptime T: type) fn (c.GDExtensionClassInstancePtr, c.GDExtensionConstStringNamePtr) callconv(.c) c.GDExtensionBool {
    comptime validateExports(T);

    return struct {
        pub fn func(p_instance: c.GDExtensionClassInstancePtr, p_name: c.GDExtensionConstStringNamePtr) callconv(.c) c.GDExtensionBool {
            _ = p_instance;
            const prop_name = @as(*StringName, @ptrCast(@constCast(p_name))).*;

            inline for (T.__exports) |entry| {
                if (comptime entry.isFieldExport()) {
                    const field_name = comptime entry.getFieldName().?;

                    var field_str = String.fromLatin1(field_name);
                    defer field_str.deinit();

                    if (prop_name.casecmpTo(field_str) == 0) {
                        inline for (@typeInfo(T).@"struct".fields) |sf| {
                            if (comptime std.mem.eql(u8, sf.name, field_name)) {
                                if (sf.default_value_ptr != null) {
                                    return 1;
                                }
                            }
                        }
                    }
                }
            }
            return 0;
        }
    }.func;
}

pub fn generatePropertyGetRevertBind(comptime T: type) fn (c.GDExtensionClassInstancePtr, c.GDExtensionConstStringNamePtr, c.GDExtensionVariantPtr) callconv(.c) c.GDExtensionBool {
    comptime validateExports(T);

    return struct {
        pub fn func(p_instance: c.GDExtensionClassInstancePtr, p_name: c.GDExtensionConstStringNamePtr, r_ret: c.GDExtensionVariantPtr) callconv(.c) c.GDExtensionBool {
            _ = p_instance;
            const prop_name = @as(*StringName, @ptrCast(@constCast(p_name))).*;

            inline for (T.__exports) |entry| {
                if (comptime entry.isFieldExport()) {
                    const field_name = comptime entry.getFieldName().?;

                    var field_str = String.fromLatin1(field_name);
                    defer field_str.deinit();

                    if (prop_name.casecmpTo(field_str) == 0) {
                        inline for (@typeInfo(T).@"struct".fields) |sf| {
                            if (comptime std.mem.eql(u8, sf.name, field_name)) {
                                if (sf.default_value_ptr) |def_ptr| {
                                    const FieldType = @FieldType(T, field_name);
                                    const default = @as(*const FieldType, @ptrCast(@alignCast(def_ptr))).*;
                                    @as(*Variant, @ptrCast(@alignCast(r_ret))).* = Variant.init(default);
                                    return 1;
                                }
                            }
                        }
                    }
                }
            }
            return 0;
        }
    }.func;
}
