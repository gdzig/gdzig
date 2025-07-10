const Context = @This();

const logger = std.log.scoped(.context);

pub const Symbol = struct {
    path: []const u8,
    label: []const u8,
};

arena: *ArenaAllocator,
api: GodotApi,
config: Config,

all_engine_classes: ArrayList([]const u8) = .empty,
depends: ArrayList([]const u8) = .empty,
engine_classes: StringHashMap(bool) = .empty,
func_docs: StringHashMap([]const u8) = .empty,
func_names: StringHashMap([]const u8) = .empty,
func_pointers: StringHashMap([]const u8) = .empty,
singletons: StringHashMap([]const u8) = .empty,

builtin_imports: StringHashMap(Imports) = .empty,
class_index: StringHashMap(usize) = .empty,
class_imports: StringHashMap(Imports) = .empty,
function_imports: StringHashMap(Imports) = .empty,

builtins: StringArrayHashMap(Builtin) = .empty,
builtin_sizes: StringArrayHashMap(struct { size: usize, members: StringArrayHashMap(struct { offset: usize, meta: []const u8 }) }) = .empty,
classes: StringArrayHashMap(Class) = .empty,
enums: StringArrayHashMap(Enum) = .empty,
flags: StringArrayHashMap(Flag) = .empty,
interface: Interface = .empty,
modules: StringArrayHashMap(Module) = .empty,

symbol_lookup: StringHashMap(Symbol) = .empty,

const func_case: case.Case = .camel;

const base_type_map = std.StaticStringMap([]const u8).initComptime(.{
    .{ "int", "i64" },
    .{ "int8", "i8" },
    .{ "uint8", "u8" },
    .{ "int16", "i16" },
    .{ "uint16", "u16" },
    .{ "int32", "i32" },
    .{ "uint32", "u32" },
    .{ "int64", "i64" },
    .{ "uint64", "u64" },
    .{ "float", "f32" },
    .{ "double", "f64" },
});

pub fn build(arena: *ArenaAllocator, api: GodotApi, config: Config) !Context {
    var self = Context{
        .arena = arena,
        .api = api,
        .config = config,
    };

    try self.buildSymbolLookupTable();

    try self.parseGdExtensionHeaders();
    try self.parseSingletons();
    try self.parseClasses();

    try self.collectSizes();

    try self.castBuiltins();
    try self.castClasses();
    try self.castEnums();
    try self.castFlags();
    try self.castModules();

    try self.collectImports();

    return self;
}

pub fn allocator(self: *const Context) Allocator {
    return self.arena.allocator();
}

pub fn rawAllocator(self: *const Context) Allocator {
    return self.arena.child_allocator;
}

fn collectImports(self: *Context) !void {
    for (self.api.builtin_classes) |builtin| {
        try self.collectBuiltinImports(builtin);
    }
    for (self.api.classes, 0..) |class, i| {
        try self.class_index.put(self.allocator(), class.name, i);
    }
    for (self.api.classes) |class| {
        try self.collectClassImports(self.classes.getPtr(class.name).?);
    }
    for (self.api.utility_functions) |function| {
        try self.collectFunctionImports(function);
    }
    for (self.all_engine_classes.items) |class| {
        try self.interface.imports.put(self.allocator(), class);
    }
}

fn collectBuiltinImports(self: *Context, builtin: GodotApi.Builtin) !void {
    if (self.builtin_imports.contains(builtin.name)) return;

    var imports: Imports = .empty;
    imports.skip = builtin.name;

    for (builtin.constants orelse &.{}) |constant| {
        try imports.put(self.allocator(), self.correctType(constant.type, ""));
    }
    for (builtin.constructors) |constructor| {
        for (constructor.arguments orelse &.{}) |argument| {
            try imports.put(self.allocator(), self.correctType(argument.type, ""));
        }
    }
    for (builtin.members orelse &.{}) |member| {
        try imports.put(self.allocator(), self.correctType(member.type, ""));
    }
    for (builtin.methods orelse &.{}) |method| {
        try imports.put(self.allocator(), self.correctType(method.return_type, ""));
        for (method.arguments orelse &.{}) |argument| {
            try imports.put(self.allocator(), self.correctType(argument.type, ""));
        }
    }
    for (builtin.operators) |operator| {
        if (operator.right_type.len > 0) {
            try imports.put(self.allocator(), self.correctType(operator.right_type, ""));
        }
        try imports.put(self.allocator(), self.correctType(operator.return_type, ""));
    }

    try imports.put(self.allocator(), "StringName");

    try self.builtin_imports.put(self.allocator(), builtin.name, imports);

    if (self.builtins.getPtr(builtin.name)) |context_builtin| {
        try context_builtin.imports.merge(self.allocator(), &imports);
    }
}

fn collectClassImports(self: *Context, class: *Class) !void {
    if (class.imports.map.count() > 0) return;
    class.imports.skip = class.name;

    for (class.functions.values()) |function| {
        try self.typeImport(&class.imports, &function.return_type);
        for (function.parameters.values()) |parameter| {
            try self.typeImport(&class.imports, &parameter.type);
        }
    }
    for (class.properties.values()) |property| {
        try self.typeImport(&class.imports, &property.type);
    }
    for (class.signals.values()) |signal| {
        for (signal.parameters.values()) |parameter| {
            try self.typeImport(&class.imports, &parameter.type);
        }
    }

    try class.imports.put(self.allocator(), "RefCounted");

    // Index imports from the parent class hierarchy
    if (class.getBasePtr(self)) |base| {
        try self.collectClassImports(base);
        try class.imports.put(self.allocator(), base.name);
        try class.imports.merge(self.allocator(), &base.imports);
    }
}

fn typeImport(self: *Context, imports: *Imports, @"type": *const Type) !void {
    switch (@"type".*) {
        .array => try imports.put(self.allocator(), "Array"),
        .basic => |name| try imports.put(self.allocator(), name),
        .class => |name| try imports.put(self.allocator(), name),
        .@"enum" => |name| try imports.put(self.allocator(), name),
        .flag => |name| try imports.put(self.allocator(), name),
        .pointer => |child| try self.typeImport(imports, child),
        .string => try imports.put(self.allocator(), "String"),
        .string_name => try imports.put(self.allocator(), "StringName"),
        .node_path => try imports.put(self.allocator(), "NodePath"),
        .@"union" => {},
        .variant => try imports.put(self.allocator(), "Variant"),
        .void => {},
    }
}

fn collectFunctionImports(self: *Context, function: GodotApi.UtilityFunction) !void {
    var imports: Imports = .empty;
    try imports.put(self.allocator(), function.return_type);

    for (function.arguments orelse &.{}) |argument| {
        try imports.put(self.allocator(), argument.type);
    }

    try imports.put(self.allocator(), "StringName");

    // TODO: remove function_imports
    var module = self.modules.getPtr(function.category).?;
    try module.imports.merge(self.allocator(), &imports);

    try self.function_imports.put(self.allocator(), function.name, imports);
}

fn parseClasses(self: *Context) !void {
    for (self.api.classes) |bc| {
        try self.engine_classes.put(self.allocator(), bc.name, bc.is_refcounted);
    }

    for (self.api.native_structures) |ns| {
        try self.engine_classes.put(self.allocator(), ns.name, false);
    }
}

fn parseSingletons(self: *Context) !void {
    for (self.api.singletons) |sg| {
        try self.singletons.put(self.allocator(), sg.name, sg.type);
    }
}

fn parseGdExtensionHeaders(self: *Context) !void {
    var buffered_reader = std.io.bufferedReader(self.config.gdextension_interface.reader());
    const reader = buffered_reader.reader();

    const name_doc = "@name";

    var buf: [1024]u8 = undefined;
    var fn_name: ?[]const u8 = null;
    var fp_type: ?[]const u8 = null;
    const safe_ident_chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_";

    var doc_stream: std.ArrayListUnmanaged(u8) = .empty;
    const doc_writer: std.ArrayListUnmanaged(u8).Writer = doc_stream.writer(self.allocator());

    var doc_start: ?usize = null;
    var doc_end: ?usize = null;
    var doc_line_buf: [1024]u8 = undefined;
    var doc_line_temp: [1024]u8 = undefined;

    while (true) {
        const line: []const u8 = reader.readUntilDelimiterOrEof(&buf, '\n') catch break orelse break;

        const contains_name_doc = std.mem.indexOf(u8, line, name_doc) != null;

        // getting function docs
        if (std.mem.indexOf(u8, line, "/*")) |i| if (i >= 0) {
            doc_start = doc_stream.items.len;

            if (line.len <= 4) {
                continue;
            }
        };

        // we are in a doc comment
        if (doc_start != null) {
            const is_last_line = std.mem.containsAtLeast(u8, line, 1, "*/");

            if (line.len > 0) {
                @memcpy(doc_line_buf[0 .. @max(line.len, 3) - 3], line[@min(line.len, 3)..]);

                var doc_line = doc_line_buf[0 .. @max(line.len, 3) - 3];
                if (is_last_line) {
                    // remove the trailing "*/"
                    const len = std.mem.replace(u8, doc_line, "*/", "", &doc_line_temp);
                    doc_line = doc_line_temp[0..len];
                }

                if (!contains_name_doc and !(is_last_line and doc_line.len == 0)) {
                    try doc_writer.writeAll(try self.allocator().dupe(u8, doc_line));
                    try doc_writer.writeAll("\n");
                }

                if (is_last_line) {
                    doc_end = doc_stream.items.len - 1;
                }
            }
        }

        // getting function pointers
        if (contains_name_doc) {
            const name_index = std.mem.indexOf(u8, line, name_doc).?;
            const start = name_index + name_doc.len + 1; // +1 to skip the space after @name
            fn_name = try self.allocator().dupe(u8, line[start..]);
            fp_type = null;
        } else if (std.mem.startsWith(u8, line, "typedef")) {
            if (fn_name == null) continue; // skip if we don't have a function name yet

            var iterator = std.mem.splitSequence(u8, line, " ");
            _ = iterator.next(); // skip "typedef"
            const const_or_return_type = iterator.next().?; // skip the return type
            if (std.mem.eql(u8, const_or_return_type, "const")) {
                // skip "const" keyword
                _ = iterator.next();
            }

            const fp_type_slice = iterator.next().?;
            const start = std.mem.indexOfAny(u8, fp_type_slice, safe_ident_chars).?;
            const end = std.mem.indexOf(u8, fp_type_slice[start..], ")").?;
            fp_type = try self.allocator().dupe(u8, fp_type_slice[start..(end + start)]);
        }

        if (fn_name) |_| if (fp_type) |_| {
            const docs: ?[]const u8 = blk: {
                if (doc_start) |start_index| {
                    if (doc_end) |end_index| {
                        break :blk try self.allocator().dupe(u8, doc_stream.items[start_index..end_index]);
                    }
                }
                break :blk null;
            };

            try self.func_docs.put(self.allocator(), fp_type.?, docs.?);
            try self.func_pointers.put(self.allocator(), fp_type.?, fn_name.?);
            try self.interface.functions.append(self.allocator(), .{
                .docs = docs,
                .name = try case.allocTo(self.allocator(), .camel, fn_name.?),
                .api_name = fn_name.?,
                .ptr_type = fp_type.?,
            });

            fn_name = null;
            fp_type = null;
            doc_start = null;
            doc_end = null;
        };
    }
}

fn collectSizes(self: *Context) !void {
    // Update size for all builtins
    for (self.api.builtin_class_sizes) |config| {
        if (!std.mem.eql(u8, config.build_configuration, self.config.buildConfiguration())) {
            continue;
        }
        for (config.sizes) |info| {
            try self.builtin_sizes.put(self.allocator(), info.name, .{
                .size = @intCast(info.size),
                .members = .empty,
            });
        }
    }

    // Update member offests and "meta" types for all builtins
    for (self.api.builtin_class_member_offsets) |config| {
        if (!std.mem.eql(u8, config.build_configuration, self.config.buildConfiguration())) {
            continue;
        }
        for (config.classes) |builtin_config| {
            const builtin = self.builtin_sizes.getPtr(builtin_config.name).?;
            for (builtin_config.members) |member_config| {
                try builtin.members.put(self.allocator(), member_config.member, .{
                    .offset = @intCast(member_config.offset),
                    .meta = member_config.meta,
                });
            }
        }
    }
}

fn castBuiltins(self: *Context) !void {
    for (self.api.builtin_classes) |builtin| {
        if (util.shouldSkipClass(builtin.name)) continue;
        try self.builtins.put(self.allocator(), builtin.name, try .fromApi(self.allocator(), builtin, self));
    }
}

fn castClasses(self: *Context) !void {
    for (self.api.classes) |class| {
        if (util.shouldSkipClass(class.name)) continue;
        try self.castClass(class);
    }
}

fn castClass(self: *Context, class: GodotApi.Class) !void {
    // Assemble parent classes first
    if (self.api.findClass(class.inherits)) |base| {
        if (!self.classes.contains(base.name)) {
            try self.castClass(base);
        }
    }
    try self.classes.put(self.allocator(), class.name, try .fromApi(self.allocator(), class, self));
}

fn castEnums(self: *Context) !void {
    for (self.api.global_enums) |@"enum"| {
        if (@"enum".is_bitfield) {
            continue;
        }
        if (std.mem.startsWith(u8, @"enum".name, "Variant.")) {
            continue;
        }
        try self.enums.put(self.allocator(), @"enum".name, try .fromGlobalEnum(self.allocator(), null, @"enum", self));
    }
}

fn castFlags(self: *Context) !void {
    for (self.api.global_enums) |@"enum"| {
        if (!@"enum".is_bitfield) {
            continue;
        }
        if (std.mem.startsWith(u8, @"enum".name, "Variant.")) {
            continue;
        }
        try self.flags.put(self.allocator(), @"enum".name, try .fromGlobalEnum(self.allocator(), null, @"enum", self));
    }
}

fn castModules(self: *Context) !void {
    // This logic is a dumb way to group utility functions into modules
    var cur: ?*Module = null;
    for (self.api.utility_functions) |function| {
        const entry = try self.modules.getOrPut(self.allocator(), function.category);
        cur = entry.value_ptr;
        if (!entry.found_existing) {
            cur.?.* = try .init(self.allocator(), function.category);
        }
    }
    var i: usize = 0;
    for (self.modules.values()) |*module| {
        var functions: ArrayList(Function) = .empty;
        for (self.api.utility_functions[i..], i..) |function, j| {
            if (!std.mem.eql(u8, module.name, function.category)) {
                i = j;
                break;
            }
            try functions.append(self.allocator(), try .fromUtilityFunction(self.allocator(), function, self));
        }
        module.*.functions = try functions.toOwnedSlice(self.allocator());
    }
}

pub fn correctName(self: *const Context, name: []const u8) []const u8 {
    if (std.zig.Token.keywords.has(name)) {
        return std.fmt.allocPrint(self.arena.allocator(), "@\"{s}\"", .{name}) catch unreachable;
    }

    return name;
}

pub fn correctType(self: *const Context, type_name: []const u8, meta: []const u8) []const u8 {
    var correct_type = if (meta.len > 0) meta else type_name;
    if (correct_type.len == 0) return "void";

    if (std.mem.eql(u8, correct_type, "float")) {
        return "f64";
    } else if (std.mem.eql(u8, correct_type, "int")) {
        return "i64";
    } else if (std.mem.eql(u8, correct_type, "Nil")) {
        return "Variant";
    } else if (base_type_map.has(correct_type)) {
        return base_type_map.get(correct_type).?;
    } else if (std.mem.startsWith(u8, correct_type, "typedarray::")) {
        //simplified to just use array instead
        return "Array";
    } else if (util.isEnum(correct_type)) {
        const cls = util.getEnumClass(correct_type);
        if (std.mem.eql(u8, cls, "GlobalConstants")) {
            return std.fmt.allocPrint(self.allocator(), "global.{s}", .{util.getEnumName(correct_type)}) catch unreachable;
        } else {
            return util.getEnumName(correct_type);
        }
    }

    if (std.mem.startsWith(u8, correct_type, "const ")) {
        correct_type = correct_type[6..];
    }

    if (self.isRefCounted(correct_type)) {
        return std.fmt.allocPrint(self.allocator(), "?{s}", .{correct_type}) catch unreachable;
    } else if (self.isClass(correct_type)) {
        return std.fmt.allocPrint(self.allocator(), "?{s}", .{correct_type}) catch unreachable;
    } else if (correct_type[correct_type.len - 1] == '*') {
        return std.fmt.allocPrint(self.allocator(), "?*{s}", .{correct_type[0 .. correct_type.len - 1]}) catch unreachable;
    }
    return correct_type;
}

pub fn getArgumentsTypes(ctx: *const Context, fn_node: GodotApi.Builtin.Constructor, buf: []u8) []const u8 {
    var pos: usize = 0;
    if (@hasField(@TypeOf(fn_node), "arguments")) {
        if (fn_node.arguments) |as| {
            for (as, 0..) |a, i| {
                _ = i;
                const arg_type = ctx.correctType(a.type, "");
                if (arg_type[0] == '*' or arg_type[0] == '?') {
                    std.mem.copyForwards(u8, buf[pos..], arg_type[1..]);
                    buf[pos] = std.ascii.toUpper(buf[pos]);
                    pos += arg_type.len - 1;
                } else {
                    std.mem.copyForwards(u8, buf[pos..], arg_type);
                    buf[pos] = std.ascii.toUpper(buf[pos]);
                    pos += arg_type.len;
                }
            }
        }
    }
    return buf[0..pos];
}

pub fn getReturnType(self: *const Context, method: GodotApi.GdMethod) []const u8 {
    return switch (method) {
        .builtin => |bc| self.correctType(bc.return_type, ""),
        .class => |cls| if (cls.return_value) |ret| self.correctType(ret.type, ret.meta) else "void",
    };
}

pub fn getZigFuncName(self: *Context, godot_func_name: []const u8) []const u8 {
    const result = self.func_names.getOrPut(self.allocator(), godot_func_name) catch unreachable;

    if (!result.found_existing) {
        result.value_ptr.* = self.correctName(case.allocTo(self.allocator(), func_case, godot_func_name) catch unreachable);
    }

    return result.value_ptr.*;
}

pub fn getVariantTypeName(self: *const Context, class_name: []const u8) []const u8 {
    var buf: [256]u8 = undefined;
    const nnn = case.bufTo(&buf, .snake, class_name) catch unreachable;
    return std.fmt.allocPrint(self.arena.allocator(), "godot.c.GDEXTENSION_VARIANT_TYPE_{s}", .{std.ascii.upperString(&buf, nnn)}) catch unreachable;
}

pub fn isRefCounted(self: *const Context, type_name: []const u8) bool {
    const real_type = util.childType(type_name);
    if (self.engine_classes.get(real_type)) |v| {
        return v;
    }
    return false;
}

pub fn isClass(self: *const Context, type_name: []const u8) bool {
    const real_type = util.childType(type_name);
    return std.mem.eql(u8, real_type, "Object") or self.engine_classes.contains(real_type);
}

pub fn isSingleton(self: *const Context, class_name: []const u8) bool {
    return self.singletons.contains(class_name);
}

fn symbolTableClasses(self: *Context, classes: anytype, module: []const u8) !void {
    for (classes) |class| {
        if (util.shouldSkipClass(class.name)) continue;

        const class_path = try std.fmt.allocPrint(self.allocator(), "{s}.{s}.{s}", .{
            module,
            case_utils.fmtSliceCaseSnake(class.name),
            class.name,
        });
        try self.symbol_lookup.putNoClobber(self.allocator(), class.name, .{
            .label = class.name,
            .path = class_path,
        });

        for (class.enums orelse &.{}) |@"enum"| {
            const enum_name = try std.fmt.allocPrint(self.allocator(), "{s}.{s}", .{ class.name, @"enum".name });
            const enum_path = try std.fmt.allocPrint(self.allocator(), "{s}.{s}", .{ class_path, @"enum".name });
            try self.symbol_lookup.putNoClobber(self.allocator(), enum_name, .{
                .label = enum_name,
                .path = enum_path,
            });
        }

        for (class.methods orelse &.{}) |method| {
            const method_name = try std.fmt.allocPrint(self.allocator(), "{s}.{s}", .{ class.name, method.name });
            const method_path = try std.fmt.allocPrint(self.allocator(), "{s}.{s}", .{
                class_path,
                case_utils.fmtSliceCaseCamel(method.name),
            });

            const method_label = try std.fmt.allocPrint(self.allocator(), "{s}.{s}", .{
                class.name,
                case_utils.fmtSliceCaseCamel(method.name),
            });

            try self.symbol_lookup.putNoClobber(self.allocator(), method_name, .{
                .label = method_label,
                .path = method_path,
            });
        }
    }
}

pub fn buildSymbolLookupTable(self: *Context) !void {
    if (self.symbol_lookup.size == 0) {
        logger.debug("Initializing symbol lookup...", .{});

        try self.symbol_lookup.putNoClobber(self.allocator(), "Variant", .{
            .label = "Variant",
            .path = "builtin.variant.Variant",
        });

        try self.symbolTableClasses(self.api.classes, "class");
        try self.symbolTableClasses(self.api.builtin_classes, "builtin");

        for (self.api.global_enums) |@"enum"| {
            const enum_path = try std.fmt.allocPrint(self.allocator(), "global.{s}.{s}", .{
                case_utils.fmtSliceCaseSnake(@"enum".name),
                @"enum".name,
            });
            try self.symbol_lookup.putNoClobber(self.allocator(), @"enum".name, .{
                .label = @"enum".name,
                .path = enum_path,
            });
        }

        for (self.api.utility_functions) |function| {
            const function_name = try std.fmt.allocPrint(self.allocator(), "{s}", .{
                case_utils.fmtSliceCaseCamel(function.name),
            });
            const function_path = try std.fmt.allocPrint(self.allocator(), "general.{s}", .{
                function_name,
            });

            try self.symbol_lookup.putNoClobber(self.allocator(), function.name, .{
                .label = function_name,
                .path = function_path,
            });

            const global_scope_key = try std.fmt.allocPrint(self.allocator(), "@GlobalScope.{s}", .{
                function.name,
            });
            try self.symbol_lookup.putNoClobber(self.allocator(), global_scope_key, .{
                .label = function_name,
                .path = function_path,
            });
        }

        logger.debug("Symbol lookup initialized. Size: {d}", .{self.symbol_lookup.size});
    }
}

const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayListUnmanaged;
const ArenaAllocator = std.heap.ArenaAllocator;
const StringHashMap = std.StringHashMapUnmanaged;
const StringArrayHashMap = std.StringArrayHashMapUnmanaged;

const case = @import("case");

const case_utils = @import("case_utils.zig");
const Config = @import("Config.zig");
pub const Builtin = @import("Context/Builtin.zig");
pub const Class = @import("Context/Class.zig");
pub const Constant = @import("Context/Constant.zig");
pub const DocumentContext = @import("Context/docs.zig").DocumentContext;
pub const Enum = @import("Context/Enum.zig");
pub const Field = @import("Context/Field.zig");
pub const Flag = @import("Context/Flag.zig");
pub const Function = @import("Context/Function.zig");
pub const Imports = @import("Context/Imports.zig");
pub const Interface = @import("Context/Interface.zig");
pub const Module = @import("Context/Module.zig");
pub const Property = @import("Context/Property.zig");
pub const Signal = @import("Context/Signal.zig");
pub const Type = @import("Context/type.zig").Type;
const GodotApi = @import("GodotApi.zig");
const util = @import("util.zig");
