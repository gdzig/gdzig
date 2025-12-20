const convert_tab_size = 4;

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

pub const DocumentConfig = struct {
    base_url: []const u8,
    verbosity: Config.Verbosity = .verbose,
};

pub const DocumentContext = struct {
    const link_prefix = "#gdzig.";

    base_url: []const u8,
    symbol_lookup: StringHashMap(Symbol),
    codegen_ctx: *const CodegenContext,
    current_class: ?[]const u8 = null,
    write_ctx: ?*const WriteContext = null,
    // SAFETY: will be initialized in fromWriteContext
    writer: *std.io.Writer = undefined,
    verbosity: Config.Verbosity = .verbose,

    pub fn init(codegen_ctx: *const CodegenContext, current_class: ?[]const u8, symbol_lookup: StringHashMap(Symbol), config: DocumentConfig) DocumentContext {
        return DocumentContext{
            .base_url = config.base_url,
            .codegen_ctx = codegen_ctx,
            .current_class = current_class,
            .symbol_lookup = symbol_lookup,
            .verbosity = config.verbosity,
        };
    }

    pub fn fromOpaque(ptr: ?*anyopaque) *DocumentContext {
        return @ptrCast(@alignCast(@constCast(ptr)));
    }

    pub fn fromWriteContext(write_ctx: *const WriteContext) *DocumentContext {
        var doc_ctx: *DocumentContext = .fromOpaque(write_ctx.user_data);
        if (doc_ctx.write_ctx == null) {
            doc_ctx.write_ctx = write_ctx;
            doc_ctx.writer = @constCast(write_ctx.writer);
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
        const symbol_link_fmt = std.fmt.comptimePrint("[{{s}}]({{s}}{s}{{s}})", .{link_prefix});
        try self.writer.print(symbol_link_fmt, .{ symbol.label, self.base_url, symbol.path });
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

        if (self.verbosity == .verbose) {
            logger.err("Enum symbol lookup failed: {s}, current class: {s}", .{ enum_name, self.current_class orelse "unknown" });
        }
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

        if (self.verbosity == .verbose) {
            logger.err("Method symbol lookup failed: {s}, current class: {s}", .{ method_name, self.current_class orelse "unknown" });
        }

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
    verbosity: Config.Verbosity = .verbose,
};

pub fn convertDocsToMarkdown(allocator: Allocator, input: []const u8, ctx: *const CodegenContext, options: Options) ![]const u8 {
    var doc_ctx = DocumentContext.init(ctx, options.current_class, ctx.symbol_lookup, .{
        .base_url = "https://gdzig.github.io/gdzig/",
        .verbosity = options.verbosity,
    });

    var doc = try Document.loadFromBuffer(allocator, input, .{
        .verbatim_tags = verbatim_tags,
        .tokenizer_options = TokenizerOptions{
            .equals_required_in_parameters = false,
        },
        .parser_options = ParserOptions{
            .is_self_closing_fn = isSelfClosing,
            .user_data = @ptrCast(@constCast(&doc_ctx)),
        },
    });
    defer doc.deinit();

    var output: std.io.Writer.Allocating = .init(allocator);

    try bbcodez.fmt.md.renderDocument(allocator, doc, &output.writer, .{
        .write_element_fn = writeElement,
        .user_data = @ptrCast(@constCast(&doc_ctx)),
        .convert_tab_size = convert_tab_size,
    });

    return output.toOwnedSlice();
}

fn getWriteContext(ptr: ?*const anyopaque) *const WriteContext {
    return @ptrCast(@alignCast(ptr));
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

const Node = bbcodez.Node;
const TempDir = temp.TempDir;
const Document = bbcodez.Document;
const Allocator = std.mem.Allocator;
const Symbol = CodegenContext.Symbol;
const Config = @import("../Config.zig");
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
