const Builtin = @This();

doc: ?[]const u8 = null,
module: []const u8 = "",
name: []const u8 = "_",
name_api: []const u8 = "_",

size: usize = 0,

has_destructor: bool = false,

constants: StringArrayHashMap(Constant) = .empty,
constructors: StringArrayHashMap(Function) = .empty,
enums: StringArrayHashMap(Enum) = .empty,
fields: StringArrayHashMap(Field) = .empty,
methods: StringArrayHashMap(Function) = .empty,
operators: ArrayList(Function) = .empty,

imports: Imports = .empty,

pub fn fromApi(allocator: Allocator, api: GodotApi.Builtin, ctx: *const Context) !Builtin {
    var self: Builtin = .{};
    errdefer self.deinit(allocator);

    const size_config = ctx.builtin_sizes.get(api.name).?;

    self.name = try casez.allocConvert(allocator, gdzig_case.type, api.name);
    self.module = try casez.allocConvert(allocator, gdzig_case.file, self.name);
    self.name_api = api.name;
    self.size = size_config.size;
    self.doc = if (api.description) |desc| try docs.convertDocsToMarkdown(allocator, desc, ctx, .{
        .verbosity = ctx.config.verbosity,
    }) else null;
    self.has_destructor = api.has_destructor;

    for (api.constructors) |constructor| {
        const function = try Function.fromBuiltinConstructor(allocator, self.name_api, constructor, ctx);
        try self.constructors.put(allocator, function.name, function);
    }

    for (api.enums orelse &.{}) |@"enum"| {
        try self.enums.put(allocator, @"enum".name, try Enum.fromBuiltin(allocator, @"enum"));
    }

    for (api.members orelse &.{}) |member| {
        const member_config = size_config.members.get(member.name);
        try self.fields.put(allocator, member.name, try Field.init(
            allocator,
            member.description,
            member.name,
            member.type,
            if (member_config) |mc| mc.meta else null,
            if (member_config) |mc| mc.offset else null,
            ctx,
        ));
    }

    // Sort fields by offset
    {
        const Ctx = struct {
            fields: []Field,
            pub fn lessThan(c: @This(), a_index: usize, b_index: usize) bool {
                return c.fields[a_index].offset orelse std.math.maxInt(usize) < c.fields[b_index].offset orelse std.math.maxInt(usize);
            }
        };
        self.fields.sort(Ctx{ .fields = self.fields.values() });
    }

    for (api.operators) |operator| {
        // Skip + unary operator
        if (std.mem.eql(u8, "unary+", operator.name)) continue;
        try self.operators.append(allocator, try Function.fromBuiltinOperator(allocator, self.name, operator, ctx));
    }

    for (api.methods orelse &.{}) |method| {
        try self.methods.put(allocator, method.name, try Function.fromBuiltinMethod(allocator, self.name, method, ctx));
    }

    for (api.constants orelse &.{}) |constant| {
        try self.constants.put(allocator, constant.name, try Constant.fromBuiltin(allocator, &self, constant, ctx));
    }

    // find if there is a constructor
    // where every parameter matches the name
    // and type of each field (only count fields with offsets - actual struct fields)
    const field_count = blk: {
        var count: usize = 0;
        for (self.fields.values()) |field| {
            if (field.offset != null) count += 1;
        }
        break :blk count;
    };
    if (field_count > 0) {
        for (self.constructors.values()) |*function| {
            if (function.parameters.count() == field_count) {
                var matched = true;
                // Fields are sorted by offset, so first field_count entries have offsets
                for (0..field_count) |i| {
                    const field = self.fields.entries.get(i);
                    const param = function.parameters.entries.get(i);

                    if (!field.value.type.approxEql(param.value.type)) {
                        matched = false;
                        break;
                    }
                }

                if (matched) {
                    function.can_init_directly = true;

                    for (0..field_count) |i| {
                        const field = self.fields.entries.get(i).value;
                        var param = function.parameters.entries.get(i);
                        param.value.field_name = field.name;
                        param.value.field_type = field.type;

                        function.parameters.entries.set(i, param);
                    }

                    break;
                }
            }
        }
    }

    if (std.mem.eql(u8, api.name, "Callable")) {
        try self.imports.put(allocator, "Object");
    }

    return self;
}

pub fn loadMixinIfExists(self: *Builtin, allocator: Allocator, input_dir: std.fs.Dir) !void {
    const mixin_file_path = try std.fmt.allocPrint(allocator, "builtin/{s}.mixin.zig", .{self.name});
    defer allocator.free(mixin_file_path);

    const file = input_dir.openFile(mixin_file_path, .{}) catch |err| {
        if (err == error.FileNotFound) return;
        std.log.err("Failed to open mixin file '{s}': {}", .{ mixin_file_path, err });
        return err;
    };

    var buf: [4096]u8 = undefined;
    var file_reader = file.reader(&buf);

    const contents = try allocator.allocSentinel(u8, @intCast(try file.getEndPos()), 0);
    try file_reader.interface.readSliceAll(contents);

    // find the @mixin start/stop markers and only parse that section
    const parse_contents: [:0]const u8 = blk: {
        const start_marker = "// @mixin start\n";
        const start_idx = if (std.mem.indexOf(u8, contents, start_marker)) |idx| idx + start_marker.len else 0;
        const stop_idx = if (std.mem.indexOf(u8, contents[start_idx..], "// @mixin stop")) |idx| start_idx + idx else contents.len;
        contents[stop_idx] = 0;
        break :blk contents[start_idx..stop_idx :0];
    };

    var ast = try Ast.parse(allocator, parse_contents, .zig);
    defer ast.deinit(allocator);

    if (ast.errors.len > 0) {
        std.log.err("Failed to parse {s} mixin.", .{self.name});
        return error.ParseError;
    }

    const root_decls = ast.rootDecls();
    for (root_decls) |index| {
        const node = ast.nodes.get(@intFromEnum(index));

        switch (node.tag) {
            .fn_decl => if (try Function.fromMixin(allocator, ast, index)) |result| {
                const fn_type, const function = result;
                switch (fn_type) {
                    .constructor => try self.constructors.put(allocator, function.name, function),
                    .method => try self.methods.put(allocator, function.name, function),
                }
            },
            .simple_var_decl, .aligned_var_decl, .global_var_decl => if (try Constant.fromMixin(allocator, ast, index)) |constant| {
                try self.constants.put(allocator, constant.name_api, constant);

                // If a constructor has the same name, mark it to be skipped during codegen
                if (self.constructors.getPtr(constant.name)) |constructor| {
                    constructor.skip = true;
                }
            },
            else => {},
        }
    }
}

pub fn findConstructorByArgumentCount(self: Builtin, arg_len: usize) ?Function {
    for (self.constructors.values()) |constructor| {
        if (constructor.parameters.count() == arg_len) {
            return constructor;
        }
    }

    return null;
}

pub fn deinit(self: *Builtin, allocator: Allocator) void {
    if (self.doc) |d| allocator.free(d);
    allocator.free(self.module);
    allocator.free(self.name);

    for (self.constants.values()) |*constant| {
        constant.deinit(allocator);
    }
    self.constants.deinit(allocator);

    for (self.constructors.values()) |*constructor| {
        constructor.deinit(allocator);
    }
    self.constructors.deinit(allocator);

    for (self.enums.values()) |*@"enum"| {
        @"enum".deinit(allocator);
    }
    self.enums.deinit(allocator);

    for (self.fields.values()) |*field| {
        field.deinit(allocator);
    }
    self.fields.deinit(allocator);

    for (self.methods.values()) |*method| {
        method.deinit(allocator);
    }
    self.methods.deinit(allocator);

    self.imports.deinit(allocator);

    self.* = .{};
}

const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayListUnmanaged;
const StringArrayHashMap = std.StringArrayHashMapUnmanaged;

const Ast = std.zig.Ast;
const Node = Ast.Node;

const casez = @import("casez");
const common = @import("common");
const gdzig_case = common.gdzig_case;

const Context = @import("../Context.zig");
const Constant = Context.Constant;
const Enum = Context.Enum;
const Field = Context.Field;
const Function = Context.Function;
const Imports = Context.Imports;
const GodotApi = @import("../GodotApi.zig");
const docs = @import("docs.zig");
