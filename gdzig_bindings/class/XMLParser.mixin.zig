/// Opens a raw XML buffer on this XMLParser instance.
///
/// - **buf**: A slice containing the buffer data.
///
/// **Since Godot 4.1**
pub inline fn openBuf(self: *XMLParser, buf: []const u8) void {
    raw.xmlParserOpenBuffer(self.ptr(), @ptrCast(buf.ptr), buf.len);
}

// @mixin stop

const raw: *Interface = &@import("../gdzig_bindings.zig").raw;

const Interface = @import("../Interface.zig");
const XMLParser = @import("./xmlparser.zig").XMLParser;
