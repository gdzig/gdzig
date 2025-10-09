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

                    if (args_count == 1) {
                        temp[0] = std.mem.trim(u8, args_slice, &std.ascii.whitespace);
                    } else {
                        var args_reader = std.Io.Reader.fixed(args_slice);
                        for (0..args_count) |i| {
                            const arg = try args_reader.takeDelimiterExclusive(',');
                            temp[i] = std.mem.trim(u8, arg, &std.ascii.whitespace);
                        }
                        out_args = temp;
                    }
                }

                return .{
                    .constructor = .{
                        .type = c_type,
                        .args = out_args orelse &.{},
                    },
                };
            }
        }

        // primitive
        return .{ .primitive = value };
    }
};

const testing = std.testing;

test Value {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();

    var td: TempDir = try .create(arena.allocator(), .{});
    defer td.deinit();

    var bindings_output = try td.open(.{});
    defer bindings_output.close();

    var config = try Config.testConfig(bindings_output);

    var buf: [4096]u8 = undefined;
    var extension_api_reader = config.extension_api.reader(&buf);

    const parsed_api = try GodotApi.parseFromReader(&arena, &extension_api_reader.interface);
    const ctx: Context = try .build(&arena, parsed_api.value, config);

    const null_value: Value = try .parse(arena.allocator(), "null", &ctx);
    try testing.expectEqual(.null, null_value);

    const empty: Value = try .parse(arena.allocator(), "", &ctx);
    try testing.expectEqual(.null, empty);

    const empty_string: Value = try .parse(arena.allocator(), "\"\"", &ctx);
    try testing.expectEqual(.null, empty_string);

    const string: Value = try .parse(arena.allocator(), "\"Hello\"", &ctx);
    try testing.expect(string == .string);
    try testing.expectEqualStrings("Hello", string.string);

    const transform: Value = try .parse(arena.allocator(), "Transform2D(0, 1, 2, 3, 4, 5)", &ctx);
    try testing.expect(transform == .constructor);
    try testing.expect(transform.constructor.type == .basic);
    try testing.expectEqualStrings("Transform2D", transform.constructor.type.basic);
    // Transform2D(0,1,2,3,4,5) with 6 args gets transformed into 3 Vector2.initXY() calls
    try testing.expectEqual(3, transform.constructor.args.len);
    try testing.expectEqualStrings(".initXY(0, 1)", transform.constructor.args[0]);
    try testing.expectEqualStrings(".initXY(2, 3)", transform.constructor.args[1]);
    try testing.expectEqualStrings(".initXY(4, 5)", transform.constructor.args[2]);

    const primitive: Value = try .parse(arena.allocator(), "123", &ctx);
    try testing.expect(primitive == .primitive);
    try testing.expectEqual(primitive.primitive, "123");
}

const std = @import("std");
const Allocator = std.mem.Allocator;

const TempDir = @import("temp").TempDir;
const Config = @import("../Config.zig");
const Context = @import("../Context.zig");
const Type = Context.Type;
const GodotApi = @import("../GodotApi.zig");
