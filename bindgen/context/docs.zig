const Element = enum {
    codeblocks,
};

fn writeElement(node: Node, context: ?*anyopaque) anyerror!bool {
    const ctx: *Context = @alignCast(@ptrCast(context));
    const el: Element = std.meta.stringToEnum(Element, try node.getName()) orelse return false;

    return switch (el) {
        .codeblocks => try writeCodeblocks(node, ctx),
    };
}

fn writeCodeblocks(node: Node, ctx: *Context) anyerror!bool {
    for (node.children.items) |child| {
        const lang = try child.getName();
        try ctx.writer.print("```{s}\n", .{lang});
        try render(child, ctx);
        try ctx.writer.writeAll("```\n");
    }

    return true;
}

pub fn convertDocsToMarkdown(allocator: Allocator, input: []const u8) ![]const u8 {
    var doc = try Document.loadFromBuffer(allocator, input, .{});
    defer doc.deinit();

    var output = ArrayList(u8){};
    try bbcodez.fmt.md.renderDocument(allocator, doc, output.writer(allocator).any(), .{
        .write_element_fn = writeElement,
    });

    return output.toOwnedSlice(allocator);
}

const render = bbcodez.fmt.md.render;

const Node = bbcodez.Node;
const Document = bbcodez.Document;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayListUnmanaged;
const Context = bbcodez.fmt.md.WriteContext;

const std = @import("std");
const bbcodez = @import("bbcodez");
