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

pub const DocumentContext = struct {
    // TODO: add support for setting a configurable base url
    const link_prefix = "#gdzig.";

    var symbol_lookup = StringHashMap([]const u8).empty;

    codegen_ctx: *const CodegenContext,
    current_class: ?[]const u8 = null,
    write_ctx: ?*const WriteContext = null,
    // SAFETY: will be initialized in fromWriteContext
    writer: *std.io.AnyWriter = undefined,

    pub fn init(codegen_ctx: *const CodegenContext, current_class: ?[]const u8) DocumentContext {
        return DocumentContext{
            .codegen_ctx = codegen_ctx,
            .current_class = current_class,
        };
    }

    pub fn fromOpaque(ptr: ?*anyopaque) *DocumentContext {
        return @constCast(@alignCast(@ptrCast(ptr)));
    }

    pub fn fromWriteContext(write_ctx: *const WriteContext) *DocumentContext {
        var doc_ctx: *DocumentContext = .fromOpaque(write_ctx.user_data);
        if (doc_ctx.write_ctx == null) {
            doc_ctx.write_ctx = write_ctx;
            doc_ctx.writer = @constCast(&write_ctx.writer);
        }
        return doc_ctx;
    }

    pub fn resolveSymbol(self: DocumentContext, symbol: []const u8, symbol_type: Element) ?[]const u8 {
        return switch (symbol_type) {
            .@"enum" => self.resolveEnum(symbol),
            .method => self.resolveMethod(symbol),
            else => null,
        };
    }

    fn resolveEnum(self: DocumentContext, enum_name: []const u8) ?[]const u8 {
        if (self.current_class) |class_name| {
            const qualified = std.fmt.allocPrint(self.codegen_ctx.allocator, "{s}.{s}", .{ class_name, enum_name }) catch return null;
            defer self.codegen_ctx.allocator.free(qualified);

            // Check if this qualified name exists in symbol_lookup
            if (self.symbolLookup(qualified)) |link| {
                return link;
            }
        }
        // Fall back to global lookup
        return self.symbolLookup(enum_name);
    }

    fn resolveMethod(self: *const DocumentContext, method_name: []const u8) ?[]const u8 {
        if (self.current_class) |class_name| {
            const qualified = std.fmt.allocPrint(self.codegen_ctx.allocator, "{s}.{s}", .{ class_name, method_name }) catch return null;
            // Check if this qualified name exists in symbol_lookup
            if (self.symbolLookup(qualified)) |link| {
                return link;
            }
        }
        // Fall back to global lookup
        return self.symbolLookup(method_name);
    }

    fn buildSymbolLookupTable(self: DocumentContext) !void {
        if (symbol_lookup.size == 0) {
            const ctx = self.codegen_ctx;
            const api = ctx.api;

            logger.debug("Initializing symbol lookup...", .{});

            try symbol_lookup.putNoClobber(ctx.allocator, "Variant", "Variant");

            for (api.classes) |class| {
                if (util.shouldSkipClass(class.name)) continue;

                const doc_name = try std.fmt.allocPrint(ctx.allocator, "bindings.core.{s}", .{class.name});
                try symbol_lookup.putNoClobber(ctx.allocator, class.name, doc_name);

                for (class.enums orelse &.{}) |@"enum"| {
                    const enum_name = try std.fmt.allocPrint(ctx.allocator, "{s}.{s}", .{ class.name, @"enum".name });
                    const enum_doc_name = try std.fmt.allocPrint(ctx.allocator, "{s}.{s}", .{ doc_name, enum_name });
                    try symbol_lookup.putNoClobber(ctx.allocator, enum_name, enum_doc_name);
                }
            }

            for (api.builtin_classes) |builtin| {
                if (util.shouldSkipClass(builtin.name)) continue;

                const doc_name = try std.fmt.allocPrint(ctx.allocator, "bindings.core.{0s}", .{builtin.name});
                try symbol_lookup.putNoClobber(ctx.allocator, builtin.name, doc_name);

                for (builtin.enums orelse &.{}) |@"enum"| {
                    const enum_name = try std.fmt.allocPrint(ctx.allocator, "{s}.{s}", .{ builtin.name, @"enum".name });
                    const enum_doc_name = try std.fmt.allocPrint(ctx.allocator, "{s}.{s}", .{ doc_name, enum_name });
                    try symbol_lookup.putNoClobber(ctx.allocator, enum_name, enum_doc_name);
                }
            }

            for (api.global_enums) |@"enum"| {
                const doc_name = try std.fmt.allocPrint(ctx.allocator, "bindings.global.{s}", .{@"enum".name});
                try symbol_lookup.putNoClobber(ctx.allocator, @"enum".name, doc_name);
            }

            logger.debug("Symbol lookup initialized. Size: {d}", .{symbol_lookup.size});
        }
    }

    pub fn symbolLookup(self: DocumentContext, key: []const u8) ?[]const u8 {
        _ = self;
        return symbol_lookup.get(key);
    }

    pub fn writeSymbolLink(self: DocumentContext, symbol_name: []const u8, link: []const u8) anyerror!bool {
        const symbol_link_fmt = std.fmt.comptimePrint("[{{s}}]({s}{{s}})", .{link_prefix});
        try self.writer.print(symbol_link_fmt, .{ symbol_name, link });
        return true;
    }

    pub fn writeLineBreak(self: DocumentContext, _: Node) anyerror!bool {
        try self.writer.writeByte('\n');
        return true;
    }

    pub fn writeAnnotation(self: DocumentContext, node: Node) anyerror!bool {
        // TODO: make it a link
        const annotation_name = try node.getValue() orelse return false;
        try self.writer.print("`{s}`", .{annotation_name});
        return true;
    }

    pub fn writeEnum(self: DocumentContext, node: Node) anyerror!bool {
        const enum_name = try node.getValue() orelse return false;

        if (self.resolveEnum(enum_name)) |link| {
            if (try self.writeSymbolLink(enum_name, link)) {
                return true;
            }
        }

        logger.err("Enum symbol lookup failed: {s}, current class: {s}", .{ enum_name, self.current_class orelse "unknown" });
        try self.writer.print("`{s}`", .{enum_name});
        return true;
    }

    pub fn writeConstant(self: DocumentContext, node: Node) anyerror!bool {
        // TODO: make it a link
        const constant_name = try node.getValue() orelse return false;
        try self.writer.print("`{s}`", .{constant_name});
        return true;
    }

    pub fn writeMember(self: DocumentContext, node: Node) anyerror!bool {
        const member_name = try node.getValue() orelse return false;
        try self.writer.print("`{s}`", .{member_name});
        return true;
    }

    pub fn writeMethod(self: DocumentContext, node: Node) anyerror!bool {
        // TODO: make it a link
        // how do we get the name of the class that the method belongs to?
        const method_name = try node.getValue() orelse return false;
        try self.writer.print("`{s}`", .{method_name});
        return true;
    }

    pub fn writeCodeblock(self: DocumentContext, node: Node) anyerror!bool {
        try self.writer.writeAll("```");
        try render(node, self.write_ctx.?);
        try self.writer.writeAll("```");

        return true;
    }

    pub fn writeCodeblocks(self: DocumentContext, node: Node) anyerror!bool {
        var element_list = try node.childrenOfType(self.codegen_ctx.allocator, .element);
        defer element_list.deinit(self.codegen_ctx.allocator);

        for (element_list.items) |child| {
            const lang = try child.getName();
            try self.writer.print("```{s}", .{lang});
            try render(child, self.write_ctx.?);
            try self.writer.writeAll("```");
        }

        return true;
    }

    pub fn writeParam(self: DocumentContext, node: Node) anyerror!bool {
        const param_name = try node.getValue() orelse return false;
        try self.writer.print("`{s}`", .{param_name});
        return true;
    }

    pub fn writeBasicType(self: DocumentContext, node: Node) anyerror!bool {
        const type_name = node.getName() catch return false;
        try self.writer.print("`{s}`", .{type_name});
        return true;
    }
};

pub const Options = struct {
    current_class: ?[]const u8 = null,
};

pub fn convertDocsToMarkdown(allocator: Allocator, input: []const u8, ctx: *const CodegenContext, options: Options) ![]const u8 {
    var doc_ctx = DocumentContext.init(ctx, options.current_class);

    try doc_ctx.buildSymbolLookupTable();

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
        .user_data = @constCast(@ptrCast(&doc_ctx)),
    });

    return output.toOwnedSlice(allocator);
}

fn getWriteContext(ptr: ?*const anyopaque) *const WriteContext {
    return @alignCast(@ptrCast(ptr));
}

fn writeElement(node: Node, ctx_ptr: ?*const anyopaque) anyerror!bool {
    const doc_ctx: *DocumentContext = .fromWriteContext(getWriteContext(ctx_ptr));

    const node_name = try node.getName();
    if (doc_ctx.symbolLookup(node_name)) |link| {
        if (try doc_ctx.writeSymbolLink(node_name, link)) {
            return true;
        }
    }

    const el: Element = std.meta.stringToEnum(Element, try node.getName()) orelse return false;

    return switch (el) {
        .codeblocks => try doc_ctx.writeCodeblocks(node),
        .codeblock, .gdscript, .csharp => try doc_ctx.writeCodeblock(node),
        .param => try doc_ctx.writeParam(node),
        .bool, .int, .float => try doc_ctx.writeBasicType(node),
        .method => try doc_ctx.writeMethod(node),
        .member => try doc_ctx.writeMember(node),
        .constant => try doc_ctx.writeConstant(node),
        .@"enum" => try doc_ctx.writeEnum(node),
        .br => try doc_ctx.writeLineBreak(node),
        .annotation => try doc_ctx.writeAnnotation(node),
    };
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
const util = @import("../util.zig");

const logger = std.log.scoped(.docs);
