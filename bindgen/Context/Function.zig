const Function = @This();

doc: ?[]const u8 = null,
name: []const u8 = "_",
name_api: []const u8 = "_",

/// The name of the parent type that this function belongs to.
base: ?[]const u8 = null,

index: ?usize = null,
hash: ?u64 = null,

// When the function is an operator, this is the name of the operator.
operator_name: ?[]const u8 = null,

parameters: StringArrayHashMap(Parameter) = .empty,
return_type: Type = .void,
return_type_initializer: ?[]const u8 = null,

/// The override behavior of the function, in object-oriented terms.
mode: Mode = .final,
self: union(enum) {
    /// This function takes no instance.
    static: void,
    /// This function takes a singleton instance.
    singleton: void,
    /// This function takes a constant self pointer.
    constant: []const u8,
    /// This function takes a mutable self pointer.
    mutable: []const u8,
    /// This function takes self by value.
    value: []const u8,
} = .static,
is_vararg: bool = false,

/// When true, this constructor can be implemented via direct struct initialization
/// instead of calling the GDExtension API, which enables comptime initialization.
can_init_directly: bool = false,

/// This maps the API's operator name to a function name
const operator_fn_names: StaticStringMap([]const u8) = .initComptime(.{
    .{ "+", "add" },
    .{ "&", "band" },
    .{ "~", "bnot" },
    .{ "|", "bor" },
    .{ "/", "div" },
    .{ "==", "eql" },
    .{ ">", "gt" },
    .{ ">=", "gtEql" },
    .{ "in", "in" },
    .{ "and", "land" },
    .{ "<", "lt" },
    .{ "<=", "ltEql" },
    .{ "or", "lor" },
    .{ "%", "mod" },
    .{ "*", "mul" },
    .{ "unary-", "negate" },
    .{ "!=", "notEql" },
    .{ "not", "not" },
    .{ "**", "power" },
    .{ "<<", "shl" },
    .{ ">>", "shr" },
    .{ "-", "sub" },
    .{ "^", "xor" },
    .{ "xor", "xor" },
});

/// This maps the API's operator name to the Variant.Operator tag name
const operator_enum_names = StaticStringMap([]const u8).initComptime(.{
    .{ "==", "equal" },
    .{ "!=", "not_equal" },
    .{ "<", "less" },
    .{ "<=", "less_equal" },
    .{ ">", "greater" },
    .{ ">=", "greater_equal" },
    .{ "+", "add" },
    .{ "-", "subtract" },
    .{ "*", "multiply" },
    .{ "/", "divide" },
    .{ "unary-", "negate" },
    .{ "%", "module" },
    .{ "**", "power" },
    .{ "<<", "shift_left" },
    .{ ">>", "shift_right" },
    .{ "&", "bit_and" },
    .{ "|", "bit_or" },
    .{ "^", "bit_xor" },
    .{ "~", "bit_negate" },
    .{ "and", "@\"and\"" },
    .{ "or", "@\"or\"" },
    .{ "xor", "xor" },
    .{ "not", "not" },
    .{ "in", "in" },
});

pub fn fromBuiltinOperator(allocator: Allocator, builtin_name: []const u8, api: GodotApi.Builtin.Operator, ctx: *const Context) !Function {
    var self: Function = .{};

    self.doc = if (api.description) |doc| try docs.convertDocsToMarkdown(allocator, doc, ctx, .{
        .current_class = builtin_name,
    }) else null;
    self.name = blk: {
        var buf: ArrayList(u8) = .empty;
        errdefer buf.deinit(allocator);
        try buf.appendSlice(allocator, operator_fn_names.get(api.name).?);

        var stream = std.io.fixedBufferStream(api.right_type);
        var reader = stream.reader();
        var writer = buf.writer(allocator);

        try case.to(.pascal, &reader, &writer);

        if (std.mem.endsWith(u8, buf.items, builtin_name)) {
            buf.shrinkAndFree(allocator, buf.items.len - builtin_name.len);
        }

        break :blk try buf.toOwnedSlice(allocator);
    };
    self.name_api = api.name;

    self.operator_name = operator_enum_names.get(api.name).?;

    const right_type = if (api.right_type.len > 0) try Type.from(allocator, api.right_type, false, ctx) else null;
    if (right_type) |rhs| {
        try self.parameters.put(allocator, "rhs", .{
            .name = "rhs",
            .type = rhs,
        });
    }
    self.return_type = try Type.from(allocator, api.return_type, false, ctx);

    self.mode = .final;
    self.self = .{ .constant = builtin_name };
    self.is_vararg = false;
    self.return_type_initializer = getReturnTypeInitializer(self.return_type);

    return self;
}

pub fn fromBuiltinConstructor(allocator: Allocator, builtin_name: []const u8, constructor: GodotApi.Builtin.Constructor, ctx: *const Context) !Function {
    var self = Function{};
    errdefer self.deinit(allocator);

    self.doc = if (constructor.description) |doc| try docs.convertDocsToMarkdown(allocator, doc, ctx, .{
        .current_class = builtin_name,
    }) else null;

    self.name = blk: {
        var buf: ArrayList(u8) = .empty;
        errdefer buf.deinit(allocator);

        var args = constructor.arguments orelse &.{};

        if (args.len == 1 and std.mem.eql(u8, builtin_name, args[0].type)) {
            try buf.appendSlice(allocator, "copy");
            break :blk try buf.toOwnedSlice(allocator);
        } else if (args.len > 0 and std.mem.eql(u8, "from", args[0].name)) {
            try buf.appendSlice(allocator, "from");
            var stream = std.io.fixedBufferStream(args[0].type);
            var reader = stream.reader();
            var writer = buf.writer(allocator);
            try case.to(.pascal, &reader, &writer);
            args = args[1..];
        } else {
            try buf.appendSlice(allocator, "init");
        }

        for (args) |arg| {
            var stream = std.io.fixedBufferStream(arg.name);
            var reader = stream.reader();
            var writer = buf.writer(allocator);
            try case.to(.pascal, &reader, &writer);
        }

        break :blk try buf.toOwnedSlice(allocator);
    };

    self.index = @intCast(constructor.index);

    for (constructor.arguments orelse &.{}) |arg| {
        try self.parameters.put(allocator, arg.name, try .fromNameType(allocator, arg.name, arg.type, false, ctx, .{}));
    }

    self.return_type = try .from(allocator, builtin_name, false, ctx);
    self.base = builtin_name;

    return self;
}

pub fn fromBuiltinMethod(allocator: Allocator, builtin_name: []const u8, api: GodotApi.Builtin.Method, ctx: *const Context) !Function {
    var self = Function{};
    errdefer self.deinit(allocator);

    self.doc = if (api.description) |doc| try docs.convertDocsToMarkdown(allocator, doc, ctx, .{
        .current_class = builtin_name,
    }) else null;
    self.name = try case.allocTo(allocator, .camel, api.name);
    self.name_api = api.name;
    self.hash = api.hash;
    self.self = if (api.is_static)
        .static
    else if (api.is_const)
        .{ .constant = builtin_name }
    else
        .{ .mutable = builtin_name };
    self.is_vararg = api.is_vararg;
    self.base = builtin_name;

    for (api.arguments orelse &.{}) |arg| {
        const parameter: Parameter = if (arg.default_value.len > 0)
            try .fromNameTypeDefault(allocator, arg.name, arg.type, false, arg.default_value, ctx)
        else
            try .fromNameType(allocator, arg.name, arg.type, false, ctx, .{});
        try self.parameters.put(allocator, arg.name, parameter);
    }
    self.return_type = try .from(allocator, api.return_type, false, ctx);
    self.return_type_initializer = getReturnTypeInitializer(self.return_type);

    return self;
}

pub fn fromClass(allocator: Allocator, class_name: []const u8, has_singleton: bool, api: GodotApi.Class.Method, ctx: *const Context) !Function {
    var self = Function{};
    errdefer self.deinit(allocator);

    self.doc = if (api.description) |doc| try docs.convertDocsToMarkdown(allocator, doc, ctx, .{
        .current_class = class_name,
    }) else null;
    self.name = blk: {
        if (!api.is_virtual) {
            break :blk try case.allocTo(allocator, .camel, api.name);
        }

        // Strip the underscore prefix, camelize the rest, then reapply the underscore prefix
        var buf: ArrayList(u8) = try .initCapacity(allocator, api.name.len);
        errdefer buf.deinit(allocator);
        buf.appendAssumeCapacity('_');

        var stream = std.io.fixedBufferStream(api.name[1..]);
        var reader = stream.reader();
        var writer = buf.writer(allocator);

        try case.to(.camel, &reader, &writer);

        break :blk try buf.toOwnedSlice(allocator);
    };
    self.name_api = api.name;
    self.base = class_name;
    self.hash = api.hash;
    self.mode = if (!api.is_virtual) .final else if (api.is_required) .abstract else .virtual;
    self.self = if (api.is_static)
        .static
    else if (has_singleton)
        .singleton
    else if (api.is_const)
        .{ .constant = class_name }
    else
        .{ .mutable = class_name };
    self.is_vararg = api.is_vararg;

    for (api.arguments orelse &.{}) |arg| {
        const parameter: Parameter = if (arg.default_value.len > 0)
            try .fromNameTypeDefault(
                allocator,
                arg.name,
                if (arg.meta.len > 0) arg.meta else arg.type,
                arg.meta.len > 0,
                arg.default_value,
                ctx,
            )
        else
            try .fromNameType(
                allocator,
                arg.name,
                if (arg.meta.len > 0) arg.meta else arg.type,
                arg.meta.len > 0,
                ctx,
                .{},
            );
        try self.parameters.put(allocator, arg.name, parameter);
    }

    self.return_type = if (api.return_value) |rv|
        try .from(
            allocator,
            if (rv.meta.len > 0) rv.meta else rv.type,
            rv.meta.len > 0,
            ctx,
        )
    else
        .void;

    self.return_type_initializer = getReturnTypeInitializer(self.return_type);

    // TODO: default return values? rv.default_value

    return self;
}

pub fn fromClassGetter(allocator: Allocator, class_name: []const u8, name: []const u8, @"type": Type, is_singleton: bool) !Function {
    var self: Function = .{};
    errdefer self.deinit(allocator);

    self.name = try case.allocTo(allocator, .camel, name);
    self.name_api = name;
    self.base = class_name;
    self.self = if (is_singleton) .singleton else .{ .constant = class_name };
    self.is_vararg = false;
    self.parameters = .{};
    self.return_type = @"type";

    return self;
}

pub fn fromClassSetter(allocator: Allocator, class_name: []const u8, is_singleton: bool, name: []const u8, @"type": Type) !Function {
    var self: Function = .{};
    errdefer self.deinit(allocator);

    self.name = try case.allocTo(allocator, .camel, name);
    self.name_api = name;
    self.base = class_name;
    self.self = if (is_singleton) .singleton else .{ .mutable = class_name };
    self.is_vararg = false;
    self.return_type = .void;

    try self.parameters.put(allocator, "value", .{
        .name = "value",
        .type = @"type",
    });

    return self;
}

pub fn fromUtilityFunction(allocator: Allocator, function: GodotApi.UtilityFunction, ctx: *const Context) !Function {
    var self: Function = .{};
    errdefer self.deinit(allocator);

    self.doc = if (function.description) |desc| try docs.convertDocsToMarkdown(allocator, desc, ctx, .{}) else null;
    self.name = try case.allocTo(allocator, .camel, function.name);
    self.name_api = function.name;
    self.hash = function.hash;
    self.self = .static;
    self.is_vararg = function.is_vararg;
    for (function.arguments orelse &.{}) |arg| {
        try self.parameters.put(allocator, arg.name, try .fromNameType(allocator, arg.name, arg.type, false, ctx, .{}));
    }
    self.return_type = if (function.return_type.len > 0) try .from(allocator, function.return_type, false, ctx) else .void;

    return self;
}

pub fn deinit(self: *Function, allocator: Allocator) void {
    if (self.doc) |doc| allocator.free(doc);
    allocator.free(self.name);
    for (self.parameters.values()) |*param| {
        param.deinit(allocator);
    }
    self.parameters.deinit(allocator);
    self.return_type.deinit(allocator);

    self.* = .{};
}

/// Describes the override behavior of a function in object-oriented inheritance.
///
/// This enum categorizes functions based on whether they can or must be overridden
/// by derived classes, following common OOP virtual function semantics.
pub const Mode = enum {
    /// The function MUST be overridden.
    abstract,
    /// The function MAY be overridden.
    virtual,
    /// The function CANNOT be overridden.
    final,
};

pub const Parameter = struct {
    name: []const u8 = "_",
    name_api: []const u8 = "_",
    type: Type = .void,
    default: ?[]const u8 = null,
    field_name: ?[]const u8 = null,

    pub const NameStyle = enum {
        none,
        prefixed,
    };

    pub const Options = struct {
        name_style: NameStyle = .prefixed,
    };

    pub fn fromNameType(allocator: Allocator, api_name: []const u8, api_type: []const u8, is_meta: bool, ctx: *const Context, opt: Options) !Parameter {
        const name = switch (opt.name_style) {
            .none => try std.fmt.allocPrint(allocator, "{s}", .{case_utils.fmtSliceCaseSnake(api_name)}),
            .prefixed => try std.fmt.allocPrint(allocator, "p_{s}", .{case_utils.fmtSliceCaseSnake(api_name)}),
        };
        errdefer allocator.free(name);

        const @"type" = try Type.from(allocator, api_type, is_meta, ctx);
        errdefer @"type".deinit(allocator);

        return Parameter{
            .name = name,
            .name_api = api_name,
            .type = @"type",
        };
    }

    pub fn fromNameTypeDefault(allocator: Allocator, api_name: []const u8, api_type: []const u8, is_meta: bool, default: []const u8, ctx: *const Context) !Parameter {
        var self = try fromNameType(allocator, api_name, api_type, is_meta, ctx, .{
            .name_style = .none,
        });

        if (self.type == .array and std.mem.indexOf(u8, default, "[]") != null) {
            self.default = "null";
        } else if (self.type == .string and std.mem.eql(u8, default, "\"\"")) {
            self.default = "null";
        } else if (self.type == .string_name and std.mem.eql(u8, default, "&\"\"")) {
            self.default = "null";
        } else if (self.type == .@"enum") {
            self.default = try std.fmt.allocPrint(allocator, "@enumFromInt({s})", .{default});
        } else if (self.type == .flag) {
            self.default = try std.fmt.allocPrint(allocator, "@bitCast({s})", .{default});
        } else {
            self.default = try allocator.dupe(u8, default);
        }
        return self;
    }

    pub fn deinit(self: *Parameter, allocator: Allocator) void {
        allocator.free(self.name);
        self.type.deinit(allocator);
        if (self.default) |default| allocator.free(default);

        self.* = .{};
    }
};

const return_type_init_map: StaticStringMap([]const u8) = .initComptime(.{
    // builtins
    .{ "Vector2", ".zero" },
    .{ "Vector3", ".zero" },
    .{ "Vector4", ".zero" },
    .{ "Vector2i", ".zero" },
    .{ "Vector3i", ".zero" },
    .{ "Vector4i", ".zero" },
    .{ "Basis", ".identity" },
    .{ "Transform2D", ".identity" },
    .{ "Transform3D", ".identity" },
    .{ "Projection", ".identity" },

    // primitives
    .{ "bool", "false" },

    .{ "u8", "0" },
    .{ "u16", "0" },
    .{ "u32", "0" },
    .{ "u64", "0" },

    .{ "i8", "0" },
    .{ "i16", "0" },
    .{ "i32", "0" },
    .{ "i64", "0" },

    .{ "f32", "0.0" },
    .{ "f64", "0.0" },

    .{ "void", "undefined" },
    .{ "Variant", ".nil" },
});

/// Returns the initializer for a given return type.
///
/// Note: Do not use for constructors.
fn getReturnTypeInitializer(return_type: Type) ?[]const u8 {
    switch (return_type) {
        inline .string_name, .string => return ".init()",
        inline .class, .basic => |type_name| {
            if (return_type_init_map.get(type_name)) |initializer| {
                return initializer;
            }

            if (std.zig.isPrimitive(type_name)) {
                std.debug.panic("No initializer defined for primitive type '{s}'", .{type_name});
            }

            // this should exist for all basic and class types
            return ".init()";
        },
        else => {},
    }

    return null;
}

const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayListUnmanaged;
const StaticStringMap = std.StaticStringMap;
const StringArrayHashMap = std.StringArrayHashMapUnmanaged;

const case = @import("case");
const case_utils = @import("../case_utils.zig");

const Context = @import("../Context.zig");
const Type = Context.Type;
const GodotApi = @import("../GodotApi.zig");
const docs = @import("docs.zig");
