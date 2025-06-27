const Context = @This();

pub const Enum = @import("context/Enum.zig");
pub const Flag = @import("context/Flag.zig");
pub const Function = @import("context/Function.zig");
pub const Imports = @import("context/Imports.zig");
pub const Module = @import("context/Module.zig");
pub const Type = @import("context/type.zig").Type;

/// @deprecated: prefer passing allocator
allocator: Allocator,
api: GodotApi,
config: Config,

all_engine_classes: ArrayList([]const u8) = .empty,
class_sizes: StringHashMap(i64) = .empty,
depends: ArrayList([]const u8) = .empty,
engine_classes: StringHashMap(bool) = .empty,
func_docs: StringHashMap([]const u8) = .empty,
func_names: StringHashMap([]const u8) = .empty,
func_pointers: StringHashMap([]const u8) = .empty,
singletons: StringHashMap([]const u8) = .empty,

core_exports: ArrayList(struct { ident: []const u8, file: []const u8, path: ?[]const u8 = null }) = .empty,
builtin_imports: StringHashMap(Imports) = .empty,
class_index: StringHashMap(usize) = .empty,
class_imports: StringHashMap(Imports) = .empty,
function_imports: StringHashMap(Imports) = .empty,

enums: ArrayList(Enum) = .empty,
flags: ArrayList(Flag) = .empty,
modules: ArrayList(Module) = .empty,

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

pub fn build(allocator: Allocator, api: GodotApi, config: Config) !Context {
    var self = Context{
        .allocator = allocator,
        .api = api,
        .config = config,
    };

    try self.collectExports(allocator);

    try self.parseGdExtensionHeaders();
    try self.parseClassSizes();
    try self.parseSingletons();
    try self.parseClasses();

    try self.castEnums(allocator);
    try self.castFlags(allocator);
    try self.castModules(allocator);

    try self.collectImports(allocator);

    return self;
}

pub fn deinit(self: *Context) void {
    self.all_classes.deinit(self.allocator);
    self.all_engine_classes.deinit(self.allocator);
    self.class_sizes.deinit(self.allocator);
    self.depends.deinit(self.allocator);
    self.engine_classes.deinit(self.allocator);
    self.func_docs.deinit(self.allocator);
    self.func_names.deinit(self.allocator);
    self.func_pointers.deinit(self.allocator);
    self.singletons.deinit(self.allocator);
    self.builtin_imports.deinit(self.allocator);
    self.class_index.deinit(self.allocator);
    self.class_imports.deinit(self.allocator);
    self.function_imports.deinit(self.allocator);

    for (self.enums.items) |@"enum"| {
        @"enum".deinit(self.allocator);
    }
    self.enums.deinit(self.allocator);

    for (self.flags.items) |flag| {
        flag.deinit(self.allocator);
    }
    self.flags.deinit(self.allocator);

    for (self.modules.items) |module| {
        module.deinit(self.allocator);
    }
    self.modules.deinit(self.allocator);
}

/// This function generates a list of types/modules to re-export in core.zig
fn collectExports(self: *Context, allocator: Allocator) !void {
    try self.core_exports.append(allocator, .{
        .ident = "global",
        .file = "global",
    });

    for (self.api.builtin_classes) |builtin| {
        if (util.shouldSkipClass(builtin.name)) {
            continue;
        }
        try self.core_exports.append(allocator, .{
            .ident = builtin.name,
            .file = builtin.name,
            .path = builtin.name,
        });
    }

    for (self.api.classes) |class| {
        if (util.shouldSkipClass(class.name)) {
            continue;
        }
        try self.core_exports.append(allocator, .{
            .ident = class.name,
            .file = class.name,
            .path = class.name,
        });
        try self.all_engine_classes.append(allocator, class.name);
    }
}

fn collectImports(self: *Context, allocator: Allocator) !void {
    for (self.api.builtin_classes) |builtin| {
        try self.collectBuiltinImports(allocator, builtin);
    }
    for (self.api.classes, 0..) |class, i| {
        try self.class_index.put(allocator, class.name, i);
    }
    for (self.api.classes) |class| {
        try self.collectClassImports(allocator, class);
    }
    for (self.api.utility_functions) |function| {
        try self.collectFunctionImports(allocator, function);
    }
}

fn collectBuiltinImports(self: *Context, allocator: Allocator, builtin: GodotApi.Builtin) !void {
    if (self.builtin_imports.contains(builtin.name)) return;

    var imports: Imports = .empty;
    imports.skip = builtin.name;

    for (builtin.constants orelse &.{}) |constant| {
        try imports.put(allocator, self.correctType(constant.type, ""));
    }
    for (builtin.constructors) |constructor| {
        for (constructor.arguments orelse &.{}) |argument| {
            try imports.put(allocator, self.correctType(argument.type, ""));
        }
    }
    for (builtin.members orelse &.{}) |member| {
        try imports.put(allocator, self.correctType(member.type, ""));
    }
    for (builtin.methods orelse &.{}) |method| {
        try imports.put(allocator, self.correctType(method.return_type, ""));
        for (method.arguments orelse &.{}) |argument| {
            try imports.put(allocator, self.correctType(argument.type, ""));
        }
    }
    for (builtin.operators) |operator| {
        try imports.put(allocator, self.correctType(operator.right_type, ""));
        try imports.put(allocator, self.correctType(operator.return_type, ""));
    }

    try self.builtin_imports.put(allocator, builtin.name, imports);
}

fn collectClassImports(self: *Context, allocator: Allocator, class: GodotApi.Class) !void {
    if (self.class_imports.contains(class.name)) return;

    var imports: Imports = .empty;
    imports.skip = class.name;

    for (class.methods orelse &.{}) |method| {
        if (method.return_value) |return_value| {
            try imports.put(allocator, self.correctType(return_value.type, return_value.meta));
        }
        for (method.arguments orelse &.{}) |argument| {
            try imports.put(allocator, self.correctType(argument.type, argument.meta));
        }
    }
    for (class.properties orelse &.{}) |_| {
        // TODO: deal with comma separated "CanvasItemMaterial,ShaderMaterial"
        // try imports.put(allocator, self.correctType(property.type, ""));
    }
    for (class.signals orelse &.{}) |signal| {
        for (signal.arguments orelse &.{}) |argument| {
            try imports.put(allocator, self.correctType(argument.type, ""));
        }
    }

    // Index imports from the parent class hierarchy
    var cur = class;
    while (cur.inherits.len > 0) {
        const idx = self.class_index.get(cur.inherits).?;
        cur = self.api.classes[idx];
        try self.collectClassImports(allocator, cur);
        try imports.put(allocator, cur.name);
        try imports.merge(allocator, &self.class_imports.get(cur.name).?);
    }

    try self.class_imports.put(allocator, class.name, imports);
}

fn collectFunctionImports(self: *Context, allocator: Allocator, function: GodotApi.UtilityFunction) !void {
    var imports: Imports = .empty;
    try imports.put(allocator, function.return_type);

    for (function.arguments orelse &.{}) |argument| {
        try imports.put(allocator, argument.type);
    }

    try self.function_imports.put(allocator, function.name, imports);
}

fn parseClasses(self: *Context) !void {
    for (self.api.classes) |bc| {
        // TODO: why?
        if (std.mem.eql(u8, bc.name, "ClassDB")) {
            continue;
        }
        try self.engine_classes.put(self.allocator, bc.name, bc.is_refcounted);
    }

    for (self.api.native_structures) |ns| {
        try self.engine_classes.put(self.allocator, ns.name, false);
    }
}

fn parseClassSizes(self: *Context) !void {
    for (self.api.builtin_class_sizes) |bcs| {
        if (!std.mem.eql(u8, bcs.build_configuration, self.config.buildConfiguration())) {
            continue;
        }

        for (bcs.sizes) |sz| {
            try self.class_sizes.put(self.allocator, sz.name, sz.size);
        }
    }
}

fn parseSingletons(self: *Context) !void {
    for (self.api.singletons) |sg| {
        try self.singletons.put(self.allocator, sg.name, sg.type);
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
    const doc_writer: std.ArrayListUnmanaged(u8).Writer = doc_stream.writer(self.allocator);

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

            if (line.len <= 3) {
                continue;
            }
        };

        // we are in a doc comment
        if (doc_start != null) {
            const is_last_line = std.mem.containsAtLeast(u8, line, 1, "*/");

            if (line.len > 0) {
                @memcpy(doc_line_buf[0 .. line.len - 2], line[2..]);
                var doc_line = doc_line_buf[0 .. line.len - 2];

                if (is_last_line) {
                    // remove the trailing "*/"
                    const len = std.mem.replace(u8, doc_line, "*/", "", &doc_line_temp);
                    doc_line = doc_line_temp[0..len];
                }

                if (!contains_name_doc and !(is_last_line and doc_line.len == 0)) {
                    try doc_writer.writeAll("/// ");
                    try doc_writer.writeAll(try self.allocator.dupe(u8, doc_line));
                    try doc_writer.writeAll("\n");
                }

                if (is_last_line) {
                    doc_end = doc_stream.items.len;
                }
            }
        }

        // getting function pointers
        if (contains_name_doc) {
            const name_index = std.mem.indexOf(u8, line, name_doc).?;
            const start = name_index + name_doc.len + 1; // +1 to skip the space after @name
            fn_name = try self.allocator.dupe(u8, line[start..]);
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
            fp_type = try self.allocator.dupe(u8, fp_type_slice[start..(end + start)]);
        }

        if (fn_name) |_| if (fp_type) |_| {
            try self.func_pointers.put(self.allocator, fp_type.?, fn_name.?);

            if (doc_start) |start_index| if (doc_end) |end_index| {
                const doc_text = try self.allocator.dupe(u8, doc_stream.items[start_index..end_index]);
                try self.func_docs.put(self.allocator, fp_type.?, doc_text);
            };

            fn_name = null;
            fp_type = null;
            doc_start = null;
            doc_end = null;
        };
    }
}

fn castEnums(self: *Context, allocator: Allocator) !void {
    for (self.api.global_enums) |@"enum"| {
        if (@"enum".is_bitfield) {
            continue;
        }
        try self.enums.append(allocator, try .fromGlobalEnum(allocator, @"enum"));
    }
}

fn castFlags(self: *Context, allocator: Allocator) !void {
    for (self.api.global_enums) |@"enum"| {
        if (!@"enum".is_bitfield) {
            continue;
        }
        try self.flags.append(allocator, try .fromGlobalEnum(allocator, @"enum"));
    }
}

fn castModules(self: *Context, allocator: Allocator) !void {
    // This logic is a dumb way to group utility functions into modules
    var cur: ?*Module = null;
    for (self.api.utility_functions) |function| {
        if (cur == null or !std.mem.eql(u8, cur.?.name, function.category)) {
            cur = try self.modules.addOne(allocator);
            cur.?.* = try .init(allocator, function.category);
        }
    }
    var i: usize = 0;
    for (self.modules.items) |*module| {
        var functions: ArrayList(Function) = .empty;
        for (self.api.utility_functions[i..], 1..) |function, j| {
            if (!std.mem.eql(u8, module.name, function.category)) {
                i = j;
                break;
            }
            try functions.append(allocator, try .fromUtilityFunction(allocator, function));
        }
        module.functions = try functions.toOwnedSlice(allocator);
    }
}

pub fn correctName(self: *const Context, name: []const u8) []const u8 {
    if (std.zig.Token.keywords.has(name)) {
        return std.fmt.allocPrint(self.allocator, "@\"{s}\"", .{name}) catch unreachable;
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
            return std.fmt.allocPrint(self.allocator, "global.{s}", .{util.getEnumName(correct_type)}) catch unreachable;
        } else {
            return util.getEnumName(correct_type);
        }
    }

    if (std.mem.startsWith(u8, correct_type, "const ")) {
        correct_type = correct_type[6..];
    }

    if (self.isRefCounted(correct_type)) {
        return std.fmt.allocPrint(self.allocator, "?{s}", .{correct_type}) catch unreachable;
    } else if (self.isEngineClass(correct_type)) {
        return std.fmt.allocPrint(self.allocator, "?{s}", .{correct_type}) catch unreachable;
    } else if (correct_type[correct_type.len - 1] == '*') {
        return std.fmt.allocPrint(self.allocator, "?*{s}", .{correct_type[0 .. correct_type.len - 1]}) catch unreachable;
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
    const result = self.func_names.getOrPut(self.allocator, godot_func_name) catch unreachable;

    if (!result.found_existing) {
        result.value_ptr.* = self.correctName(case.allocTo(self.allocator, func_case, godot_func_name) catch unreachable);
    }

    return result.value_ptr.*;
}

pub fn getVariantTypeName(self: *const Context, class_name: []const u8) []const u8 {
    var buf: [256]u8 = undefined;
    const nnn = case.bufTo(&buf, .snake, class_name) catch unreachable;
    return std.fmt.allocPrint(self.allocator, "godot.c.GDEXTENSION_VARIANT_TYPE_{s}", .{std.ascii.upperString(&buf, nnn)}) catch unreachable;
}

pub fn isRefCounted(self: *const Context, type_name: []const u8) bool {
    const real_type = util.childType(type_name);
    if (self.engine_classes.get(real_type)) |v| {
        return v;
    }
    return false;
}

pub fn isEngineClass(self: *const Context, type_name: []const u8) bool {
    const real_type = util.childType(type_name);
    return std.mem.eql(u8, real_type, "Object") or self.engine_classes.contains(real_type);
}

pub fn isSingleton(self: *const Context, class_name: []const u8) bool {
    return self.singletons.contains(class_name);
}

const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayListUnmanaged;
const StringHashMap = std.StringHashMapUnmanaged;

const case = @import("case");

const GodotApi = @import("GodotApi.zig");
const util = @import("util.zig");
const Config = @import("Config.zig");
