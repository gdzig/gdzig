const Class = @This();

/// Markdown formatted docblock
doc: ?[]const u8 = null,

/// The normalized name of the type
name: []const u8 = "_",
/// The name of the type used in `extension_api.json`
name_api: []const u8 = "_",

/// The normalize name of the base type
base: ?[]const u8 = null,
/// The name of the base type used in `extension_api.json`
base_api: ?[]const u8 = null,

/// Is this class a singleton (can only have one instant)?
is_singleton: bool = false,
/// Can this type be instantiated directly with no arguments
is_instantiable: bool = false,
/// Is this a reference counted type
is_refcounted: bool = false,

/// Constants exported by this class
constants: StringArrayHashMap(Constant) = .empty,
/// Enums exported by this class
enums: StringArrayHashMap(Enum) = .empty,
/// Flags exported by this class
flags: StringArrayHashMap(Flag) = .empty,
/// Methods exported by this class
functions: StringArrayHashMap(Function) = .empty,
/// Properties exported by this class
properties: StringArrayHashMap(Property) = .empty,
/// Signals exported by this class
signals: StringArrayHashMap(Signal) = .empty,

/// Imports required by this class
imports: Imports = .empty,

pub fn fromApi(allocator: Allocator, api: GodotApi.Class, ctx: *const Context) !Class {
    var self: Class = .{};
    errdefer self.deinit(allocator);

    // Documentation
    self.doc = if (api.description) |desc|
        try docs.convertDocsToMarkdown(allocator, desc, ctx, .{})
    else if (api.brief_description) |desc|
        try docs.convertDocsToMarkdown(allocator, desc, ctx, .{})
    else
        null;

    // Name
    self.name = blk: {
        // TODO: case conversion
        // break try case.allocTo(allocator, .pascal, api.name);
        break :blk try allocator.dupe(u8, api.name);
    };
    self.name_api = api.name;

    // Base
    self.base = if (api.inherits.len > 0) blk: {
        // TODO: case conversion
        // break try case.allocTo(allocator, .pascal, api.name);
        break :blk try allocator.dupe(u8, api.inherits);
    } else null;
    self.base_api = if (api.inherits.len > 0) api.inherits else null;

    // Meta
    self.is_instantiable = api.is_instantiable;
    self.is_refcounted = api.is_refcounted;

    // Constants
    for (api.constants orelse &.{}) |constant| {
        try self.constants.put(allocator, constant.name, try Constant.fromClass(allocator, constant, ctx));
    }

    // Enums
    for (api.enums orelse &.{}) |@"enum"| {
        if (@"enum".is_bitfield) {
            try self.flags.put(allocator, @"enum".name, try Flag.fromGlobalEnum(allocator, @"enum", ctx));
        } else {
            try self.enums.put(allocator, @"enum".name, try Enum.fromClass(allocator, @"enum"));
        }
    }

    // Methods
    for (api.methods orelse &.{}) |method| {
        try self.functions.put(allocator, method.name, try Function.fromClass(allocator, method, ctx));
    }

    // Properties
    for (api.properties orelse &.{}) |property| {
        try self.properties.put(allocator, property.name, try Property.fromClass(allocator, property, ctx));
    }

    // Signals
    for (api.signals orelse &.{}) |signal| {
        try self.signals.put(allocator, signal.name, try Signal.fromClass(allocator, signal, ctx));
    }

    return self;
}

pub fn deinit(self: *Class, allocator: Allocator) void {
    if (self.doc) |doc| allocator.free(doc);
    allocator.free(self.name);
    if (self.base) |base| allocator.free(base);

    for (self.constants.values()) |*constant| {
        constant.deinit(allocator);
    }
    self.constants.deinit(allocator);

    for (self.enums.values()) |*@"enum"| {
        @"enum".deinit(allocator);
    }
    self.enums.deinit(allocator);

    for (self.flags.values()) |*flag| {
        flag.deinit(allocator);
    }
    self.flags.deinit(allocator);

    for (self.functions.values()) |*function| {
        function.deinit(allocator);
    }
    self.functions.deinit(allocator);

    for (self.properties.values()) |*property| {
        property.deinit(allocator);
    }
    self.properties.deinit(allocator);

    for (self.signals.values()) |*signal| {
        signal.deinit(allocator);
    }
    self.signals.deinit(allocator);

    self.imports.deinit(allocator);

    self.* = .{};
}

pub fn getBase(self: *const Class, ctx: *const Context) ?*Class {
    return if (self.base) |base| ctx.classes.getPtr(base) else null;
}

const std = @import("std");
const Allocator = std.mem.Allocator;
const StringArrayHashMap = std.StringArrayHashMapUnmanaged;

const Context = @import("../Context.zig");
const Constant = Context.Constant;
const Enum = Context.Enum;
const Flag = Context.Flag;
const Function = Context.Function;
const Imports = Context.Imports;
const Property = Context.Property;
const Signal = Context.Signal;
const GodotApi = @import("../GodotApi.zig");
const docs = @import("docs.zig");
