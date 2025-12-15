const Constant = @This();

doc: ?[]const u8 = null,
name: []const u8 = "_",
name_api: []const u8 = "_",
type: Type = .void,
value: []const u8 = "comptime unreachable",
skip: bool = false,

pub const replacements: std.StaticStringMap([]const u8) = .initComptime(.{
    .{ "inf", "std.math.inf(" ++ (if (std.mem.eql(u8, build_options.precision, "double")) "f64" else "f32") ++ ")" },
});

pub fn fromBuiltin(allocator: Allocator, builtin: *const Builtin, api: GodotApi.Builtin.Constant, ctx: *const Context) !Constant {
    var self: Constant = .{};
    errdefer self.deinit(allocator);

    self.name = name: {
        const name = try casez.allocConvert(allocator, gdzig_case.file, api.name);
        if (builtin.methods.contains(name)) {
            const n = try std.fmt.allocPrint(allocator, "{s}_", .{name});
            std.debug.assert(!builtin.methods.contains(n));
            break :name n;
        }
        break :name name;
    };
    self.name_api = try allocator.dupe(u8, api.name);
    self.type = try Type.from(allocator, api.type, false, ctx);
    self.doc = try docs.convertDocsToMarkdown(allocator, api.description, ctx, .{
        .current_class = builtin.name_api,
        .verbosity = ctx.config.verbosity,
    });
    self.value = blk: {
        const default_value: Value = try .parse(allocator, api.value, ctx);
        switch (default_value) {
            .constructor => |c| {
                const args = c.args;
                const arg_count = args.len;

                if (builtin.findConstructorByArgumentCount(arg_count)) |function| {
                    var output = std.Io.Writer.Allocating.init(allocator);
                    var writer = &output.writer;
                    try writer.writeAll(function.name);

                    try writer.writeAll("(");
                    for (args, 0..) |arg, i| {
                        const pval = replacements.get(arg) orelse arg;
                        try writer.writeAll(pval);

                        if (i != arg_count - 1) {
                            try writer.writeAll(", ");
                        }
                    }
                    try writer.writeAll(")");

                    break :blk output.written();
                }
            },
            else => {},
        }

        break :blk try allocator.dupe(u8, api.value);
    };

    return self;
}

pub fn fromClass(allocator: Allocator, api: GodotApi.Class.Constant, ctx: *const Context) !Constant {
    var self: Constant = .{};
    errdefer self.deinit(allocator);

    // TODO: normalization
    self.name = try allocator.dupe(u8, api.name);
    self.type = try .from(allocator, "int", false, ctx);
    self.value = try std.fmt.allocPrint(allocator, "{d}", .{api.value});

    return self;
}

pub fn fromMixin(allocator: Allocator, ast: Ast, index: NodeIndex) !?Constant {
    const var_decl = ast.fullVarDecl(index) orelse return null;
    const node = ast.nodes.get(@intFromEnum(index));

    const is_pub = blk: {
        const main_token = node.main_token;
        var token_index: usize = 0;
        while (token_index < main_token) : (token_index += 1) {
            const token = ast.tokens.get(token_index);
            if (token.tag == .keyword_pub) {
                break :blk true;
            }
        }
        break :blk false;
    };

    if (!is_pub) {
        return null;
    }

    const is_const = ast.tokens.get(var_decl.ast.mut_token).tag == .keyword_const;
    if (!is_const) {
        return null;
    }

    const name_token = var_decl.ast.mut_token + 1;
    const name = ast.tokenSlice(name_token);
    const name_api = try casez.allocConvert(allocator, gdzig_case.constant, name);

    return .{
        .skip = true,
        .name = name,
        .name_api = name_api,
    };
}

pub fn deinit(self: *Constant, allocator: Allocator) void {
    if (self.doc) |doc| allocator.free(doc);
    allocator.free(self.name);
    self.type.deinit(allocator);
    allocator.free(self.value);

    self.* = .{};
}

// https://ziggit.dev/t/comptime-code-to-create-a-tuple-from-an-array/11329/3
fn BuildTupleFromArray(comptime Array: type, comptime len: usize) type {
    const Element = std.meta.Elem(Array);
    const types_array: [len]type = @splat(Element);
    return std.meta.Tuple(&types_array);
}

fn buildTupleFromArray(array: anytype, comptime len: usize) BuildTupleFromArray(@TypeOf(array), len) {
    var a: BuildTupleFromArray(@TypeOf(array), len) = undefined;
    inline for (array, 0..len) |value, i| {
        a[i] = value;
    }
    return a;
}

const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayListUnmanaged;
const Ast = std.zig.Ast;
const NodeIndex = Ast.Node.Index;
const build_options = @import("build_options");

const casez = @import("casez");
const common = @import("common");
const gdzig_case = common.gdzig_case;

const Context = @import("../Context.zig");
const Type = Context.Type;
const Builtin = Context.Builtin;
const GodotApi = @import("../GodotApi.zig");
const docs = @import("docs.zig");
const Value = @import("value.zig").Value;
