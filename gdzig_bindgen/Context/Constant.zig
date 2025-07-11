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
value: []const u8 = "{}",

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
    });
    self.value = blk: {
        // default value with value constructor
        if (std.mem.indexOf(u8, api.value, "(")) |idx| {
            var split_args = std.mem.splitSequence(u8, api.value[idx + 1 .. api.value.len - 1], ", ");

            var args: ArrayList([]const u8) = .empty;
            defer args.deinit(ctx.rawAllocator());
            while (split_args.next()) |arg| {
                try args.append(ctx.rawAllocator(), std.mem.trim(u8, arg, &std.ascii.whitespace));
            }
            const arg_count = args.items.len;

            // find constructor with same arg count
            for (builtin.constructors.items) |function| {
                if (function.parameters.count() == arg_count) {
                    var output: ArrayList(u8) = .empty;
                    var writer = output.writer(allocator);
                    try writer.writeAll(function.name);

                    try writer.writeAll("(");
                    for (args.items, 0..) |arg, i| {
                        var pval = arg;
                        if (std.mem.eql(u8, pval, "inf")) {
                            pval = comptime "std.math.inf(" ++ (if (std.mem.eql(u8, build_options.precision, "double")) "f64" else "f32") ++ ")";
                        }

                        try writer.writeAll(pval);

                        if (i != args.items.len - 1) {
                            try writer.writeAll(", ");
                        }
                    }
                    try writer.writeAll(")");

                    break :blk try output.toOwnedSlice(allocator);
                }
            }

            // fallback for missing constructors
            if (std.meta.stringToEnum(MissingConstructors, api.type)) |value| switch (value) {
                .Transform2D => {
                    if (arg_count == 6) {
                        const fmt =
                            \\initXAxisYAxisOrigin(
                            \\    .initXY({s}, {s}),
                            \\    .initXY({s}, {s}),
                            \\    .initXY({s}, {s})
                            \\)
                        ;

                        break :blk try std.fmt.allocPrint(allocator, fmt, .{
                            args.items[0],
                            args.items[1],
                            args.items[2],
                            args.items[3],
                            args.items[4],
                            args.items[5],
                        });
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

                        break :blk try std.fmt.allocPrint(allocator, fmt, .{
                            args.items[0],
                            args.items[1],
                            args.items[2],
                            args.items[3],
                            args.items[4],
                            args.items[5],
                            args.items[6],
                            args.items[7],
                            args.items[8],
                            args.items[9],
                            args.items[10],
                            args.items[11],
                        });
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

                        break :blk try std.fmt.allocPrint(allocator, fmt, .{
                            args.items[0],
                            args.items[1],
                            args.items[2],
                            args.items[3],
                            args.items[4],
                            args.items[5],
                            args.items[6],
                            args.items[7],
                            args.items[8],
                        });
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

                        break :blk try std.fmt.allocPrint(allocator, fmt, .{
                            args.items[0],
                            args.items[1],
                            args.items[2],
                            args.items[3],
                            args.items[4],
                            args.items[5],
                            args.items[6],
                            args.items[7],
                            args.items[8],
                            args.items[9],
                            args.items[10],
                            args.items[11],
                            args.items[12],
                            args.items[13],
                            args.items[14],
                            args.items[15],
                        });
                    }
                },
            };
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

const Type = Context.Type;
const Builtin = Context.Builtin;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayListUnmanaged;
const Context = @import("../Context.zig");
const GodotApi = @import("../GodotApi.zig");

const std = @import("std");
const case = @import("case");
const docs = @import("docs.zig");
const build_options = @import("build_options");
