/// Opens a raw XML buffer on this XmlParser instance.
///
/// - **buf**: A slice containing the buffer data.
///
/// **Since Godot 4.1**
pub inline fn openBuf(self: *Self, buf: []const u8) void {
    raw.xmlParserOpenBuffer(self.ptr(), @ptrCast(buf.ptr), buf.len);
}

// @mixin stop

const Self = gdzig.class.XmlParser;

const gdzig = @import("gdzig");
const raw = &gdzig.raw;
