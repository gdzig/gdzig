const Element = enum {
    codeblock,
    codeblocks,
};

fn writeElement(node: Node, context: ?*anyopaque) anyerror!bool {
    const ctx: *Context = @alignCast(@ptrCast(context));
    const el: Element = std.meta.stringToEnum(Element, try node.getName()) orelse return false;

    return switch (el) {
        .codeblocks => try writeCodeblocks(node, ctx),
        .codeblock => try writeCodeblock(node, ctx),
    };
}

fn writeCodeblock(node: Node, ctx: *Context) anyerror!bool {
    try ctx.writer.writeAll("```");
    try render(node, ctx);
    try ctx.writer.writeAll("```");

    return true;
}

fn writeCodeblocks(node: Node, ctx: *Context) anyerror!bool {
    var element_list = try node.childrenOfType(ctx.allocator, .element);
    defer element_list.deinit(ctx.allocator);

    for (element_list.items) |child| {
        const lang = try child.getName();
        try ctx.writer.print("```{s}", .{lang});
        try render(child, ctx);
        try ctx.writer.writeAll("```");
    }

    return true;
}

const verbatim_tags = &[_][]const u8{
    "code",
    "gdscript",
    "csharp",
    "codeblock",
};

pub fn convertDocsToMarkdown(allocator: Allocator, input: []const u8) ![]const u8 {
    var doc = try Document.loadFromBuffer(allocator, input, .{
        .verbatim_tags = verbatim_tags,
        .tokenizer_options = TokenizerOptions{
            .equals_required_in_parameters = false,
        },
    });
    defer doc.deinit();

    var output = ArrayList(u8){};
    try bbcodez.fmt.md.renderDocument(allocator, doc, output.writer(allocator).any(), .{
        .write_element_fn = writeElement,
    });

    return output.toOwnedSlice(allocator);
}

test "convertDocsToMarkdown" {
    const bbcode =
        \\Converts one or more arguments of any type to string in the best way possible and prints them to the console.
        \\The following BBCode tags are supported: [code]b[/code], [code]i[/code], [code]u[/code], [code]s[/code], [code]indent[/code], [code]code[/code], [code]url[/code], [code]center[/code], [code]right[/code], [code]color[/code], [code]bgcolor[/code], [code]fgcolor[/code].
        \\URL tags only support URLs wrapped by a URL tag, not URLs with a different title.
        \\When printing to standard output, the supported subset of BBCode is converted to ANSI escape codes for the terminal emulator to display. Support for ANSI escape codes varies across terminal emulators, especially for italic and strikethrough. In standard output, [code]code[/code] is represented with faint text but without any font change. Unsupported tags are left as-is in standard output.
        \\[codeblocks]
        \\[gdscript skip-lint]
        \\print_rich("[color=green][b]Hello world![/b][/color]") # Prints "Hello world!", in green with a bold font.
        \\[/gdscript]
        \\[csharp skip-lint]
        \\GD.PrintRich("[color=green][b]Hello world![/b][/color]"); // Prints "Hello world!", in green with a bold font.
        \\[/csharp]
        \\[/codeblocks]
        \\[b]Note:[/b] Consider using [method push_error] and [method push_warning] to print error and warning messages instead of [method print] or [method print_rich]. This distinguishes them from print messages used for debugging purposes, while also displaying a stack trace when an error or warning is printed.
        \\[b]Note:[/b] On Windows, only Windows 10 and later correctly displays ANSI escape codes in standard output.
        \\[b]Note:[/b] Output displayed in the editor supports clickable [code skip-lint][url=address]text[/url][/code] tags. The [code skip-lint][url][/code] tag's [code]address[/code] value is handled by [method OS.shell_open] when clicked.
    ;

    const output = try convertDocsToMarkdown(testing.allocator, bbcode);
    defer testing.allocator.free(output);

    std.debug.print("{s}\n", .{output});
}

const render = bbcodez.fmt.md.render;

const Node = bbcodez.Node;
const Document = bbcodez.Document;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayListUnmanaged;
const Context = bbcodez.fmt.md.WriteContext;
const TokenizerOptions = bbcodez.tokenizer.Options;

const std = @import("std");
const testing = std.testing;
const bbcodez = @import("bbcodez");
