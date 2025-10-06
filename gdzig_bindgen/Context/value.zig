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

    pub fn parse(allocator: Allocator, value: []const u8, ctx: *const Context) !Value {
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
                return .{ .string = try allocator.dupe(u8, value[1..index]) };
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
                const c_type = try Type.from(allocator, value[0..index], false, ctx);
                const args_slice = value[index + 1 .. value.len - 1];
                const args_count = std.mem.count(u8, args_slice, ",") + 1;

                var out_args = try allocator.alloc([]const u8, args_count);
                var args_reader = std.Io.Reader.fixed(args_slice);
                for (0..args_count) |i| {
                    const arg = try args_reader.takeDelimiterExclusive(',');
                    out_args[i] = std.mem.trim(u8, arg, &std.ascii.whitespace);
                }

                return .{
                    .constructor = .{
                        .type = c_type,
                        .args = out_args,
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

    var file = try std.fs.cwd().openFile("vendor/extension_api.json", .{});
    defer file.close();

    var buf: [4096]u8 = undefined;
    var file_reader = file.reader(&buf);

    var td: TempDir = try .create(arena.allocator(), .{});
    defer td.deinit();

    var bindings_output = try td.open(.{});
    defer bindings_output.close();

    const parsed_api = try GodotApi.parseFromReader(&arena, &file_reader.interface);
    const ctx: Context = try .build(&arena, parsed_api.value, try Config.testConfig(bindings_output));

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
    try testing.expectEqual(6, transform.constructor.args.len);
    try testing.expectEqualStrings("0", transform.constructor.args[0]);
    try testing.expectEqualStrings("1", transform.constructor.args[1]);
    try testing.expectEqualStrings("2", transform.constructor.args[2]);
    try testing.expectEqualStrings("3", transform.constructor.args[3]);
    try testing.expectEqualStrings("4", transform.constructor.args[4]);
    try testing.expectEqualStrings("5", transform.constructor.args[5]);

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
