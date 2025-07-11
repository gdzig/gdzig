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

const self_closing_tags: std.StaticStringMap(void) = .initComptime(.{
    .{"method"},
    .{"member"},
    .{"constant"},
    .{"enum"},
    .{"annotation"},
    .{"param"},
    .{"bool"},
    .{"int"},
    .{"float"},
    .{"br"},
});

pub const DocumentContext = struct {
    // TODO: add support for setting a configurable base url
    const link_prefix = "#gdzig.";

    symbol_lookup: StringHashMap(Symbol),
    codegen_ctx: *const CodegenContext,
    current_class: ?[]const u8 = null,
    write_ctx: ?*const WriteContext = null,
    // SAFETY: will be initialized in fromWriteContext
    writer: *std.io.AnyWriter = undefined,

    pub fn init(codegen_ctx: *const CodegenContext, current_class: ?[]const u8, symbol_lookup: StringHashMap(Symbol)) DocumentContext {
        return DocumentContext{
            .codegen_ctx = codegen_ctx,
            .current_class = current_class,
            .symbol_lookup = symbol_lookup,
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

    fn resolveEnum(self: DocumentContext, enum_name: []const u8) ?Symbol {
        if (self.current_class) |class_name| {
            const qualified = std.fmt.allocPrint(self.codegen_ctx.rawAllocator(), "{s}.{s}", .{ class_name, enum_name }) catch return null;
            defer self.codegen_ctx.rawAllocator().free(qualified);

            // Check if this qualified name exists in symbol_lookup
            if (self.symbolLookup(qualified)) |symbol| {
                return symbol;
            }
        }
        // Fall back to global lookup
        return self.symbolLookup(enum_name);
    }

    fn resolveMethod(self: *const DocumentContext, method_name: []const u8) ?Symbol {
        if (self.current_class) |class_name| {
            const qualified = std.fmt.allocPrint(self.codegen_ctx.rawAllocator(), "{s}.{s}", .{ class_name, method_name }) catch return null;
            defer self.codegen_ctx.rawAllocator().free(qualified);

            // Check if this qualified name exists in symbol_lookup
            if (self.symbolLookup(qualified)) |symbol| {
                return symbol;
            }
        }
        // Fall back to global lookup
        return self.symbolLookup(method_name);
    }

    pub fn symbolLookup(self: DocumentContext, key: []const u8) ?Symbol {
        return self.symbol_lookup.get(key);
    }

    pub fn writeSymbolLink(self: DocumentContext, symbol: Symbol) anyerror!bool {
        const symbol_link_fmt = std.fmt.comptimePrint("[{{s}}]({s}{{s}})", .{link_prefix});
        try self.writer.print(symbol_link_fmt, .{ symbol.label, symbol.path });
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

        if (self.resolveEnum(enum_name)) |symbol| {
            if (try self.writeSymbolLink(symbol)) {
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
        const method_name = try node.getValue() orelse return false;

        if (self.resolveMethod(method_name)) |symbol| {
            if (try self.writeSymbolLink(symbol)) {
                return true;
            }
        }

        logger.err("Method symbol lookup failed: {s}, current class: {s}", .{ method_name, self.current_class orelse "unknown" });
        try self.writer.print("`{s}`", .{method_name});
        return true;
    }

    pub fn writeCodeblockInner(self: DocumentContext, node: Node) anyerror!bool {
        try bbcodez.fmt.md.writeAllChildrenText(node, self.write_ctx.?);
        return true;
    }

    pub fn writeCodeblock(self: DocumentContext, node: Node) anyerror!bool {
        try self.writer.writeAll("```");
        _ = try self.writeCodeblockInner(node);
        try self.writer.writeAll("```");
        return true;
    }

    pub fn writeCodeblocks(self: DocumentContext, node: Node) anyerror!bool {
        var it = node.iterator(.{ .type = .element });
        while (it.next()) |child| {
            const lang = try child.getName();
            try self.writer.print("\n## {s}\n", .{lang});
            try self.writer.writeAll("\n```");
            _ = try self.writeCodeblockInner(child);
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

fn isSelfClosing(user_data: ?*anyopaque, token: Token) bool {
    if (self_closing_tags.has(token.name)) {
        return true;
    }

    if (user_data) |ud| {
        const self: *const DocumentContext = @ptrCast(@alignCast(ud));
        return self.symbol_lookup.contains(token.name);
    }

    return false;
}

pub const Options = struct {
    current_class: ?[]const u8 = null,
};

pub fn convertDocsToMarkdown(allocator: Allocator, input: []const u8, ctx: *const CodegenContext, options: Options) ![]const u8 {
    var doc_ctx = DocumentContext.init(ctx, options.current_class, ctx.symbol_lookup);

    var doc = try Document.loadFromBuffer(allocator, input, .{
        .verbatim_tags = verbatim_tags,
        .tokenizer_options = TokenizerOptions{
            .equals_required_in_parameters = false,
        },
        .parser_options = ParserOptions{
            .is_self_closing_fn = isSelfClosing,
            .user_data = @constCast(@ptrCast(&doc_ctx)),
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

    if (node.type == .text) {
        return false;
    }

    const node_name = try node.getName();
    if (doc_ctx.symbolLookup(node_name)) |sym| {
        if (try doc_ctx.writeSymbolLink(sym)) {
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
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    var td: TempDir = try .create(arena.allocator(), .{});
    defer td.deinit();

    const bindings_output = try td.open(.{});
    var config: Config = try .testConfig(bindings_output);
    defer config.deinit();

    const godot_api = try GodotApi.parseFromReader(&arena, config.extension_api.reader().any());
    defer godot_api.deinit();

    const ctx: CodegenContext = try .build(&arena, godot_api.value, config);

    {
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

        const output = try convertDocsToMarkdown(testing.allocator, bbcode, &ctx, .{});
        defer testing.allocator.free(output);

        // std.debug.print("{s}\n", .{output});
    }
    {
        const bbcode =
            \\Most basic 3D game object, with a [Transform3D] and visibility settings. All other 3D game objects inherit from [Node3D]. Use [Node3D] as a parent node to move, scale, rotate and show/hide children in a 3D project.\nAffine operations (rotate, scale, translate) happen in parent's local coordinate system, unless the [Node3D] object is set as top-level. Affine operations in this coordinate system correspond to direct affine operations on the [Node3D]'s transform. The word local below refers to this coordinate system. The coordinate system that is attached to the [Node3D] object itself is referred to as object-local coordinate system.\n[b]Note:[/b] Unless otherwise specified, all methods that have angle parameters must have angles specified as [i]radians[/i]. To convert degrees to radians, use [method @GlobalScope.deg_to_rad].\n[b]Note:[/b] Be aware that \"Spatial\" nodes are now called \"Node3D\" starting with Godot 4. Any Godot 3.x references to \"Spatial\" nodes refer to \"Node3D\" in Godot 4.
        ;

        const output = try convertDocsToMarkdown(testing.allocator, bbcode, &ctx, .{
            .current_class = "Node3D",
        });
        defer testing.allocator.free(output);

        // std.debug.print("{s}\n", .{output});
    }
}

const Node = bbcodez.Node;
const TempDir = temp.TempDir;
const Document = bbcodez.Document;
const Allocator = std.mem.Allocator;
const Symbol = CodegenContext.Symbol;
const Config = @import("../Config.zig");
const ArrayList = std.ArrayListUnmanaged;
const GodotApi = @import("../GodotApi.zig");
const WriteContext = bbcodez.fmt.md.WriteContext;
const ParserOptions = bbcodez.parser.Options;
const TokenizerOptions = bbcodez.tokenizer.Options;
const Token = bbcodez.tokenizer.TokenResult.Token;
const CodegenContext = @import("../Context.zig");
const StringHashMap = std.StringHashMapUnmanaged;

const std = @import("std");
const testing = std.testing;
const temp = @import("temp");
const bbcodez = @import("bbcodez");

const logger = std.log.scoped(.docs);
