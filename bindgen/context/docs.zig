pub fn convertDocsToMarkdown(allocator: Allocator, input: []const u8) ![]const u8 {
    var doc = try BbcodeDocument.loadFromBuffer(allocator, input);
    defer doc.deinit();

    var output = ArrayList(u8){};
    try bbcodez.fmt.md.renderDocument(allocator, doc, output.writer(allocator).any());

    return output.toOwnedSlice(allocator);
}

const Allocator = std.mem.Allocator;
const BbcodeDocument = bbcodez.Document;
const ArrayList = std.ArrayListUnmanaged;

const std = @import("std");
const bbcodez = @import("bbcodez");
