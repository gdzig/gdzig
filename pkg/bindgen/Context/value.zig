const ValueType = enum {
    null,
    string,
    string_name,
    boolean,
    primitive,
    constructor,
};

pub const Value = union(ValueType) {
    null: void,
    string: []const u8,
    string_name: []const u8,
    boolean: bool,
    primitive: []const u8,
    constructor: struct {
        type: Type,
        args: []const []const u8,
    },

    pub fn isNullable(self: Value) bool {
        return self == .null;
    }

    pub fn needsRuntimeInit(self: Value, ctx: *const Context) bool {
        switch (self) {
            .string, .string_name => return true,
            .constructor => |c| {
                const type_name = switch (c.type) {
                    .basic => |name| name,
                    else => return false,
                };

                const builtin = ctx.builtins.get(type_name) orelse return false;
                const constructor = builtin.findConstructorByArgumentCount(c.args.len) orelse return false;
                return !constructor.can_init_directly;
            },
            else => return false,
        }
    }

    pub fn runtimeInitNeedsDeinit(self: Value) bool {
        return self == .string or self == .string_name;
    }

    pub fn parse(arena: Allocator, value: []const u8, ctx: *const Context) !Value {
        if (value.len == 0 or std.mem.eql(u8, value, "null")) {
            return .null;
        }

        if (std.mem.eql(u8, value, "\"\"") or std.mem.eql(u8, value, "&\"\"")) {
            return .null;
        }
        if (value[0] == '"') {
            return .{ .string = try std.zig.string_literal.parseAlloc(arena, value) };
        }
        if (std.mem.startsWith(u8, value, "&\"") and value[value.len - 1] == '"') {
            return .{ .string_name = try std.zig.string_literal.parseAlloc(arena, value[1..]) };
        }

        if (std.mem.eql(u8, value, "true")) {
            return .{ .boolean = true };
        }
        if (std.mem.eql(u8, value, "false")) {
            return .{ .boolean = false };
        }

        if (value[value.len - 1] == ')') {
            if (std.mem.indexOf(u8, value, "(")) |index| {
                const c_name = value[0..index];
                const c_type = try Type.from(arena, c_name, false, ctx);
                const args_slice = value[index + 1 .. value.len - 1];
                const args_count = std.mem.count(u8, args_slice, ",") + 1;

                var out_args: ?[]const []const u8 = null;
                if (args_slice.len > 0) {
                    const temp = try arena.alloc([]const u8, args_count);

                    var it = std.mem.splitScalar(u8, args_slice, ',');
                    var i: usize = 0;
                    while (it.next()) |raw_arg| : (i += 1) {
                        temp[i] = std.mem.trim(u8, raw_arg, " \t\r\n,");
                    }

                    out_args = temp;
                }

                return .{
                    .constructor = .{
                        .type = c_type,
                        .args = out_args orelse &.{},
                    },
                };
            }
        }

        return .{ .primitive = value };
    }
};

const std = @import("std");
const Allocator = std.mem.Allocator;

const Context = @import("../Context.zig");
const Type = Context.Type;
