const Builtin = @This();

doc: ?[]const u8 = null,
module: []const u8 = "",
name: []const u8 = "_",
name_api: []const u8 = "_",

size: usize = 0,

has_destructor: bool = false,

constants: StringArrayHashMap(Constant) = .empty,
constructors: ArrayList(Function) = .empty,
enums: StringArrayHashMap(Enum) = .empty,
fields: StringArrayHashMap(Field) = .empty,
methods: StringArrayHashMap(Function) = .empty,
operators: ArrayList(Function) = .empty,

imports: Imports = .empty,

pub fn fromApi(allocator: Allocator, api: GodotApi.Builtin, ctx: *const Context) !Builtin {
    var self: Builtin = .{};
    errdefer self.deinit(allocator);

    const size_config = ctx.builtin_sizes.get(api.name).?;

    self.name = blk: {
        // TODO: case conversion
        // break try case.allocTo(allocator, .pascal, api.name);
        break :blk try allocator.dupe(u8, api.name);
    };
    self.module = try case.allocTo(allocator, .snake, self.name);
    self.name_api = api.name;
    self.size = size_config.size;
    self.doc = if (api.description) |desc| try docs.convertDocsToMarkdown(allocator, desc, ctx, .{}) else null;
    self.has_destructor = api.has_destructor;

    for (api.constructors) |constructor| {
        try self.constructors.append(allocator, try Function.fromBuiltinConstructor(allocator, self.name, constructor, ctx));
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

    for (api.constants orelse &.{}) |constant| {
        try self.constants.put(allocator, constant.name, try Constant.fromBuiltin(allocator, &self, constant, ctx));
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

    // find if there is a constructor
    // where every parameter matches the name
    // and type of each field
    const field_count = self.fields.count();
    if (field_count > 0) {
        for (self.constructors.items) |*function| {
            if (function.parameters.count() == field_count) {
                for (0..field_count) |i| {
                    const field = self.fields.entries.get(i);
                    const param = function.parameters.entries.get(i);

                    if (!std.mem.eql(u8, field.value.name_api, param.value.name_api)) {
                        continue;
                    }

                    if (!field.value.type.eql(param.value.type)) {
                        continue;
                    }
                }

                function.can_init_directly = true;

                for (0..field_count) |i| {
                    const field = self.fields.entries.get(i).value;
                    var param = function.parameters.entries.get(i);
                    param.value.field_name = field.name;

                    function.parameters.entries.set(i, param);
                }

                break;
            }
        }
    }

    return self;
}

pub fn deinit(self: *Builtin, allocator: Allocator) void {
    if (self.doc) |d| allocator.free(d);
    allocator.free(self.module);
    allocator.free(self.name);

    for (self.constants.values()) |*constant| {
        constant.deinit(allocator);
    }
    self.constants.deinit(allocator);

    for (self.constructors.items) |*constructor| {
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

const case = @import("case");

const Context = @import("../Context.zig");
const Constant = Context.Constant;
const Enum = Context.Enum;
const Field = Context.Field;
const Function = Context.Function;
const Imports = Context.Imports;
const GodotApi = @import("../GodotApi.zig");
const docs = @import("docs.zig");
