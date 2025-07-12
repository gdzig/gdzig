const Enum = @This();

doc: ?[]const u8 = null,
module: []const u8 = "",
name: []const u8 = "_",
name_api: []const u8 = "_",
values: StringHashMap(Value) = .empty,

pub fn fromBuiltin(allocator: Allocator, api: GodotApi.Builtin.Enum) !Enum {
    var self: Enum = .{};
    errdefer self.deinit(allocator);

    self.name = try allocator.dupe(u8, api.name);
    self.name_api = api.name;
    self.module = try case.allocTo(allocator, .snake, self.name);

    for (api.values) |value| {
        try self.values.put(allocator, value.name, try .init(allocator, value.description, value.name, value.value));
    }

    return self;
}

pub fn fromClass(allocator: Allocator, class_name: []const u8, api: GodotApi.Class.Enum, ctx: *const Context) !Enum {
    var self: Enum = .{};
    errdefer self.deinit(allocator);

    self.name = try allocator.dupe(u8, api.name);
    self.name_api = api.name;
    self.module = try case.allocTo(allocator, .snake, self.name);

    for (api.values) |value| {
        const desc = if (value.description) |d| try docs.convertDocsToMarkdown(allocator, d, ctx, .{
            .current_class = class_name,
        }) else null;
        try self.values.put(allocator, value.name, try .init(allocator, desc, value.name, value.value));
    }

    return self;
}

pub fn fromGlobalEnum(allocator: Allocator, class_name: ?[]const u8, api: GodotApi.GlobalEnum, ctx: *const Context) !Enum {
    var self: Enum = .{};
    errdefer self.deinit(allocator);

    self.name = try allocator.dupe(u8, api.name);
    self.name_api = api.name;
    self.module = try case.allocTo(allocator, .snake, self.name);

    for (api.values) |value| {
        const desc = if (value.description) |d| try docs.convertDocsToMarkdown(allocator, d, ctx, .{
            .current_class = class_name,
        }) else null;
        try self.values.put(allocator, value.name, try .init(allocator, desc, value.name, value.value));
    }

    return self;
}

pub fn deinit(self: *Enum, allocator: Allocator) void {
    if (self.doc) |doc| allocator.free(doc);
    allocator.free(self.module);
    allocator.free(self.name);
    var values = self.values.valueIterator();
    while (values.next()) |value| {
        value.deinit(allocator);
    }
    self.values.deinit(allocator);

    self.* = .{};
}

pub const Value = struct {
    doc: ?[]const u8 = null,
    name: []const u8 = "_",
    value: i64 = 0,

    pub fn init(allocator: Allocator, doc: ?[]const u8, name: []const u8, value: i64) !Value {
        var self: Value = .{};
        errdefer self.deinit(allocator);

        self.doc = if (doc) |d| try allocator.dupe(u8, d) else null;
        self.name = try case.allocTo(allocator, .snake, name);
        self.value = value;

        return self;
    }

    pub fn deinit(self: *Value, allocator: Allocator) void {
        if (self.doc) |doc| allocator.free(doc);
        allocator.free(self.name);

        self.* = .{};
    }
};

const std = @import("std");
const Allocator = std.mem.Allocator;
const StringHashMap = std.StringHashMapUnmanaged;
const Context = @import("../Context.zig");

const case = @import("case");

const GodotApi = @import("../GodotApi.zig");
const docs = @import("docs.zig");
