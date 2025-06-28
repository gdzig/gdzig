pub fn generate(ctx: *Context) !void {
    try writeBuiltins(ctx);
    try writeGlobalEnums(ctx);
    try writeModules(ctx);

    try generateClasses(ctx);
    try generateCore(ctx);
}

fn writeBuiltins(ctx: *Context) !void {
    for (ctx.builtins.values()) |*builtin| {
        if (util.shouldSkipClass(builtin.name)) {
            continue;
        }

        const filename = try std.fmt.allocPrint(ctx.allocator, "{s}.zig", .{builtin.name});
        defer ctx.allocator.free(filename);

        const file = try ctx.config.output.createFile(filename, .{});
        defer file.close();

        var buf = bufferedWriter(file.writer());
        var writer = codeWriter(buf.writer().any());

        try writeBuiltin(&writer, builtin);

        try buf.flush();
    }
}

fn writeBuiltin(w: *Writer, builtin: *const Context.Builtin) !void {
    try writeDocBlock(w, builtin.doc);

    // Declaration start
    try w.printLine(
        \\pub const {0s} = extern struct {{
    , .{builtin.name});
    w.indent += 1;

    // Memory layout assertions
    try w.printLine(
        \\comptime {{
        \\    if (@sizeOf({0s}) != {1d}) @compileError("expected {0s} to be {1d} bytes");
    , .{ builtin.name, builtin.size });
    w.indent += 1;
    for (builtin.fields.values()) |*field| {
        if (field.offset) |offset| {
            try w.printLine(
                \\if (@offsetOf({1s}, "{0s}") != {2d}) @compileError("expected the offset of '{0s}' on '{1s}' to be {2d}");
            , .{ field.name, builtin.name, offset });
        }
    }
    w.indent -= 1;
    try w.writeLine(
        \\}
        \\
    );

    // Fields
    if (builtin.fields.count() == 0) {
        // TODO: this should probably be handled in Context.Builtin
        try w.printLine("value: [{d}]u8,", .{builtin.size});
    } else if (builtin.fields.count() > 0) {
        for (builtin.fields.values()) |*field| {
            if (field.offset != null) {
                try writeField(w, field);
            }
        }
    }

    // Constants
    var constants = builtin.constants.valueIterator();
    while (constants.next()) |constant| {
        try writeConstant(w, constant);
    }

    // Hardcoded constructors
    // TODO: move the hardcoding of these overrides to an overrides module
    if (std.mem.eql(u8, builtin.name, "String")) {
        try w.writeLine(
            \\pub fn fromLatin1(chars: []const u8) String {
            \\    var self: String = undefined;
            \\    godot.core.stringNewWithLatin1CharsAndLen(@ptrCast(&self.value), chars.ptr, @intCast(chars.len));
            \\    return self;
            \\}
            \\pub fn fromUtf8(chars: []const u8) String {
            \\    var self: String = undefined;
            \\    godot.core.stringNewWithUtf8CharsAndLen(@ptrCast(&self.value), chars.ptr, @intCast(chars.len));
            \\    return self;
            \\}
            \\pub fn fromUtf16(chars: []const godot.char16_t) String {
            \\    var self: String = undefined;
            \\    godot.core.stringNewWithUtf16CharsAndLen(@ptrCast(&self.value), chars.ptr, @intCast(chars.len));
            \\    return self;
            \\}
            \\pub fn fromUtf32(chars: []const godot.char32_t) String {
            \\    var self: String = undefined;
            \\    godot.core.stringNewWithUtf32CharsAndLen(@ptrCast(&self.value), chars.ptr, @intCast(chars.len));
            \\    return self;
            \\}
            \\pub fn fromWide(chars: []const godot.wchar_t) String {
            \\    var self: String = undefined;
            \\    godot.core.stringNewWithWideCharsAndLen(@ptrCast(&self.value), chars.ptr, @intCast(chars.len));
            \\    return self;
            \\}
        );
    }
    if (std.mem.eql(u8, builtin.name, "StringName")) {
        try w.writeLine(
            \\pub fn fromComptimeLatin1(comptime chars: [:0]const u8) StringName {
            \\    var self: StringName = undefined;
            \\    godot.core.stringNameNewWithLatin1Chars(@ptrCast(&self.value), chars.ptr, 1);
            \\    return self;
            \\}
            \\pub fn fromLatin1(chars: [:0]const u8) StringName {
            \\    var self: StringName = undefined;
            \\    godot.core.stringNameNewWithLatin1Chars(@ptrCast(&self.value), chars.ptr, 0);
            \\    return self;
            \\}
            \\pub fn fromUtf8(chars: []const u8) StringName {
            \\    var self: StringName = undefined;
            \\    godot.core.stringNameNewWithUtf8CharsAndLen(@ptrCast(&self.value), chars.ptr, @intCast(chars.len));
            \\    return self;
            \\}
        );
    }

    // Constructors
    for (builtin.constructors.items) |*constructor| {
        try writeBuiltinConstructor(w, builtin.name, constructor);
    }

    // Destructor
    if (builtin.has_destructor) {
        try writeBuiltinDestructor(w, builtin);
    }

    // Methods
    var methods = builtin.methods.valueIterator();
    while (methods.next()) |method| {
        try writeBuiltinMethod(w, builtin.name, method);
    }

    // Enums
    var enums = builtin.enums.valueIterator();
    while (enums.next()) |@"enum"| {
        try writeEnum(w, @"enum");
    }

    // Declaration end
    w.indent -= 1;
    try w.writeLine("};");

    // Imports
    try writeImports(w, &builtin.imports);
}

fn writeBuiltinConstructor(w: *Writer, self: []const u8, constructor: *const Context.Function) !void {
    try writeFunctionHeader(w, self, constructor);
    try w.printLine(
        \\const constructor = godot.support.bindConstructor({s}, {d});
        \\constructor(@ptrCast(&out), @ptrCast(&args));
    , .{
        self,
        constructor.index.?,
    });
    try writeFunctionFooter(w, constructor);
}

fn writeBuiltinDestructor(w: *Writer, builtin: *const Context.Builtin) !void {
    try w.printLine(
        \\pub fn deinit(self: *{0s}) void {{
        \\    const method = godot.support.bindDestructor({0s});
        \\    method(@ptrCast(self));
        \\}}
        \\
    , .{
        builtin.name,
    });
}

fn writeBuiltinMethod(w: *Writer, self: []const u8, method: *const Context.Function) !void {
    try writeFunctionHeader(w, self, method);
    try w.printLine(
        \\const method = godot.support.bindBuiltinMethod({s}, "{s}", {d});
        \\method({s}, @ptrCast(&args), @ptrCast(&out), args.len);
    , .{
        self,
        method.api_name.?,
        method.hash.?,
        if (method.is_static)
            "null"
        else if (method.is_const)
            "@ptrCast(@constCast(self))"
        else
            "@ptrCast(self)",
    });
    try writeFunctionFooter(w, method);
}

fn writeConstant(w: *Writer, constant: *const Context.Constant) !void {
    try w.print("pub const {s}: ", .{constant.name});
    try writeTypeAtField(w, &constant.type);
    try w.printLine(" = {s};", .{constant.value});
}

fn writeDocBlock(w: *Writer, docs: ?[]const u8) !void {
    if (docs) |d| {
        w.comment = .doc;
        try w.writeLine(d);
        w.comment = .off;
    }
}

fn writeGlobalEnums(ctx: *Context) !void {
    const file = try ctx.config.output.createFile("global.zig", .{});
    defer file.close();

    var buf = bufferedWriter(file.writer());
    var writer = codeWriter(buf.writer().any());

    for (ctx.enums.values()) |*@"enum"| {
        // TODO: shouldSkip functions
        if (std.mem.startsWith(u8, @"enum".name, "Variant.")) continue;
        try writeEnum(&writer, @"enum");
    }

    for (ctx.flags.values()) |flag| {
        // TODO: shouldSkip functions
        if (std.mem.startsWith(u8, flag.name, "Variant.")) continue;
        try writeFlag(&writer, flag);
    }

    try buf.flush();
}

fn writeEnum(w: *Writer, @"enum": *const Context.Enum) !void {
    try w.printLine("pub const {s} = enum(i32) {{", .{@"enum".name});
    w.indent += 1;
    var values = @"enum".values.valueIterator();
    while (values.next()) |value| {
        try writeDocBlock(w, value.doc);
        try w.printLine("{s} = {d},", .{ value.name, value.value });
    }
    w.indent -= 1;
    try w.writeLine("};");
}

fn writeField(w: *Writer, field: *const Context.Field) !void {
    try writeDocBlock(w, field.doc);
    try w.print("{s}: ", .{field.name});
    try writeTypeAtField(w, &field.type);
    try w.writeLine(
        \\,
        \\
    );
}

fn writeFlag(w: *Writer, flag: Context.Flag) !void {
    try w.printLine("pub const {s} = packed struct(i32) {{", .{flag.name});
    w.indent += 1;
    for (flag.fields) |field| {
        try writeDocBlock(w, field.doc);
        try w.printLine("{s}: bool = {s},", .{ field.name, if (field.default) "true" else "false" });
    }
    if (flag.padding > 0) {
        try w.printLine("_: u{d} = 0,", .{flag.padding});
    }
    for (flag.consts) |@"const"| {
        try writeDocBlock(w, @"const".doc);
        try w.printLine("pub const {s}: {s} = @bitCast(@as(u32, {d}));", .{ @"const".name, flag.name, @"const".value });
    }
    w.indent -= 1;
    try w.writeLine("};");
}

fn writeFunctionHeader(w: *Writer, self: ?[]const u8, function: *const Context.Function) !void {
    try writeDocBlock(w, function.doc);

    // Declaration
    try w.print("pub fn {s}(", .{function.name});

    var is_first = true;

    // Self
    if (!function.is_static) {
        try w.writeAll("self: *");
        if (function.is_const) {
            try w.writeAll("const ");
        }
        try w.writeAll(self orelse "@This()");
        is_first = false;
    }

    // Standard parameters
    var opt: usize = function.parameters.count();
    for (function.parameters.values(), 0..) |param, i| {
        if (param.default != null) {
            opt = i;
            break;
        }
        if (!is_first) {
            try w.writeAll(", ");
        }
        try w.print("{s}: ", .{param.name});
        try writeTypeAtParameter(w, param.type);
        is_first = false;
    }

    // Variadic parameters
    if (function.is_vararg) {
        if (!is_first) {
            try w.writeAll(", ");
        }
        try w.print("@\"...\": anytype", .{});
        is_first = false;
    }

    // Optional parameters
    if (opt < function.parameters.count()) {
        if (!is_first) {
            try w.writeAll(", ");
        }
        try w.writeAll("opt: struct { ");
        is_first = true;
        for (function.parameters.values()[opt..]) |param| {
            if (!is_first) {
                try w.writeAll(", ");
            }
            try w.print("{s}: ", .{param.name});
            try writeTypeAtField(w, &param.type);
            try w.print(" = {s}", .{param.default.?});
            is_first = false;
        }
        try w.writeAll(" }");
        is_first = false;
    }

    // Return type
    try w.writeAll(") ");
    try writeTypeAtReturn(w, &function.return_type);
    try w.writeLine(" {");
    w.indent += 1;

    // Parameter comptime type checking
    for (function.parameters.values()) |_| {
        // try generateFunctionParameterTypeCheck(w, param);
    }

    // Variadic argument type checking
    if (function.is_vararg) {
        // try w.writeLine(
        //     \\inline for (0..@"...".len) |i| {
        //     \\    godot.debug.assertVariantLike(@field(@"...", i));
        //     \\}
        // );
    }

    // Fixed argument slice variable
    if (!function.is_vararg) {
        // todo: parameter comptime coercisions
        try w.printLine("var args: [{d}]godot.c.GDExtensionConstTypePtr = undefined;", .{function.parameters.count()});
        for (function.parameters.values()[0..opt], 0..) |param, i| {
            try w.printLine("args[{d}] = @ptrCast(&{s});", .{ i, param.name });
        }
        for (function.parameters.values()[opt..], opt..) |param, i| {
            try w.printLine("args[{d}] = @ptrCast(&opt.{s});", .{ i, param.name });
        }
    }

    // Variadic argument slice variable
    if (function.is_vararg) {
        try w.printLine("var args: [@\"...\".len + {d}]godot.c.GDExtensionConstTypePtr = undefined;", .{function.parameters.count()});
        for (function.parameters.values()[0..opt], 0..) |param, i| {
            try w.printLine("args[{d}] = &godot.Variant.init(&{s});", .{ i, param.name });
        }
        for (function.parameters.values()[opt..], opt..) |param, i| {
            try w.printLine("args[{d}] = &godot.Variant.init(&opt.{s});", .{ i, param.name });
        }
        try w.printLine(
            \\inline for (0..@"...".len) |i| {{
            \\  args[{d} + i] = &godot.Variant.init(@field(@"...", i));
            \\}}
        , .{function.parameters.count()});
    }

    // Return variable
    if (function.return_type != .void) {
        if (function.is_vararg) {
            try w.writeLine("var out: godot.Variant = undefined;");
        } else {
            try w.writeAll("var out: ");
            try writeTypeAtReturn(w, &function.return_type);
            try w.writeLine(" = undefined;");
        }
    }
}

fn writeFunctionFooter(w: *Writer, function: *const Context.Function) !void {
    // Return the value
    if (function.return_type != .void) {
        // Fixed arity functions
        if (!function.is_vararg) {
            try w.writeLine(
                \\return out;
            );
        }

        // Variadic functions
        if (function.is_vararg) {
            try w.writeAll("return out.as(");
            try writeTypeAtReturn(w, &function.return_type);
            try w.writeLine(");");
        }
    }

    // Return for variable argument funtions
    if (function.is_vararg and function.return_type != .void) {
        // @panic("todo");
    }

    // End function
    w.indent -= 1;
    try w.writeLine(
        \\}
        \\
    );
}

fn writeImports(w: *Writer, imports: *const Context.Imports) !void {
    try w.writeLine(
        \\const godot = @import("../root.zig");
    );

    var iter = imports.iterator();
    while (iter.next()) |import| {
        if (util.isBuiltinType(import.*)) continue;

        if (std.mem.startsWith(u8, import.*, "Vector")) {
            try w.printLine("const {0s} = @import(\"vector\").{0s};", .{import.*});
        } else if (std.mem.eql(u8, import.*, "Variant")) {
            try w.writeLine("const Variant = @import(\"../Variant.zig\").Variant;");
        } else if (std.mem.eql(u8, import.*, "global")) {
            try w.writeLine("const global = @import(\"global.zig\");");
        } else {
            try w.printLine("const {0s} = @import(\"core.zig\").{0s};", .{import.*});
        }
    }
}

fn writeModules(ctx: *Context) !void {
    for (ctx.modules.values()) |*module| {
        const filename = try std.fmt.allocPrint(ctx.allocator, "{s}.zig", .{module.name});
        defer ctx.allocator.free(filename);

        const file = try ctx.config.output.createFile(filename, .{});
        defer file.close();

        var buf = bufferedWriter(file.writer());
        var writer = codeWriter(buf.writer().any());

        try writeModule(&writer, module);

        try buf.flush();
    }
}

fn writeModule(w: *Writer, module: *const Context.Module) !void {
    for (module.functions) |*function| {
        try writeModuleFunction(w, function);
    }
    try writeImports(w, &module.imports);
}

// TO DO IN CONTEXT
// 2. Transform return type (add optional '?' prefix for pointer types)
// 9. Generate function arguments with underscore postfix:
//    - Handle engine class types as 'anytype'
//    - Handle string types as 'anytype' (with exceptions)
//    - Regular types use their actual type
//
// TO DO IN CODEGEN
// 8. Generate self parameter based on proc type:
//    - ClassMethod: 'self: anytype' ????
// 14. Generate argument array setup:
//     - Handle string type conversion with Latin1 chars
// 16. Handle special return value processing:
//     - Engine class returns: convert godot_object pointer to struct
//     - Vararg returns: handle Variant conversion
fn writeModuleFunction(w: *Writer, function: *const Context.Function) !void {
    try writeFunctionHeader(w, null, function);

    try w.printLine(
        \\const function = godot.support.bindFunction("{s}", {d});
        \\function({s}, @ptrCast(&args), args.len);
    , .{
        function.name,
        function.hash.?,
        if (function.return_type != .void) "@ptrCast(&out)" else "null",
    });

    try writeFunctionFooter(w, function);
}

fn writeTypeAtField(w: *Writer, @"type": *const Context.Type) !void {
    switch (@"type".*) {
        .void => try w.writeAll("void"),
        .string => try w.writeAll("String"),
        .string_name => try w.writeAll("StringName"),
        .node_path => try w.writeAll("NodePath"),
        .variant => try w.writeAll("Variant"),
        .many => @panic("cannot format a union types in a struct field position"),
        inline else => |s| try w.writeAll(s),
    }
}

fn writeTypeAtReturn(w: *Writer, @"type": *const Context.Type) !void {
    switch (@"type".*) {
        .void => try w.writeAll("void"),
        .string => try w.writeAll("String"),
        .string_name => try w.writeAll("StringName"),
        .node_path => try w.writeAll("NodePath"),
        .variant => try w.writeAll("Variant"),
        .many => @panic("cannot format a union type in a struct field position"),
        inline else => |s| try w.writeAll(s),
    }
}

/// Writes out a Type for a function parameter. Used to provide `anytype` where we do comptime type
/// checks and coercions.
fn writeTypeAtParameter(w: *Writer, @"type": Context.Type) !void {
    switch (@"type") {
        .void => try w.writeAll("void"),
        .string => try w.writeAll("String"),
        .string_name => try w.writeAll("StringName"),
        .node_path => try w.writeAll("NodePath"),
        .variant => try w.writeAll("Variant"),
        .many => @panic("cannot format a union type in a function parameter position"),
        .basic => |name| try w.writeAll(name),
        .class => |name| try w.writeAll(name),
    }
}

/// Writes out code necessary to both assert that arguments are the right type, and coerce them
/// into the form necessary to pass to the Godot function.
fn writeTypeCheck(w: *Writer, parameter: Context.Function.Parameter) !void {
    switch (parameter.type) {
        .class => |class| {
            try w.printLine(
                \\godot.debug.assertIs(godot.core.{1s}, {0s});
            , .{ parameter.name, class });
        },
        .node_path => {
            try w.printLine(
                \\godot.debug.assertPathLike({0s});
            , .{parameter.name});
        },
        .string, .string_name => {
            try w.printLine(
                \\godot.debug.assertStringLike({0s});
            , .{parameter.name});
        },
        .variant => {
            try w.printLine(
                \\godot.debug.assertVariantLike({0s});
            , .{parameter.name});
        },
        else => return,
    }
}

fn generateClasses(ctx: *Context) !void {
    for (ctx.api.classes) |class| {
        if (util.shouldSkipClass(class.name)) {
            continue;
        }

        // TODO: avoid allocation?
        const filename = try std.fmt.allocPrint(ctx.allocator, "{s}.zig", .{class.name});
        defer ctx.allocator.free(filename);

        const file = try ctx.config.output.createFile(filename, .{});
        defer file.close();

        var buf = bufferedWriter(file.writer());
        var writer = codeWriter(buf.writer().any());

        try generateClass(&writer, class, ctx);

        try buf.flush();
    }
}

fn generateClass(w: *Writer, class: GodotApi.Class, ctx: *Context) !void {
    try writeDocBlock(w, class.description);

    // TODO: remove this
    var generated_method_map: StringHashMap(void) = .empty;

    try w.printLine("pub const {s} = extern struct {{", .{class.name});
    w.indent += 1;
    try w.writeLine(
        \\pub const Self = @This();
        \\godot_object: ?*anyopaque,
    );
    try generateClassEnums(w, class);
    try generateClassConstants(w, class);
    if (class.findMethod("init") == null) {
        try generateClassInit(w, class.name);
    }
    if (ctx.isSingleton(class.name)) {
        try generateClassSingleton(w, class.name, &generated_method_map, ctx);
    }
    try generateClassMethods(w, class, &generated_method_map, ctx);
    try generateClassVirtualDispatch(w, class, ctx);
    try generateClassInheritedMethods(w, class, ctx);
    w.indent -= 1;
    try w.printLine("}};", .{});

    if (ctx.class_imports.get(class.name)) |imports| {
        try writeImports(w, &imports);
    }
}

fn generateClassEnums(w: *Writer, class: GodotApi.Class) !void {
    const enums = class.enums orelse return;
    for (enums) |@"enum"| {
        try generateClassEnum(w, @"enum");
    }
}

fn generateClassEnum(w: *Writer, @"enum": GodotApi.Class.Enum) !void {
    try w.printLine("pub const {s} = c_int;", .{@"enum".name});
    for (@"enum".values) |value| {
        try w.printLine("pub const {s}: c_int = {d};", .{ value.name, value.value });
    }
}

fn generateClassConstants(w: *Writer, class: GodotApi.Class) !void {
    const constants = class.constants orelse return;
    for (constants) |constant| {
        try generateClassConstant(w, constant);
    }
}

fn generateClassConstant(w: *Writer, constant: GodotApi.Class.Constant) !void {
    try w.printLine("pub const {s}: c_int = {d};", .{ constant.name, constant.value });
}

fn generateClassInit(w: *Writer, class_name: []const u8) !void {
    try w.printLine(
        \\pub fn init() {0s} {{
        \\    return godot.core.init{0s}();
        \\}}
    , .{class_name});
}

fn generateClassMethods(w: *Writer, class: GodotApi.Class, generated_method_map: *StringHashMap(void), ctx: *Context) !void {
    const class_name = ctx.correctName(class.name);
    const is_builtin_class = false;
    const proc_type = ProcType.ClassMethod;

    const methods = class.methods orelse return;

    for (methods) |method| {
        const func_name = method.name;
        const zig_func_name = ctx.getZigFuncName(func_name);

        if (method.is_virtual) {
            continue;
        }
        const return_type = blk: {
            if (is_builtin_class) {
                break :blk ctx.correctType(method.return_type, "");
            } else if (method.return_value) |ret| {
                break :blk ctx.correctType(ret.type, ret.meta);
            } else {
                break :blk "void";
            }
        };

        if (!generated_method_map.contains(zig_func_name)) {
            try generated_method_map.putNoClobber(ctx.allocator, zig_func_name, {});
            try generateProc(w, method, class_name, func_name, return_type, proc_type, ctx);
        }
    }
}

fn generateClassInheritedMethods(w: *Writer, class: GodotApi.Class, ctx: *Context) !void {
    var cur = class;
    while (ctx.api.findParent(cur)) |parent| : (cur = parent) {
        // TODO: is allocation necessary?
        const name = try std.fmt.allocPrint(ctx.allocator, "godot.core.{s}", .{parent.name});
        defer ctx.allocator.free(name);

        const methods = parent.methods orelse continue;

        // TODO: reuse existing generate functions
        for (methods) |method| {
            if (method.isPrivate()) continue;

            const return_type = ctx.getReturnType(.{ .class = method });
            try generateProc(w, method, name, method.name, return_type, .ClassMethod, ctx);
        }
    }
}

fn generateClassVirtualDispatch(w: *Writer, class: GodotApi.Class, ctx: *Context) !void {
    const methods = class.methods orelse return;

    try w.writeLine("pub fn getVirtualDispatch(comptime T: type, p_userdata: ?*anyopaque, p_name: godot.c.GDExtensionConstStringNamePtr) godot.c.GDExtensionClassCallVirtual {");
    w.indent += 1;
    for (methods) |method| {
        const func_name = method.name;
        const casecmp_to_func_name = ctx.getZigFuncName("casecmp_to");

        if (!method.is_virtual) {
            continue;
        }

        try w.printLine(
            \\{{
            \\    var name = String.fromLatin1("{0s}");
            \\    defer name.deinit();
            \\    if (@as(*StringName, @ptrCast(@constCast(p_name))).{1s}(name) == 0 and @hasDecl(T, "{0s}")) {{
            \\        const MethodBinder = struct {{
            \\            pub fn {0s}(p_instance: godot.c.GDExtensionClassInstancePtr, p_args: [*c]const godot.c.GDExtensionConstTypePtr, p_ret: godot.c.GDExtensionTypePtr) callconv(.C) void {{
            \\                const MethodBinder = godot.MethodBinderT(@TypeOf(T.{0s}));
            \\                MethodBinder.bindPtrcall(@ptrCast(@constCast(&T.{0s})), p_instance, p_args, p_ret);
            \\            }}
            \\        }};
            \\        return MethodBinder.{0s};
            \\    }}
            \\}}
        , .{ func_name, casecmp_to_func_name });
    }

    if (class.inherits.len > 0) {
        try w.printLine(
            \\return godot.core.{s}.getVirtualDispatch(T, p_userdata, p_name);
        , .{class.inherits});
    } else {
        try w.writeLine(
            \\_ = T;
            \\_ = p_userdata;
            \\_ = p_name;
            \\return null;
        );
    }
    w.indent -= 1;
    try w.writeLine("}");
}

fn generateClassSingleton(w: *Writer, name: []const u8, generated_method_map: *StringHashMap(void), ctx: *Context) !void {
    try w.printLine(
        \\var instance: ?{0s} = null;
        \\pub fn getSingleton() {0s} {{
        \\    if (instance == null) {{
        \\        const obj = godot.core.globalGetSingleton(@ptrCast(godot.getClassName({0s})));
        \\        instance = .{{ .godot_object = obj }};
        \\    }}
        \\    return instance.?;
        \\}}
    , .{name});

    // TODO: why?
    try generated_method_map.putNoClobber(ctx.allocator, "getSingleton", {});
}

fn generateProc(w: *Writer, fn_node: anytype, class_name: []const u8, func_name: []const u8, return_type_orig: []const u8, comptime proc_type: ProcType, ctx: *Context) !void {
    const zig_func_name = ctx.getZigFuncName(func_name);

    const return_type: []const u8 = blk: {
        if (std.mem.startsWith(u8, return_type_orig, "*")) {
            break :blk try std.fmt.allocPrint(ctx.allocator, "?{s}", .{return_type_orig});
        } else {
            break :blk return_type_orig;
        }
    };

    if (@typeInfo(@TypeOf(fn_node)) != .null) {
        try writeDocBlock(w, fn_node.description);
    }

    try w.print("pub fn {s}(", .{zig_func_name});

    const is_static = proc_type == .ClassMethod and fn_node.is_static;
    const is_vararg = fn_node.is_vararg;

    var args = std.ArrayList([]const u8).init(ctx.allocator);
    defer args.deinit();
    var arg_types = std.ArrayList([]const u8).init(ctx.allocator);
    defer arg_types.deinit();
    const need_return = !std.mem.eql(u8, return_type, "void");
    var is_first_arg = true;
    if (!is_static) {
        if (proc_type == .ClassMethod) {
            _ = try w.write("self: anytype");
            is_first_arg = false;
        }
    }
    const arg_name_postfix = "_"; //to avoid shadowing member function, which is not allowed in Zig

    if (fn_node.arguments) |as| {
        for (as, 0..) |a, i| {
            _ = i;
            const arg_type = ctx.correctType(a.type, "");
            const arg_name = try std.fmt.allocPrint(ctx.allocator, "{s}{s}", .{ a.name, arg_name_postfix });
            // //constructors use Variant to store each argument, which use double/int64_t for float/int internally
            // if (proc_type == .Constructor) {
            //     if (std.mem.eql(u8, arg_type, "f32")) {}
            // }
            if (!is_first_arg) {
                _ = try w.write(", ");
            }
            is_first_arg = false;
            if (ctx.isClass(arg_type)) {
                try w.print("{s}: anytype", .{arg_name});
            } else {
                if (util.isStringType(arg_type)) {
                    try w.print("{s}: anytype", .{arg_name});
                } else {
                    try w.print("{s}: {s}", .{ arg_name, arg_type });
                }
            }

            try args.append(arg_name);
            try arg_types.append(arg_type);
        }
    }

    if (is_vararg) {
        if (!is_first_arg) {
            _ = try w.write(", ");
        }
        const arg_name = "varargs";
        try w.print("{s}: anytype", .{arg_name});
        try args.append(arg_name);
        try arg_types.append("anytype");
    }

    try w.printLine(") {s} {{", .{return_type});

    w.indent += 1;
    if (need_return) {
        if (return_type[0] == '?') {
            try w.printLine("var result:{s} = null;", .{return_type});
        } else {
            try w.printLine("var result:{0s} = undefined;", .{return_type});
        }
    }

    var arg_array: []const u8 = "null";
    var arg_count: []const u8 = "0";

    if (is_vararg) {
        try w.printLine(
            \\const fields = @import("std").meta.fields(@TypeOf(varargs));
            \\var args: [fields.len + {d}]*const godot.Variant = undefined;
        , .{args.items.len - 1});
        for (0..args.items.len - 1) |i| {
            if (util.isStringType(arg_types.items[i])) {
                try w.printLine("args[{d}] = &godot.Variant.init(godot.core.String.fromLatin1({s}));", .{ i, args.items[i] });
            } else {
                try w.printLine("args[{d}] = &godot.Variant.init({s});", .{ i, args.items[i] });
            }
        }
        try w.printLine(
            \\inline for(fields, 0..)|f, i|{{
            \\    args[{d}+i] = &godot.Variant.init(@field(varargs, f.name));
            \\}}
        , .{args.items.len - 1});

        arg_array = "@ptrCast(&args)";
        arg_count = "args.len";
    } else if (args.items.len > 0) {
        try w.printLine("var args:[{d}]godot.c.GDExtensionConstTypePtr = undefined;", .{args.items.len});
        for (args.items, arg_types.items, 0..) |arg, arg_type, i| {
            if (ctx.isClass(arg_types.items[i])) {
                try w.printLine(
                    \\if(@typeInfo(@TypeOf({1s})) == .@"struct") {{ args[{0d}] = @ptrCast(godot.getGodotObjectPtr(&{1s})); }}
                    \\else if(@typeInfo(@TypeOf({1s})) == .optional) {{ args[{0d}] = @ptrCast(godot.getGodotObjectPtr(&{1s}.?)); }}
                    \\else if(@typeInfo(@TypeOf({1s})) == .pointer) {{ args[{0d}] = @ptrCast(godot.getGodotObjectPtr({1s})); }}
                    \\else {{ args[{0d}] = null; }}
                , .{ i, arg });
            } else {
                if (util.isStringType(arg_type)) {
                    try w.printLine("if(@TypeOf({2s}) == {1s}) {{ args[{0d}] = @ptrCast(&{2s}); }} else {{ args[{0d}] = @ptrCast(&{1s}.fromLatin1({2s})); }}", .{ i, arg_type, arg });
                } else {
                    try w.printLine("args[{d}] = @ptrCast(&{s});", .{ i, arg });
                }
            }
        }
        arg_array = "@ptrCast(&args)";
        arg_count = "args.len";
    }

    const result_string = if (need_return) "@ptrCast(&result)" else "null";

    switch (proc_type) {
        .ClassMethod => {
            const self_ptr = if (is_static) "null" else "@ptrCast(godot.getGodotObjectPtr(self).*)";

            try w.printLine("const method = godot.support.bindClassMethod({s}, \"{s}\", {d});", .{
                class_name,
                func_name,
                fn_node.hash,
            });
            if (is_vararg) {
                try w.writeLine("var err:godot.c.GDExtensionCallError = undefined;");
                if (std.mem.eql(u8, return_type, "Variant")) {
                    try w.printLine("godot.core.objectMethodBindCall(method, {s}, @ptrCast(@alignCast(&args[0])), args.len, &result, &err);", .{self_ptr});
                } else {
                    try w.writeLine("var ret: Variant = .nil;");
                    try w.printLine("godot.core.objectMethodBindCall(method, {s}, @ptrCast(@alignCast(&args[0])), args.len, &ret, &err);", .{self_ptr});
                    if (need_return) {
                        try w.printLine("result = ret.as({s});", .{return_type});
                    }
                }
            } else {
                if (ctx.isClass(return_type)) {
                    try w.writeLine("var godot_object:?*anyopaque = null;");
                    try w.printLine("godot.core.objectMethodBindPtrcall(method, {s}, {s}, @ptrCast(&godot_object));", .{ self_ptr, arg_array });
                    try w.printLine("result = {s}{{ .godot_object = godot_object }};", .{util.childType(return_type)});
                } else {
                    try w.printLine("godot.core.objectMethodBindPtrcall(method, {s}, {s}, {s});", .{ self_ptr, arg_array, result_string });
                }
            }
        },
    }

    if (need_return) {
        try w.writeLine("return result;");
    }

    w.indent -= 1;
    try w.writeLine("}");
}

fn generateCore(ctx: *Context) !void {
    const fp_map = ctx.func_pointers;

    const file = try ctx.config.output.createFile("core.zig", .{});
    defer file.close();

    var buf = bufferedWriter(file.writer());
    var w = codeWriter(buf.writer().any());

    try w.writeLine(
        \\const std = @import("std");
        \\const godot = @import("../root.zig");
        \\pub const c = @import("gdextension");
    );

    for (ctx.core_exports.items) |@"export"| {
        if (@"export".path) |path| {
            try w.printLine("pub const {s} = @import(\"{s}.zig\").{s};", .{ @"export".ident, @"export".file, path });
        } else {
            try w.printLine("pub const {s} = @import(\"{s}.zig\");", .{ @"export".ident, @"export".file });
        }
    }

    try w.writeLine(
        \\pub var p_library: godot.c.GDExtensionClassLibraryPtr = null;
        \\const BindingCallbackMap = std.AutoHashMap(StringName, *godot.c.GDExtensionInstanceBindingCallbacks);
    );

    { // TODO: Separate function generateCoreInterfaceVars
        for (comptime std.meta.declarations(gdextension)) |decl| {
            if (std.mem.startsWith(u8, decl.name, "GDExtensionInterface")) {
                // TODO: move all of this name logic out to helpers/Context
                var name_buf: [128]u8 = undefined;
                std.mem.copyForwards(u8, &name_buf, decl.name["GDExtensionInterface".len..]);
                const name = name_buf[0..(decl.name.len - "GDExtensionInterface".len)];
                if (std.mem.eql(u8, name, "FunctionPtr") or std.mem.eql(u8, name, "GetProcAddress")) {
                    continue;
                }
                if (std.mem.startsWith(u8, name, "PlaceHolder")) {
                    std.mem.copyForwards(u8, name_buf[0..], "Placeholder");
                }
                if (std.mem.startsWith(u8, name, "CallableCustomGetUserData")) {
                    std.mem.copyForwards(u8, name_buf[0..], "CallableCustomGetUserdata");
                }
                name_buf[0] = std.ascii.toLower(name_buf[0]);

                const docs = ctx.func_docs.get(decl.name).?;

                try w.printLine(
                    \\{s}
                    \\pub var {s}: std.meta.Child(godot.c.{s}) = undefined;
                , .{ docs, name, decl.name });
            }
        }
    }

    { // TODO: Separate function generateCoreInterfaceInit
        try w.writeLine("pub fn initCore(getProcAddress: std.meta.Child(godot.c.GDExtensionInterfaceGetProcAddress), library: godot.c.GDExtensionClassLibraryPtr) !void {");
        w.indent += 1;
        try w.writeLine("p_library = library;");

        for (comptime std.meta.declarations(gdextension)) |decl| {
            if (std.mem.startsWith(u8, decl.name, "GDExtensionInterface")) {
                // TODO: move all of this name logic out to helpers/Context
                var name_buf: [128]u8 = undefined;
                std.mem.copyForwards(u8, &name_buf, decl.name["GDExtensionInterface".len..]);
                const name = name_buf[0..(decl.name.len - "GDExtensionInterface".len)];
                if (std.mem.eql(u8, name, "FunctionPtr") or std.mem.eql(u8, name, "GetProcAddress")) {
                    continue;
                }
                if (std.mem.startsWith(u8, name, "PlaceHolder")) {
                    std.mem.copyForwards(u8, name_buf[0..], "Placeholder");
                }
                if (std.mem.startsWith(u8, name, "CallableCustomGetUserData")) {
                    std.mem.copyForwards(u8, name_buf[0..], "CallableCustomGetUserdata");
                }
                name_buf[0] = std.ascii.toLower(name_buf[0]);

                const fn_name = fp_map.get(decl.name).?;

                try w.printLine("{s} = @ptrCast(getProcAddress(\"{s}\"));", .{ name, fn_name });
            }
        }

        for (ctx.all_engine_classes.items) |cls| {
            try w.printLine("godot.getClassName({0s}).* = godot.core.StringName.fromComptimeLatin1(\"{0s}\");", .{cls});
        }

        w.indent -= 1;
        try w.writeLine("}");
    }

    // TODO: move into types and remove
    for (ctx.all_engine_classes.items) |cls| {
        const constructor_code =
            \\pub fn init{0s}() {0s} {{
            \\    return .{{
            \\        .godot_object = godot.core.classdbConstructObject(@ptrCast(godot.getClassName({0s})))
            \\    }};
            \\}}
        ;
        if (!ctx.isSingleton(cls)) {
            try w.printLine(constructor_code, .{cls});
        }
    }

    try buf.flush();
}

pub const ProcType = enum {
    ClassMethod,
};

const std = @import("std");
const bufferedWriter = std.io.bufferedWriter;
const StringHashMap = std.StringHashMapUnmanaged;

const gdextension = @import("gdextension");

const Context = @import("Context.zig");
const GodotApi = @import("GodotApi.zig");
const Writer = @import("writer.zig").AnyWriter;
const codeWriter = @import("writer.zig").codeWriter;
const util = @import("util.zig");
