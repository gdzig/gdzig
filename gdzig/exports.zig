const std = @import("std");
const godot = @import("gdzig.zig");

const String = godot.builtin.String;
const StringName = godot.builtin.StringName;
const Variant = godot.builtin.Variant;
const PropertyHint = godot.global.PropertyHint;
const PropertyUsageFlags = godot.global.PropertyUsageFlags;
const heap = godot.heap;
const c = godot.c;

const ExportType = enum {
    @"export",
    @"export_group",
    @"export_subgroup",
    @"export_category",
    @"export_range",
    @"export_exp_easing",
    @"export_enum",
    @"export_flags",
    @"export_flags_2d_physics",
    @"export_flags_2d_render",
    @"export_flags_2d_navigation",
    @"export_flags_3d_physics",
    @"export_flags_3d_render",
    @"export_flags_3d_navigation",
    @"export_file",
    @"export_dir",
    @"export_global_file",
    @"export_global_dir",
    @"export_multiline",
    @"export_placeholder",
    @"export_color_no_alpha",
    @"export_node_path",
    @"export_storage",
    @"export_custom",
};

fn getExportType(comptime entry: anytype) ExportType {
    const first = entry[0];
    const FirstType = @TypeOf(first);

    if (FirstType == ExportType) {
        return first;
    } else if (@typeInfo(FirstType) == .enum_literal) {
        return @field(ExportType, @tagName(first));
    } else {
        @compileError("First element must be an ExportType or enum literal");
    }
}

fn isFieldExport(comptime exp: ExportType) bool {
    return switch (exp) {
        .@"export_group", .@"export_subgroup", .@"export_category" => false,
        else => true,
    };
}

fn getFieldName(comptime entry: anytype) [:0]const u8 {
    return @tagName(entry[1]);
}

fn getGroupName(comptime entry: anytype) [:0]const u8 {
    return entry[1];
}

fn buildRangeHintString(comptime entry: anytype) [:0]const u8 {
    const entry_info = @typeInfo(@TypeOf(entry)).@"struct";
    const field_count = entry_info.fields.len;

    if (field_count >= 4) {
        const min = entry[2];
        const max = entry[3];
        if (field_count >= 5) {
            const step = entry[4];
            return std.fmt.comptimePrint("{d},{d},{d}", .{ min, max, step });
        }
        return std.fmt.comptimePrint("{d},{d}", .{ min, max });
    }
    return "";
}

fn buildEnumHintString(comptime entry: anytype) [:0]const u8 {
    const options = entry[2];
    const options_info = @typeInfo(@TypeOf(options)).@"struct";

    comptime var result: []const u8 = "";
    inline for (options_info.fields, 0..) |_, i| {
        if (i > 0) result = result ++ ",";
        result = result ++ options[i];
    }
    return result ++ "";
}

fn getPropertyHint(comptime entry: anytype) struct { hint: PropertyHint, hint_string: [:0]const u8 } {
    const exp = getExportType(entry);
    const entry_info = @typeInfo(@TypeOf(entry)).@"struct";

    return switch (exp) {
        .@"export" => .{
            .hint = .property_hint_none,
            .hint_string = if (entry_info.fields.len >= 3) entry[2] else "",
        },
        .@"export_range" => .{
            .hint = .property_hint_range,
            .hint_string = buildRangeHintString(entry),
        },
        .@"export_enum" => .{
            .hint = .property_hint_enum,
            .hint_string = buildEnumHintString(entry),
        },
        .@"export_flags" => .{
            .hint = .property_hint_flags,
            .hint_string = buildEnumHintString(entry),
        },
        .@"export_flags_2d_physics" => .{ .hint = .property_hint_layers_2_d_physics, .hint_string = "" },
        .@"export_flags_2d_render" => .{ .hint = .property_hint_layers_2_d_render, .hint_string = "" },
        .@"export_flags_2d_navigation" => .{ .hint = .property_hint_layers_2_d_navigation, .hint_string = "" },
        .@"export_flags_3d_physics" => .{ .hint = .property_hint_layers_3_d_physics, .hint_string = "" },
        .@"export_flags_3d_render" => .{ .hint = .property_hint_layers_3_d_render, .hint_string = "" },
        .@"export_flags_3d_navigation" => .{ .hint = .property_hint_layers_3_d_navigation, .hint_string = "" },
        .@"export_file" => .{
            .hint = .property_hint_file,
            .hint_string = if (entry_info.fields.len >= 3) entry[2] else "",
        },
        .@"export_dir" => .{ .hint = .property_hint_dir, .hint_string = "" },
        .@"export_global_file" => .{
            .hint = .property_hint_global_file,
            .hint_string = if (entry_info.fields.len >= 3) entry[2] else "",
        },
        .@"export_global_dir" => .{ .hint = .property_hint_global_dir, .hint_string = "" },
        .@"export_multiline" => .{ .hint = .property_hint_multiline_text, .hint_string = "" },
        .@"export_placeholder" => .{
            .hint = .property_hint_placeholder_text,
            .hint_string = if (entry_info.fields.len >= 3) entry[2] else "",
        },
        .@"export_color_no_alpha" => .{ .hint = .property_hint_color_no_alpha, .hint_string = "" },
        .@"export_exp_easing" => .{ .hint = .property_hint_exp_easing, .hint_string = "" },
        .@"export_node_path" => .{
            .hint = .property_hint_node_path_valid_types,
            .hint_string = if (entry_info.fields.len >= 3) entry[2] else "",
        },
        .@"export_storage" => .{ .hint = .property_hint_none, .hint_string = "" },
        .@"export_custom" => .{
            .hint = entry[2],
            .hint_string = if (entry_info.fields.len >= 4) entry[3] else "",
        },
        .@"export_group", .@"export_subgroup", .@"export_category" => .{
            .hint = .property_hint_none,
            .hint_string = "",
        },
    };
}

fn getPropertyUsage(comptime entry: anytype) PropertyUsageFlags {
    const exp = getExportType(entry);
    const entry_info = @typeInfo(@TypeOf(entry)).@"struct";

    return switch (exp) {
        .@"export_storage" => .{ .property_usage_storage = true },
        .@"export_group" => .{ .property_usage_group = true },
        .@"export_subgroup" => .{ .property_usage_subgroup = true },
        .@"export_category" => .{ .property_usage_category = true },
        .@"export_custom" => if (entry_info.fields.len >= 5) entry[4] else PropertyUsageFlags.property_usage_default,
        else => PropertyUsageFlags.property_usage_default,
    };
}

fn validateExports(comptime T: type) void {
    if (!@hasDecl(T, "__exports")) {
        @compileError("Type must have '__exports' declaration");
    }

    inline for (T.__exports) |entry| {
        const exp = getExportType(entry);
        if (isFieldExport(exp)) {
            const field_name = getFieldName(entry);
            if (!@hasField(T, field_name)) {
                @compileError("Export references non-existent field '." ++ field_name ++ "'");
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
                const exp = comptime getExportType(entry);

                if (comptime isFieldExport(exp)) {
                    const field_name = comptime getFieldName(entry);
                    const hint_info = comptime getPropertyHint(entry);
                    const usage = comptime getPropertyUsage(entry);

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
                    const group_name = comptime getGroupName(entry);
                    const usage = comptime getPropertyUsage(entry);

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
                const exp = comptime getExportType(entry);

                if (comptime isFieldExport(exp)) {
                    const field_name = comptime getFieldName(entry);

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
                const exp = comptime getExportType(entry);

                if (comptime isFieldExport(exp)) {
                    const field_name = comptime getFieldName(entry);

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
                const exp = comptime getExportType(entry);

                if (comptime isFieldExport(exp)) {
                    const field_name = comptime getFieldName(entry);

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
                const exp = comptime getExportType(entry);

                if (comptime isFieldExport(exp)) {
                    const field_name = comptime getFieldName(entry);

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
