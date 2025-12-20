//! Pure/stateless helper functions

const builtin_type_map = std.StaticStringMap(void).initComptime(.{
    .{"void"},
    .{"i8"},
    .{"u8"},
    .{"i16"},
    .{"u16"},
    .{"i32"},
    .{"u32"},
    .{"i64"},
    .{"u64"},
    .{"bool"},
    .{"f32"},
    .{"f64"},
    .{"c_int"},
    .{"uint8_t"},
});

pub fn childType(type_name: []const u8) []const u8 {
    var child_type = type_name;
    while (child_type[0] == '?' or child_type[0] == '*') {
        child_type = child_type[1..];
    }
    while (child_type[child_type.len - 1] == '*') {
        child_type = child_type[0 .. child_type.len - 1];
    }
    if (std.mem.startsWith(u8, child_type, "const ")) {
        child_type = child_type["const ".len..];
    }
    return child_type;
}

pub fn isBitfield(type_name: []const u8) bool {
    return std.mem.startsWith(u8, type_name, "bitfield::");
}

pub fn isBuiltinType(type_name: []const u8) bool {
    return builtin_type_map.has(type_name);
}

pub fn isEnum(type_name: []const u8) bool {
    return std.mem.startsWith(u8, type_name, "enum::") or isBitfield(type_name);
}

pub fn isStringType(type_name: []const u8) bool {
    return std.mem.eql(u8, type_name, "String") or std.mem.eql(u8, type_name, "StringName");
}

pub fn getEnumClass(type_name: []const u8) []const u8 {
    const pos = std.mem.lastIndexOf(u8, type_name, ".");
    if (pos) |p| {
        if (isBitfield(type_name)) {
            return type_name[10..p];
        } else {
            return type_name[6..p];
        }
    } else {
        return "GlobalConstants";
    }
}

pub fn getEnumName(type_name: []const u8) []const u8 {
    const pos = std.mem.lastIndexOf(u8, type_name, ":");
    if (pos) |p| {
        return type_name[p + 1 ..];
    } else {
        return type_name;
    }
}

pub fn shouldSkipClass(class_name: []const u8) bool {
    return std.mem.eql(u8, class_name, "bool") or
        std.mem.eql(u8, class_name, "Nil") or
        std.mem.eql(u8, class_name, "int") or
        std.mem.eql(u8, class_name, "float");
}

const std = @import("std");

const GodotApi = @import("GodotApi.zig");
