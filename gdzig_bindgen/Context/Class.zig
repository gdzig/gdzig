const Class = @This();

/// Markdown formatted docblock
doc: ?[]const u8 = null,

module: []const u8 = "",

/// The normalized name of the type
name: []const u8 = "_",
/// The name of the type used in `extension_api.json`
name_api: []const u8 = "_",

/// The normalize name of the base type
base: ?[]const u8 = null,
/// The name of the base type used in `extension_api.json`
base_api: ?[]const u8 = null,

/// Is THIS class a singleton
is_singleton: bool = false,
/// Is THIS or any PARENT class a singleton
has_singleton: bool = false,
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

    // Documentation
    self.doc = if (api.description) |desc|
        try docs.convertDocsToMarkdown(allocator, desc, ctx, .{
            .current_class = api.name,
        })
    else if (api.brief_description) |desc|
        try docs.convertDocsToMarkdown(allocator, desc, ctx, .{
            .current_class = api.name,
        })
    else
        null;

    // Name
    self.name = blk: {
        // TODO: case conversion
        // break try case.allocTo(allocator, .pascal, api.name);
        break :blk try allocator.dupe(u8, api.name);
    };
    self.name_api = api.name;

    self.module = try case.allocTo(allocator, .snake, self.name);

    // Base
    self.base = if (api.inherits) |inherits| blk: {
        // TODO: case conversion
        // break try case.allocTo(allocator, .pascal, api.name);
        break :blk try allocator.dupe(u8, inherits);
    } else null;
    self.base_api = api.inherits;

    // Meta
    self.is_singleton = ctx.isSingleton(api.name);
    self.has_singleton = self.getNearestSingleton(ctx) != null;
    self.is_instantiable = !self.has_singleton and api.is_instantiable;
    self.is_refcounted = api.is_refcounted;

    // Constants
    for (api.constants orelse &.{}) |constant| {
        try self.constants.put(allocator, constant.name, try Constant.fromClass(allocator, constant, ctx));
    }

    // Enums
    for (api.enums orelse &.{}) |@"enum"| {
        if (@"enum".is_bitfield) {
            try self.flags.put(allocator, @"enum".name, try Flag.fromGlobalEnum(allocator, self.name_api, @"enum", ctx));
        } else {
            try self.enums.put(allocator, @"enum".name, try Enum.fromClass(allocator, self.name_api, @"enum", ctx));
        }
    }

    // Methods
    for (api.methods orelse &.{}) |method| {
        try self.functions.put(allocator, method.name, try Function.fromClass(allocator, self.name_api, self.has_singleton, method, ctx));
    }

    // Inherited methods
    if (self.getBasePtr(ctx)) |base| {
        // Copy the parent class functions
        for (base.functions.values()) |*function| {
            var inherited: Function = function.*;

            // Update the self type to this class
            inherited.self = switch (inherited.self) {
                .static => .static,
                .singleton => .singleton,
                .constant => |_| .{ .constant = self.name },
                .mutable => |_| .{ .mutable = self.name },
                .value => |_| .{ .value = self.name },
            };

            // Convert the function to a singleton function if we are a singleton and the parent is not
            if (self.is_singleton and inherited.self != .static and inherited.self != .singleton) {
                inherited.self = .singleton;
            }

            try self.functions.put(
                allocator,
                inherited.name_api,
                inherited,
            );
        }
    }

    // Properties
    for (api.properties orelse &.{}) |property| {
        try self.properties.put(allocator, property.name, try Property.fromClass(allocator, self.name, property, self.is_singleton, ctx));
    }

    // Signals
    var signals = try getAllSignalsIncludingInherits(ctx.rawAllocator(), api, ctx);
    defer signals.deinit(ctx.rawAllocator());

    for (signals.items) |signal| {
        try self.signals.put(allocator, signal.name, try Signal.fromClass(allocator, api.name, signal, ctx));
    }

    return self;
}

fn getAllSignalsIncludingInherits(allocator: Allocator, api: GodotApi.Class, ctx: *const Context) !ArrayList(GodotApi.Class.Signal) {
    var signals: ArrayList(GodotApi.Class.Signal) = .empty;

    var current_class: ?GodotApi.Class = api;
    while (current_class) |api_class| {
        try signals.appendSlice(allocator, api_class.signals orelse &.{});

        if (ctx.api.findClass(api_class.inherits)) |child_class| {
            current_class = child_class;
        } else {
            current_class = null;
        }
    }

    return signals;
}

pub fn deinit(self: *Class, allocator: Allocator) void {
    if (self.doc) |doc| allocator.free(doc);
    allocator.free(self.module);
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

pub fn getBasePtr(self: *const Class, ctx: *const Context) ?*Class {
    return if (self.base) |base| ctx.classes.getPtr(base) else null;
}

pub fn getNearestSingleton(self: *const Class, ctx: *const Context) ?*const Class {
    if (self.is_singleton) return self;
    if (self.getBasePtr(ctx)) |base| {
        return base.getNearestSingleton(ctx);
    }
    return null;
}

const std = @import("std");
const Allocator = std.mem.Allocator;
const StringArrayHashMap = std.StringArrayHashMapUnmanaged;
const ArrayList = std.ArrayListUnmanaged;

const case = @import("case");

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
