const Element = enum {
    // code blocks
    codeblock,
    codeblocks,
    gdscript,
    csharp,

    // links
    method,
    member,
    constant,
    @"enum",
    annotation,

    // basic
    param,
    bool,
    int,
    float,
    br,
};

pub fn convertDocsToMarkdown(allocator: Allocator, input: []const u8, ctx: *const CodegenContext) ![]const u8 {
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
        .user_data = @constCast(@ptrCast(ctx)),
    });

    return output.toOwnedSlice(allocator);
}

fn getWriteContext(ptr: ?*const anyopaque) *const WriteContext {
    return @alignCast(@ptrCast(ptr));
}

fn getContext(ptr: ?*const anyopaque) *const CodegenContext {
    return @alignCast(@ptrCast(ptr));
}

fn writeElement(node: Node, ctx_ptr: ?*const anyopaque) anyerror!bool {
    const ctx = getWriteContext(ctx_ptr);

    const node_name = try node.getName();
    if (try symbolLookup(node_name, ctx)) |link| {
        if (try writeSymbolLink(node_name, link, ctx)) {
            return true;
        }
    }

    const el: Element = std.meta.stringToEnum(Element, try node.getName()) orelse return false;

    return switch (el) {
        .codeblocks => try writeCodeblocks(node, ctx),
        .codeblock, .gdscript, .csharp => try writeCodeblock(node, ctx),
        .param => try writeParam(node, ctx),
        .bool, .int, .float => try writeBasicType(node, ctx),
        .method => try writeMethod(node, ctx),
        .member => try writeMember(node, ctx),
        .constant => try writeConstant(node, ctx),
        .@"enum" => try writeEnum(node, ctx),
        .br => try writeLineBreak(node, ctx),
        .annotation => try writeAnnotation(node, ctx),
    };
}

var symbol_lookup = StringHashMap([]const u8).empty;
const prefix = "#gdzig.";

fn symbolLookup(key: []const u8, ctx: *const WriteContext) !?[]const u8 {
    if (symbol_lookup.size == 0) {
        const api = getContext(ctx.user_data).api;

        logger.debug("Initializing symbol lookup...", .{});

        try symbol_lookup.putNoClobber(ctx.allocator, "Variant", "Variant");

        for (api.classes) |class| {
            const doc_name = try std.fmt.allocPrint(ctx.allocator, "bindings.core.{s}", .{class.name});
            try symbol_lookup.putNoClobber(ctx.allocator, class.name, doc_name);
        }

        for (api.builtin_classes) |builtin| {
            const doc_name = try std.fmt.allocPrint(ctx.allocator, "bindings.core.{s}", .{builtin.name});
            try symbol_lookup.putNoClobber(ctx.allocator, builtin.name, doc_name);
        }

        for (api.global_enums) |@"enum"| {
            const doc_name = try std.fmt.allocPrint(ctx.allocator, "bindings.global.{s}", .{@"enum".name});
            try symbol_lookup.putNoClobber(ctx.allocator, @"enum".name, doc_name);
        }

        logger.debug("Symbol lookup initialized. Size: {d}", .{symbol_lookup.size});
    }

    return symbol_lookup.get(key);
}

fn writeSymbolLink(symbol_name: []const u8, link: []const u8, ctx: *const WriteContext) anyerror!bool {
    const symbol_link_fmt = std.fmt.comptimePrint("[{{s}}]({s}{{s}})", .{prefix});
    try ctx.writer.print(symbol_link_fmt, .{ symbol_name, link });
    return true;
}

fn writeLineBreak(_: Node, ctx: *const WriteContext) anyerror!bool {
    try ctx.writer.writeByte('\n');
    return true;
}

fn writeAnnotation(node: Node, ctx: *const WriteContext) anyerror!bool {
    // TODO: make it a link
    const annotation_name = try node.getValue() orelse return false;
    try ctx.writer.print("`{s}`", .{annotation_name});
    return true;
}

fn writeEnum(node: Node, ctx: *const WriteContext) anyerror!bool {
    const enum_name = try node.getValue() orelse return false;

    if (try symbolLookup(enum_name, ctx)) |link| {
        if (try writeSymbolLink(enum_name, link, ctx)) {
            return true;
        }
    }

    logger.warn("Enum symbol lookup failed: {s}", .{enum_name});
    try ctx.writer.print("`{s}`", .{enum_name});
    return true;
}

fn writeConstant(node: Node, ctx: *const WriteContext) anyerror!bool {
    // TODO: make it a link
    const constant_name = try node.getValue() orelse return false;
    try ctx.writer.print("`{s}`", .{constant_name});
    return true;
}

fn writeMember(node: Node, ctx: *const WriteContext) anyerror!bool {
    const member_name = try node.getValue() orelse return false;
    try ctx.writer.print("`{s}`", .{member_name});
    return true;
}

fn writeMethod(node: Node, ctx: *const WriteContext) anyerror!bool {
    // TODO: make it a link
    // how do we get the name of the class that the method belongs to?
    const method_name = try node.getValue() orelse return false;
    try ctx.writer.print("`{s}`", .{method_name});
    return true;
}

fn writeCodeblock(node: Node, ctx: *const WriteContext) anyerror!bool {
    try ctx.writer.writeAll("```");
    try render(node, ctx);
    try ctx.writer.writeAll("```");

    return true;
}

fn writeCodeblocks(node: Node, ctx: *const WriteContext) anyerror!bool {
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

fn writeParam(node: Node, ctx: *const WriteContext) anyerror!bool {
    const param_name = try node.getValue() orelse return false;
    try ctx.writer.print("`{s}`", .{param_name});
    return true;
}

fn writeBasicType(node: Node, ctx: *const WriteContext) anyerror!bool {
    const type_name = node.getName() catch return false;
    try ctx.writer.print("`{s}`", .{type_name});
    return true;
}

const verbatim_tags = &[_][]const u8{
    "code",
    "gdscript",
    "csharp",
    "codeblock",
};

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
const WriteContext = bbcodez.fmt.md.WriteContext;
const TokenizerOptions = bbcodez.tokenizer.Options;
const CodegenContext = @import("../Context.zig");
const StringHashMap = std.StringHashMapUnmanaged;

const std = @import("std");
const testing = std.testing;
const bbcodez = @import("bbcodez");
const logger = std.log.scoped(.docs);
