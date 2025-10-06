const Constant = @This();

const MissingConstructors = enum {
    Transform2D,
    Transform3D,
    Basis,
    Projection,
};

doc: ?[]const u8 = null,
name: []const u8 = "_",
type: Type = .void,
value: []const u8 = "comptime unreachable",

pub const replacements: std.StaticStringMap([]const u8) = .initComptime(.{
    .{ "inf", "std.math.inf(" ++ (if (std.mem.eql(u8, build_options.precision, "double")) "f64" else "f32") ++ ")" },
});

pub fn fromBuiltin(allocator: Allocator, builtin: *const Builtin, api: GodotApi.Builtin.Constant, ctx: *const Context) !Constant {
    var self: Constant = .{};
    errdefer self.deinit(allocator);

    self.name = name: {
        const name = try case.allocTo(allocator, .snake, api.name);
        if (builtin.methods.contains(name)) {
            const n = try std.fmt.allocPrint(allocator, "{s}_", .{name});
            std.debug.assert(!builtin.methods.contains(n));
            break :name n;
        }
        break :name name;
    };
    self.type = try Type.from(allocator, api.type, false, ctx);
    self.doc = try docs.convertDocsToMarkdown(allocator, api.description, ctx, .{
        .current_class = builtin.name_api,
        .verbosity = ctx.config.verbosity,
    });
    self.value = blk: {
        const default_value: Value = try .parse(allocator, api.value, ctx);
        switch (default_value) {
            .constructor => |c| {
                const args = c.args;
                const arg_count = args.len;

                if (builtin.findConstructorByArgumentCount(arg_count)) |function| {
                    var output = std.Io.Writer.Allocating.init(allocator);
                    var writer = &output.writer;
                    try writer.writeAll(function.name);

                    try writer.writeAll("(");
                    for (args, 0..) |arg, i| {
                        const pval = replacements.get(arg) orelse arg;
                        try writer.writeAll(pval);

                        if (i != arg_count - 1) {
                            try writer.writeAll(", ");
                        }
                    }
                    try writer.writeAll(")");

                    break :blk output.written();
                }

                // fallback for missing constructors
                if (std.meta.stringToEnum(Builtin.MissingConstructors, api.type)) |value| switch (value) {
                    .Transform2D => {
                        if (arg_count == 6) {
                            const fmt =
                                \\initXAxisYAxisOrigin(
                                \\    .initXY({s}, {s}),
                                \\    .initXY({s}, {s}),
                                \\    .initXY({s}, {s})
                                \\)
                            ;

                            break :blk try std.fmt.allocPrint(allocator, fmt, buildTupleFromArray(args, 6));
                        }
                    },
                    .Transform3D => {
                        if (arg_count == 12) {
                            const fmt =
                                \\initXAxisYAxisZAxisOrigin(
                                \\    .initXYZ({s}, {s}, {s}),
                                \\    .initXYZ({s}, {s}, {s}),
                                \\    .initXYZ({s}, {s}, {s}),
                                \\    .initXYZ({s}, {s}, {s})
                                \\)
                            ;

                            break :blk try std.fmt.allocPrint(allocator, fmt, buildTupleFromArray(args, 12));
                        }
                    },
                    .Basis => {
                        if (arg_count == 9) {
                            const fmt =
                                \\initXAxisYAxisZAxis(
                                \\    .initXYZ({s}, {s}, {s}),
                                \\    .initXYZ({s}, {s}, {s}),
                                \\    .initXYZ({s}, {s}, {s})
                                \\)
                            ;

                            break :blk try std.fmt.allocPrint(allocator, fmt, buildTupleFromArray(args, 9));
                        }
                    },
                    .Projection => {
                        if (arg_count == 16) {
                            const fmt =
                                \\initXAxisYAxisZAxisWAxis(
                                \\    .initXYZW({s}, {s}, {s}, {s}),
                                \\    .initXYZW({s}, {s}, {s}, {s}),
                                \\    .initXYZW({s}, {s}, {s}, {s}),
                                \\    .initXYZW({s}, {s}, {s}, {s})
                                \\)
                            ;

                            break :blk try std.fmt.allocPrint(allocator, fmt, buildTupleFromArray(args, 16));
                        }
                    },
                };
            },
            else => {},
        }

        break :blk try allocator.dupe(u8, api.value);
    };

    return self;
}

pub fn fromClass(allocator: Allocator, api: GodotApi.Class.Constant, ctx: *const Context) !Constant {
    var self: Constant = .{};
    errdefer self.deinit(allocator);

    // TODO: normalization
    self.name = try allocator.dupe(u8, api.name);
    self.type = try .from(allocator, "int", false, ctx);
    self.value = try std.fmt.allocPrint(allocator, "{d}", .{api.value});

    return self;
}

pub fn deinit(self: *Constant, allocator: Allocator) void {
    if (self.doc) |doc| allocator.free(doc);
    allocator.free(self.name);
    self.type.deinit(allocator);
    allocator.free(self.value);

    self.* = .{};
}

// https://ziggit.dev/t/comptime-code-to-create-a-tuple-from-an-array/11329/3
fn BuildTupleFromArray(comptime Array: type, comptime len: usize) type {
    const Element = std.meta.Elem(Array);
    const types_array: [len]type = @splat(Element);
    return std.meta.Tuple(&types_array);
}

fn buildTupleFromArray(array: anytype, comptime len: usize) BuildTupleFromArray(@TypeOf(array), len) {
    var a: BuildTupleFromArray(@TypeOf(array), len) = undefined;
    inline for (array, 0..len) |value, i| {
        a[i] = value;
    }
    return a;
}

const Type = Context.Type;
const Builtin = Context.Builtin;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayListUnmanaged;
const Context = @import("../Context.zig");
const GodotApi = @import("../GodotApi.zig");
const Value = @import("value.zig").Value;

const std = @import("std");
const case = @import("case");
const docs = @import("docs.zig");
const build_options = @import("build_options");
