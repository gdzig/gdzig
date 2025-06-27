const Enum = @This();

doc: ?[]const u8 = null,
name: []const u8,
values: []Value = &.{},

pub fn fromGlobalEnum(allocator: Allocator, api: GodotApi.GlobalEnum) !Enum {
    const name = try allocator.dupe(u8, api.name);
    errdefer allocator.free(name);

    const values = try allocator.alloc(Value, api.values.len);
    errdefer allocator.free(values);

    for (api.values, 0..) |value, i| {
        values[i] = try .fromGlobalEnum(allocator, value);
        errdefer allocator.free(values[i]);
    }

    return Enum{
        .doc = null,
        .name = name,
        .values = values,
    };
}

pub fn deinit(self: *Enum, allocator: Allocator) void {
    allocator.free(self.name);
    allocator.free(self.doc);
    for (self.values) |value| {
        value.deinit(allocator);
    }
    allocator.free(self.values);
}

pub const Value = struct {
    doc: ?[]const u8 = null,
    name: []const u8,
    value: i64,

    pub fn fromGlobalEnum(allocator: Allocator, api: GodotApi.GlobalEnum.Value) !Value {
        const doc = if (api.description) |desc| try docs.convertDocsToMarkdown(allocator, desc) else null;
        errdefer allocator.free(doc orelse "");

        const name = try case.allocTo(allocator, .snake, api.name);
        errdefer allocator.free(name);

        return .{
            .doc = doc,
            .name = name,
            .value = api.value,
        };
    }

    pub fn deinit(self: *Value, allocator: Allocator) void {
        allocator.free(self.doc);
        allocator.free(self.name);
        allocator.free(self.value);
    }
};

const std = @import("std");
const Allocator = std.mem.Allocator;

const case = @import("case");

const GodotApi = @import("../GodotApi.zig");
const docs = @import("docs.zig");
