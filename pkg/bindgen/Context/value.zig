const ValueType = enum {
    null,
    string,
    boolean,
    primitive,
    constructor,
};

pub const Value = union(ValueType) {
    null: void,
    string: []const u8,
    boolean: bool,
    primitive: []const u8,
    constructor: struct {
        type: Type,
        args: []const []const u8,
    },

    pub fn isNullable(self: Value) bool {
        return self == .null or self == .string;
    }

    pub fn needsRuntimeInit(self: Value, ctx: *const Context) bool {
        switch (self) {
            .constructor => |c| {
                // Extract the type name from the constructor type
                const type_name = switch (c.type) {
                    .basic => |name| name,
                    else => return false, // Only builtin types can have constructors
                };

                // Look up the builtin type
                const builtin = ctx.builtins.get(type_name) orelse return false;

                // Find the constructor with matching argument count
                const constructor = builtin.findConstructorByArgumentCount(c.args.len) orelse return false;

                // Return true if the constructor cannot be initialized directly (needs runtime init)
                return !constructor.can_init_directly;
            },
            else => return false,
        }
    }

    pub fn parse(arena: Allocator, value: []const u8, ctx: *const Context) !Value {
        // null
        if (value.len == 0) {
            return .null;
        }
        if (std.mem.eql(u8, value, "null")) {
            return .null;
        }

        // string
        if (value[0] == '"') {
            // empty string
            if (value[1] == '"' and value.len == 2) {
                return .null;
            }

            if (std.mem.lastIndexOf(u8, value, "\"")) |index| {
                return .{ .string = try arena.dupe(u8, value[1..index]) };
            }

            unreachable;
        }

        // boolean
        if (std.mem.eql(u8, value, "true")) {
            return .{ .boolean = true };
        }
        if (std.mem.eql(u8, value, "false")) {
            return .{ .boolean = false };
        }

        // constructor
        if (value[value.len - 1] == ')') {
            if (std.mem.indexOf(u8, value, "(")) |index| {
                const c_name = value[0..index];
                const c_type = try Type.from(arena, c_name, false, ctx);
                const args_slice = value[index + 1 .. value.len - 1];
                const args_count = std.mem.count(u8, args_slice, ",") + 1;

                var out_args: ?[]const []const u8 = null;
                if (args_slice.len > 0) {
                    var temp = try arena.alloc([]const u8, args_count);

                    var it = std.mem.splitScalar(u8, args_slice, ',');
                    var i: usize = 0;
                    while (it.next()) |raw_arg| : (i += 1) {
                        // trim whitespace + comma (the comma matters if you later switch this code)
                        temp[i] = std.mem.trim(u8, raw_arg, " \t\r\n,");
                    }

                    out_args = temp;
                }

                return .{
                    .constructor = .{
                        .type = c_type,
                        .args = out_args orelse &.{}, // empty when args_slice == ""
                    },
                };
            }
        }

        // primitive
        return .{ .primitive = value };
    }
};

const std = @import("std");
const Allocator = std.mem.Allocator;

const TempDir = @import("temp").TempDir;
const Config = @import("../Config.zig");
const Context = @import("../Context.zig");
const Type = Context.Type;
const GodotApi = @import("../GodotApi.zig");
