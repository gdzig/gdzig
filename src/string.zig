pub fn stringNameToAscii(strname: StringName, buf: []u8) []const u8 {
    const str = String.fromStringName(strname);
    return stringToAscii(str, buf);
}

pub fn stringToAscii(str: String, buf: []u8) []const u8 {
    const sz = godot.interface.stringToLatin1Chars(@ptrCast(&str), &buf[0], @intCast(buf.len));
    return buf[0..@intCast(sz)];
}

const godot = @import("./gdzig.zig");
const String = godot.builtin.String;
const StringName = godot.builtin.StringName;
