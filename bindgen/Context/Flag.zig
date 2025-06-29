const Flag = @This();

doc: ?[]const u8 = null,
name: []const u8 = "_",
fields: []Field = &.{},
consts: []Const = &.{},
padding: u8 = 0,

pub fn fromGlobalEnum(allocator: Allocator, class_name: ?[]const u8, api: GodotApi.GlobalEnum, ctx: *const Context) !Flag {
    const doc = null;

    const name = try allocator.dupe(u8, api.name);
    errdefer allocator.free(name);

    var fields: ArrayList(Field) = .empty;
    errdefer fields.deinit(allocator);

    var consts: ArrayList(Const) = .empty;
    errdefer consts.deinit(allocator);

    var default: i64 = 0;
    var position: u8 = 0;
    for (api.values) |value| {
        if (std.mem.endsWith(u8, value.name, "_DEFAULT")) {
            default = value.value;
            try consts.append(allocator, try .fromGlobalEnum(allocator, class_name, value, ctx));
            continue;
        }

        if (value.value > 0 and std.math.isPowerOfTwo(value.value)) {
            const expected_position = @ctz(value.value);

            // Fill in any missing bit positions with placeholder fields
            while (position < expected_position) : (position += 1) {
                try fields.append(allocator, .{
                    .doc = null,
                    .name = try std.fmt.allocPrint(allocator, "@\"{d}\"", .{position}),
                    .default = false,
                });
            }

            // Add the field at the correct bit position
            try fields.append(allocator, try .fromGlobalEnum(allocator, class_name, value, ctx, default));
            position += 1;
        } else {
            try consts.append(allocator, try .fromGlobalEnum(allocator, class_name, value, ctx));
        }
    }

    return .{
        .doc = doc,
        .name = name,
        .fields = try fields.toOwnedSlice(allocator),
        .consts = try consts.toOwnedSlice(allocator),
        .padding = 64 - position,
    };
}

pub fn deinit(self: *Flag, allocator: Allocator) void {
    if (self.doc) |doc| allocator.free(doc);
    allocator.free(self.name);
    for (self.fields) |*value| {
        value.deinit(allocator);
    }
    allocator.free(self.fields);
    for (self.consts) |*@"const"| {
        @"const".deinit(allocator);
    }
    allocator.free(self.consts);

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
const Context = @import("../Context.zig");

const case = @import("case");

const GodotApi = @import("../GodotApi.zig");
const docs = @import("docs.zig");
