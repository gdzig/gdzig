const raw: *Interface = &@import("../../gdzig_bindings.zig").raw;

/// Opens a raw XML buffer on an XMLParser instance.
///
/// @param parser A pointer to an XMLParser object.
/// @param buffer A slice containing the buffer data.
///
/// @see XMLParser::open_buffer()
///
/// @since 4.1
pub inline fn xmlParserOpenBuffer(parser: *XMLParser, buffer: []const u8) void {
    raw.xmlParserOpenBuffer(parser.ptr(), buffer.ptr, buffer.len);
}

const class = @import("../class.zig");
const XMLParser = class.XMLParser;
const Interface = @import("../Interface.zig");
