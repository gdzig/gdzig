const std = @import("std");
const mzvr = @import("mvzr");
const case = @import("case");

const PackedArrayType = enum {
    byte,
    int32,
    int64,
    float32,
    float64,
    string,
    vector2,
    vector3,
    color,
    vector4,
};

pub const regex = mzvr.compile("^Packed([a-zA-Z0-9])+Array$") orelse @compileError("Failed to compile regex");

fn parseArrayType(class_name: []const u8) !PackedArrayType {
    const name = class_name["Packed".len..(class_name.len - "Array".len)];

    var buf: [16]u8 = undefined;
    const name_camel = try case.bufTo(&buf, .camel, name);

    return std.meta.stringToEnum(PackedArrayType, name_camel) orelse std.debug.panic("Failed to parse array type: {s}", .{class_name});
}
