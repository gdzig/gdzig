const Flag = @This();

doc: ?[]const u8 = null,
name: []const u8 = "_",
fields: StringArrayHashMap(Field) = .empty,
consts: StringArrayHashMap(Const) = .empty,
padding: u8 = 0,
representation: enum { u32, u64 } = .u32,

pub fn fromGlobalEnum(allocator: Allocator, class_name: ?[]const u8, api: GodotApi.GlobalEnum, ctx: *const Context) !Flag {
    var self: Flag = .{};
    errdefer self.deinit(allocator);

    self.name = try allocator.dupe(u8, api.name);

    var default: i64 = 0;
    var position: u8 = 0;

    for (api.values) |value| {
        if (std.mem.endsWith(u8, value.name, "_DEFAULT")) {
            default = value.value;
            try self.consts.put(allocator, value.name, try .fromGlobalEnum(allocator, class_name, value, ctx));
            continue;
        }

        if (value.value > 0 and std.math.isPowerOfTwo(value.value)) {
            const expected_position = @ctz(value.value);

            // Fill in any missing bit positions with placeholder fields
            while (position < expected_position) : (position += 1) {
                std.debug.print("{s} expected position: {} Actual: {}\n", .{ self.name, expected_position, position });
                const name = try std.fmt.allocPrint(allocator, "@\"{d}\"", .{position});
                try self.fields.put(allocator, name, .{
                    .name = name,
                });
            }

            // Add the field at the correct bit position
            try self.fields.put(allocator, value.name, try .fromGlobalEnum(allocator, class_name, value, ctx, default));
            position += 1;
        } else {
            try self.consts.put(allocator, value.name, try .fromGlobalEnum(allocator, class_name, value, ctx));
        }
    }

    if (position > 32) {
        self.representation = .u64;
    }

    self.padding = switch (self.representation) {
        .u32 => 32 - position,
        .u64 => 64 - position,
    };

    return self;
}

pub fn deinit(self: *Flag, allocator: Allocator) void {
    if (self.doc) |doc| allocator.free(doc);
    allocator.free(self.name);

    for (self.fields.values()) |*value| {
        value.deinit(allocator);
    }
    self.fields.deinit(allocator);

    for (self.consts.values()) |*@"const"| {
        @"const".deinit(allocator);
    }
    self.consts.deinit(allocator);

    self.* = .{};
}

pub const Field = struct {
    doc: ?[]const u8 = null,
    name: []const u8 = "_",
    default: bool = false,

    pub fn fromGlobalEnum(allocator: Allocator, class_name: ?[]const u8, api: GodotApi.GlobalEnum.Value, ctx: *const Context, default: i64) !Field {
        const doc = if (api.description) |desc| try docs.convertDocsToMarkdown(allocator, desc, ctx, .{
            .current_class = class_name,
        }) else null;
        errdefer allocator.free(doc orelse "");

        const name = try case.allocTo(allocator, .snake, api.name);
        errdefer allocator.free(name);

        return Field{
            .doc = doc,
            .name = name,
            .default = default & api.value == api.value,
        };
    }

    pub fn deinit(self: *Field, allocator: Allocator) void {
        if (self.doc) |doc| allocator.free(doc);
        allocator.free(self.name);

        self.* = .{};
    }
};

pub const Const = struct {
    doc: ?[]const u8 = null,
    name: []const u8 = "_",
    value: i64 = 0,

    pub fn fromGlobalEnum(allocator: Allocator, class_name: ?[]const u8, api: GodotApi.GlobalEnum.Value, ctx: *const Context) !Const {
        const doc = if (api.description) |desc| try docs.convertDocsToMarkdown(allocator, desc, ctx, .{
            .current_class = class_name,
        }) else null;
        errdefer allocator.free(doc orelse "");

        const name = try case.allocTo(allocator, .snake, api.name);
        errdefer allocator.free(name);

        return Const{
            .doc = doc,
            .name = name,
            .value = api.value,
        };
    }

    pub fn deinit(self: *Const, allocator: Allocator) void {
        if (self.doc) |doc| allocator.free(doc);
        allocator.free(self.name);

        self.* = .{};
    }
};

const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayListUnmanaged;
const StringArrayHashMap = std.StringArrayHashMapUnmanaged;
const Context = @import("../Context.zig");

const case = @import("case");

const GodotApi = @import("../GodotApi.zig");
const docs = @import("docs.zig");
