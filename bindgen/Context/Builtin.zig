const Builtin = @This();

doc: ?[]const u8 = null,
name: []const u8 = "_",
api_name: []const u8 = "_",

size: usize = 0,

has_destructor: bool = false,

constants: StringHashMap(Constant) = .empty,
constructors: ArrayList(Function) = .empty,
enums: StringHashMap(Enum) = .empty,
fields: StringArrayHashMap(Field) = .empty,
methods: StringHashMap(Function) = .empty,

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
    self.api_name = api.name;
    self.size = size_config.size;
    self.doc = if (api.description) |desc| try docs.convertDocsToMarkdown(allocator, desc, ctx, .{}) else null;
    self.has_destructor = api.has_destructor;

    for (api.constants orelse &.{}) |constant| {
        try self.constants.put(allocator, constant.name, try Constant.fromBuiltin(allocator, constant, ctx));
    }

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

    for (api.methods orelse &.{}) |method| {
        try self.methods.put(allocator, method.name, try Function.fromBuiltinMethod(allocator, self.name, method, ctx));
    }

    return self;
}

pub fn deinit(self: *Builtin, allocator: Allocator) void {
    if (self.doc) |d| allocator.free(d);
    allocator.free(self.name);

    var constants = self.constants.valueIterator();
    while (constants.next()) |constant| {
        constant.deinit(allocator);
    }
    self.constants.deinit(allocator);

    for (self.constructors.items) |*constructor| {
        constructor.deinit(allocator);
    }
    self.constructors.deinit(allocator);

    var enums = self.enums.valueIterator();
    while (enums.next()) |@"enum"| {
        @"enum".deinit(allocator);
    }
    self.enums.deinit(allocator);

    for (self.fields.values()) |*field| {
        field.deinit(allocator);
    }
    self.fields.deinit(allocator);

    var methods = self.methods.valueIterator();
    while (methods.next()) |method| {
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
const StringHashMap = std.StringHashMapUnmanaged;

const Context = @import("../Context.zig");
const Constant = Context.Constant;
const Enum = Context.Enum;
const Field = Context.Field;
const Function = Context.Function;
const Imports = Context.Imports;
const GodotApi = @import("../GodotApi.zig");
const docs = @import("docs.zig");
