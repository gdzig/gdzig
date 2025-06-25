pub const Enum = struct {
    doc: ?[]u8 = null,
    name: []u8,
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
            const doc = if (api.description) |desc| try allocator.dupe(u8, desc) else null;
            errdefer allocator.free(doc orelse &.{});

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
};

pub const Flag = struct {
    doc: ?[]const u8 = null,
    name: []const u8,
    fields: []Field = &.{},
    consts: []Const = &.{},
    padding: u8 = 0,

    pub fn fromGlobalEnum(allocator: Allocator, api: GodotApi.GlobalEnum) !Flag {
        const doc = null;

        const name = if (std.mem.endsWith(u8, api.name, "Flags"))
            try allocator.dupe(u8, api.name[0 .. api.name.len - "Flags".len])
        else if (std.mem.endsWith(u8, api.name, "Flag"))
            try allocator.dupe(u8, api.name[0 .. api.name.len - "Flag".len])
        else
            try allocator.dupe(u8, api.name);
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
                try consts.append(allocator, try .fromGlobalEnum(allocator, value));
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
                try fields.append(allocator, try .fromGlobalEnum(allocator, value, default));
                position += 1;
            } else {
                try consts.append(allocator, try .fromGlobalEnum(allocator, value));
            }
        }

        return .{
            .doc = doc,
            .name = name,
            .fields = try fields.toOwnedSlice(allocator),
            .consts = try consts.toOwnedSlice(allocator),
            .padding = 32 - position,
        };
    }

    pub fn deinit(self: *Flag, allocator: Allocator) void {
        allocator.free(self.doc);
        allocator.free(self.name);
        for (self.fields) |value| {
            value.deinit(allocator);
        }
        allocator.free(self.fields);
        for (self.consts) |@"const"| {
            @"const".deinit(allocator);
        }
        allocator.free(self.consts);
    }

    pub const Field = struct {
        doc: ?[]const u8,
        name: []const u8,
        default: bool,

        pub fn fromGlobalEnum(allocator: Allocator, api: GodotApi.GlobalEnum.Value, default: i64) !Field {
            const doc = if (api.description) |desc| try allocator.dupe(u8, desc) else null;
            errdefer allocator.free(doc orelse &.{});

            const name = try case.allocTo(allocator, .snake, api.name);
            errdefer allocator.free(name);

            return Field{
                .doc = doc,
                .name = name,
                .default = default & api.value == api.value,
            };
        }

        pub fn deinit(self: *Field, allocator: Allocator) void {
            allocator.free(self.doc);
            allocator.free(self.name);
        }
    };

    pub const Const = struct {
        doc: ?[]const u8 = null,
        name: []const u8,
        value: i64,

        pub fn fromGlobalEnum(allocator: Allocator, api: GodotApi.GlobalEnum.Value) !Const {
            const doc = if (api.description) |desc| try allocator.dupe(u8, desc) else null;
            errdefer allocator.free(doc orelse &.{});

            const name = try case.allocTo(allocator, .snake, api.name);
            errdefer allocator.free(name);

            return Const{
                .doc = doc,
                .name = name,
                .value = api.value,
            };
        }

        pub fn deinit(self: *Const, allocator: Allocator) void {
            allocator.free(self.doc);
            allocator.free(self.name);
        }
    };
};

const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayListUnmanaged;

const case = @import("case");

pub const GodotApi = @import("GodotApi.zig");
