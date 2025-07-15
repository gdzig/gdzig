/// Opens a raw XML buffer on this XMLParser instance.
///
/// - **buffer**: A slice containing the buffer data.
///
/// @see XMLParser::open_buffer()
///
/// **Since Godot 4.1**
pub inline fn openBuffer(self: *XMLParser, buffer: []const u8) void {
    raw.xmlParserOpenBuffer(self.ptr(), buffer.ptr, buffer.len);
}

// @mixin stop

const raw: *Interface = &@import("../gdzig_bindings.zig").raw;

const Interface = @import("../Interface.zig");
const XMLParser = @import("./xml_parser.zig").XMLParser;
