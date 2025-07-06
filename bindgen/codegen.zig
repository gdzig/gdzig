pub fn generate(ctx: *Context) !void {
    try writeBuiltins(ctx);
    try writeClasses(ctx);
    try writeGlobals(ctx);
    try writeInterface(ctx);
    try writeModules(ctx);
}

fn writeBuiltins(ctx: *const Context) !void {
    // builtin.zig
    {
        const file = try ctx.config.output.createFile("builtin.zig", .{});
        defer file.close();

        var buf = bufferedWriter(file.writer());
        var w = codeWriter(buf.writer().any());

        // Variant is a special case, since it is not a generated file.
        try w.writeLine(
            \\pub const Variant = @import("builtin/variant.zig").Variant;
            \\
        );
        for (ctx.builtins.values()) |builtin| {
            try w.printLine(
                \\pub const {1s} = @import("builtin/{0s}.zig").{1s};
            , .{ builtin.module, builtin.name });
        }

        try buf.flush();
    }

    // builtin/[name].zig
    try ctx.config.output.makePath("builtin");
    for (ctx.builtins.values()) |*builtin| {
        const filename = try std.fmt.allocPrint(ctx.arena.allocator(), "builtin/{s}.zig", .{builtin.module});
        const file = try ctx.config.output.createFile(filename, .{});
        defer file.close();

        var buf = bufferedWriter(file.writer());
        var writer = codeWriter(buf.writer().any());

        try writeBuiltin(&writer, builtin, ctx);

        try buf.flush();
    }
}

fn writeBuiltin(w: *Writer, builtin: *const Context.Builtin, ctx: *const Context) !void {
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
        try w.printLine(
            \\/// {0s} is an opaque data structure; these bytes are not meant to be accessed directly.
            \\_: [{1d}]u8,
            \\
        , .{ builtin.name, builtin.size });
    } else if (builtin.fields.count() > 0) {
        for (builtin.fields.values()) |*field| {
            if (field.offset != null) {
                try writeField(w, field);
            }
        }
    }

    // Constants
    for (builtin.constants.values()) |*constant| {
        try writeConstant(w, constant);
    }
    if (builtin.constants.count() > 0) {
        try w.writeLine("");
    }

    // Hardcoded constructors
    // TODO: move the hardcoding of these overrides to an overrides module
    if (std.mem.eql(u8, builtin.name, "String")) {
        try w.writeLine(
            \\pub fn fromLatin1(chars: []const u8) String {
            \\    var self: String = undefined;
            \\    godot.interface.stringNewWithLatin1CharsAndLen(@ptrCast(&self), chars.ptr, @intCast(chars.len));
            \\    return self;
            \\}
            \\
            \\pub fn fromUtf8(chars: []const u8) String {
            \\    var self: String = undefined;
            \\    godot.interface.stringNewWithUtf8CharsAndLen(@ptrCast(&self), chars.ptr, @intCast(chars.len));
            \\    return self;
            \\}
            \\
            \\pub fn fromUtf16(chars: []const godot.char16_t) String {
            \\    var self: String = undefined;
            \\    godot.interface.stringNewWithUtf16CharsAndLen(@ptrCast(&self), chars.ptr, @intCast(chars.len));
            \\    return self;
            \\}
            \\
            \\pub fn fromUtf32(chars: []const godot.char32_t) String {
            \\    var self: String = undefined;
            \\    godot.interface.stringNewWithUtf32CharsAndLen(@ptrCast(&self), chars.ptr, @intCast(chars.len));
            \\    return self;
            \\}
            \\
            \\pub fn fromWide(chars: []const godot.wchar_t) String {
            \\    var self: String = undefined;
            \\    godot.interface.stringNewWithWideCharsAndLen(@ptrCast(&self), chars.ptr, @intCast(chars.len));
            \\    return self;
            \\}
            \\
        );
    }
    if (std.mem.eql(u8, builtin.name, "StringName")) {
        try w.writeLine(
            \\pub fn fromComptimeLatin1(comptime chars: [:0]const u8) StringName {
            \\    var self: StringName = undefined;
            \\    godot.interface.stringNameNewWithLatin1Chars(@ptrCast(&self), chars.ptr, 1);
            \\    return self;
            \\}
            \\
            \\pub fn fromLatin1(chars: [:0]const u8) StringName {
            \\    var self: StringName = undefined;
            \\    godot.interface.stringNameNewWithLatin1Chars(@ptrCast(&self), chars.ptr, 0);
            \\    return self;
            \\}
            \\
            \\pub fn fromUtf8(chars: []const u8) StringName {
            \\    var self: StringName = undefined;
            \\    godot.interface.stringNameNewWithUtf8CharsAndLen(@ptrCast(&self), chars.ptr, @intCast(chars.len));
            \\    return self;
            \\}
            \\
        );
    }

    // Constructors
    for (builtin.constructors.items) |*constructor| {
        try writeBuiltinConstructor(w, builtin.name, constructor);
        try w.writeLine("");
    }

    // Destructor
    if (builtin.has_destructor) {
        try writeBuiltinDestructor(w, builtin);
        try w.writeLine("");
    }

    // Methods
    for (builtin.methods.values()) |*method| {
        try writeBuiltinMethod(w, builtin.name, method);
        try w.writeLine("");
    }

    // Operators
    for (builtin.operators.items) |*operator| {
        try writeBuiltinOperator(w, builtin.name, operator);
        try w.writeLine("");
    }

    // Enums
    for (builtin.enums.values()) |*@"enum"| {
        try writeEnum(w, @"enum");
        try w.writeLine("");
    }

    // Declaration end
    w.indent -= 1;
    try w.writeLine("};");

    // Imports
    try writeImports(w, "..", &builtin.imports, ctx);
}

fn writeBuiltinConstructor(w: *Writer, builtin_name: []const u8, constructor: *const Context.Function) !void {
    try writeFunctionHeader(w, constructor);
    if (constructor.can_init_directly) {
        for (constructor.parameters.values()) |param| {
            try w.printLine(
                \\result.{0s} = blk: {{
                \\    switch (@typeInfo(@TypeOf({1s}))) {{
                \\        .int => break :blk @intCast({1s}),
                \\        .float => break :blk @floatCast({1s}),
                \\        else => break :blk {1s},
                \\    }}
                \\}};
            , .{ param.field_name.?, param.name });
        }
    } else {
        try w.printLine(
            \\const constructor = godot.support.bindConstructor({s}, {d});
            \\constructor(@ptrCast(&result), @ptrCast(&args));
        , .{
            builtin_name,
            constructor.index.?,
        });
    }
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

fn writeBuiltinMethod(w: *Writer, builtin_name: []const u8, method: *const Context.Function) !void {
    try writeFunctionHeader(w, method);
    try w.printLine(
        \\const method = godot.support.bindBuiltinMethod({s}, "{s}", {d});
        \\method({s}, @ptrCast(&args), @ptrCast(&result), args.len);
    , .{
        builtin_name,
        method.name_api,
        method.hash.?,
        switch (method.self) {
            .static => "null",
            .singleton => @panic("singleton builtins not supported"),
            .constant => "@ptrCast(@constCast(self))",
            .mutable => "@ptrCast(self)",
            .value => "@ptrCast(@constCast(&self))",
        },
    });
    try writeFunctionFooter(w, method);
}

fn writeBuiltinOperator(w: *Writer, builtin_name: []const u8, operator: *const Context.Function) !void {
    try writeFunctionHeader(w, operator);

    // Lookup the method
    try w.print("const op = godot.support.bindVariantOperator(.{s}, .forType({s}), ", .{ operator.operator_name.?, builtin_name });
    w.indent += 1;
    if (operator.parameters.getPtr("rhs")) |rhs| {
        try w.writeAll(".forType(");
        try writeTypeAtField(w, &rhs.type);
        try w.writeAll(")");
    } else {
        try w.writeAll("null");
    }
    w.indent -= 1;
    try w.writeLine(");");

    // Call the method
    try w.writeAll("op(");
    w.indent += 1;
    try w.writeAll("@ptrCast(self), ");
    if (operator.parameters.getPtr("rhs")) |_| {
        try w.writeAll("@ptrCast(&rhs), ");
    } else {
        try w.writeAll("null, ");
    }
    try w.writeAll("@ptrCast(&result)");
    w.indent -= 1;
    try w.writeLine(");");

    try writeFunctionFooter(w, operator);
}

fn writeClasses(ctx: *const Context) !void {
    // class.zig
    {
        const file = try ctx.config.output.createFile("class.zig", .{});
        defer file.close();

        var buf = bufferedWriter(file.writer());
        var w = codeWriter(buf.writer().any());

        for (ctx.classes.values()) |class| {
            try w.printLine(
                \\pub const {1s} = @import("class/{0s}.zig").{1s};
            , .{ class.module, class.name });
        }

        try buf.flush();
    }

    // class/[name].zig
    try ctx.config.output.makePath("class");
    for (ctx.classes.values()) |*class| {
        const filename = try std.fmt.allocPrint(ctx.rawAllocator(), "class/{s}.zig", .{class.module});
        defer ctx.rawAllocator().free(filename);

        const file = try ctx.config.output.createFile(filename, .{});
        defer file.close();

        var buf = bufferedWriter(file.writer());
        var writer = codeWriter(buf.writer().any());

        try writeClass(&writer, class, ctx);

        try buf.flush();
    }
}

fn writeClass(w: *Writer, class: *const Context.Class, ctx: *const Context) !void {
    try writeDocBlock(w, class.doc);

    // Declaration start
    try w.printLine(
        \\pub const {0s} = opaque {{
    , .{class.name});
    w.indent += 1;

    // Base class
    if (class.base) |base| {
        try w.printLine(
            \\pub const Base = {0s};
            \\
        , .{base});
    }

    // Singleton storage
    if (class.is_singleton) {
        try w.printLine(
            \\pub var instance: ?*{0s} = null;
        , .{class.name});
    }

    // Constants
    for (class.constants.values()) |*constant| {
        try writeConstant(w, constant);
    }
    if (class.constants.count() > 0) {
        try w.writeLine("");
    }

    // Signals
    // for (class.signals.values()) |*signal| {
    //     try writeSignal(w, class.name, signal);
    // }

    // Constructor
    if (class.is_instantiable) {
        if (class.base) |_| {
            try w.printLine(
                \\/// Allocates an empty {0s}.
                \\pub fn init() *{0s} {{
                \\    return @ptrCast(godot.interface.classdbConstructObject(@ptrCast(godot.meta.getNamePtr({0s}))).?);
                \\}}
                \\
            , .{class.name});
        } else {
            try w.printLine(
                \\/// Allocates an empty {0s}.
                \\pub fn init() {0s} {{
                \\    return @ptrCast(godot.interface.classdbConstructObject(@ptrCast(godot.meta.getNamePtr({0s}))).?);
                \\}}
                \\
            , .{class.name});
        }
    }

    // Functions
    for (class.functions.values()) |*function| {
        if (function.mode != .final) continue;
        try writeClassFunction(w, class, function, ctx);
        try w.writeLine("");
    }

    // TODO: write properties and signals

    // Properties
    // for (class.properties.values()) |*property| {
    //     try writeClassProperty(w, class.name, property);
    // }

    // Cast helper
    try w.printLine(
        \\/// Upcasts a child type to a `{0s}`.
        \\///
        \\/// This is a zero cost, compile time operation.
        \\pub fn upcast(value: anytype) *{0s} {{
        \\    return godot.meta.upcast({0s}, value);
        \\}}
        \\
        \\/// Downcasts a parent type to a `{0s}`.
        \\///
        \\/// This operation will fail at compile time if {0s} does not inherit from `@TypeOf(value)`. However,
        \\/// since there is no guarantee that `value` is a `{0s}` at runtime, this function has a runtime cost
        \\/// and may return `null`.
        \\pub fn downcast(value: anytype) !*{0s} {{
        \\    return godot.meta.downcast({0s}, value);
        \\}}
        \\
    , .{
        class.name,
    });

    // Virtual dispatch
    try writeClassVirtualDispatch(w, class, ctx);
    try w.writeLine("");

    // Enums
    for (class.enums.values()) |*@"enum"| {
        try writeEnum(w, @"enum");
        try w.writeLine("");
    }

    // Flags
    for (class.flags.values()) |*flag| {
        try writeFlag(w, flag);
        try w.writeLine("");
    }

    // Declaration end
    w.indent -= 1;
    try w.writeLine("};");

    // Imports
    try writeImports(w, "..", &class.imports, ctx);
}

fn writeClassFunction(w: *Writer, class: *const Context.Class, function: *const Context.Function, ctx: *const Context) !void {
    try writeFunctionHeader(w, function);

    if (class.is_singleton) {
        try w.printLine(
            \\if (instance == null) {{
            \\    instance = @ptrCast(godot.interface.globalGetSingleton(@ptrCast(godot.meta.getNamePtr({0s}))).?);
            \\}}
        , .{class.name});
    }

    if (function.is_vararg) {
        try w.writeLine("var err: godot.c.GDExtensionCallError = undefined;");
    }

    try w.printLine("const method = godot.support.bindClassMethod({s}, \"{s}\", {d});", .{
        function.base.?,
        function.name_api,
        function.hash.?,
    });

    if (function.is_vararg) {
        try w.writeAll("godot.interface.objectMethodBindCall(method, ");
        try writeClassFunctionObjectPtr(w, class, function, ctx);
        try w.printLine(", @ptrCast(@alignCast(&args[0])), args.len, {s}, &err);", .{
            if (function.return_type != .void)
                "@ptrCast(&result)"
            else
                "null",
        });
    } else {
        try w.writeAll("godot.interface.objectMethodBindPtrcall(method, ");
        try writeClassFunctionObjectPtr(w, class, function, ctx);
        try w.printLine(", @ptrCast(&args), {s});", .{
            if (function.return_type != .void)
                "@ptrCast(&result)"
            else
                "null",
        });
    }

    try writeFunctionFooter(w, function);
}

fn writeClassFunctionObjectPtr(w: *Writer, class: *const Context.Class, function: *const Context.Function, ctx: *const Context) !void {
    if (function.self == .static) {
        try w.writeAll("null");
    } else if (class.getNearestSingleton(ctx)) |singleton| {
        if (class.is_singleton) {
            try w.writeAll("@ptrCast(instance)");
        } else {
            try w.print("@ptrCast({s}.instance)", .{singleton.name});
        }
    } else if (function.self == .constant) {
        try w.writeAll("@ptrCast(@constCast(self))");
    } else {
        try w.writeAll("@ptrCast(self)");
    }
}

fn writeClassVirtualDispatch(w: *Writer, class: *const Context.Class, ctx: *const Context) !void {
    try w.writeLine(
        \\pub fn getVirtualDispatch(comptime T: type, p_userdata: ?*anyopaque, p_name: godot.c.GDExtensionConstStringNamePtr) godot.c.GDExtensionClassCallVirtual {
    );
    w.indent += 1;

    // Inherited virtual/abstract functions
    var cur: ?*const Context.Class = class;
    while (cur) |base| : (cur = base.getBasePtr(ctx)) {
        for (base.functions.values()) |*function| {
            if (function.mode == .final) continue;
            try w.printLine(
                \\if (@hasDecl(T, "{0s}") and @import("std").meta.eql(@as(*StringName, @ptrCast(@constCast(p_name))).*, StringName.fromComptimeLatin1("{1s}"))) {{
                \\    const MethodBinder = struct {{
                \\        pub fn {0s}(p_instance: godot.c.GDExtensionClassInstancePtr, p_args: [*c]const godot.c.GDExtensionConstTypePtr, p_ret: godot.c.GDExtensionTypePtr) callconv(.C) void {{
                \\            const MethodBinder = godot.support.MethodBinderT(@TypeOf(T.{0s}));
                \\            MethodBinder.bindPtrcall(@ptrCast(@constCast(&T.{0s})), p_instance, p_args, p_ret);
                \\        }}
                \\    }};
                \\    return MethodBinder.{0s};
                \\}}
            , .{ function.name, function.name_api });
        }
    }

    if (class.base) |base| {
        try w.printLine(
            \\return {s}.getVirtualDispatch(T, p_userdata, p_name);
        , .{base});
    } else {
        try w.writeLine(
            \\_ = T;
            \\_ = p_userdata;
            \\_ = p_name;
            \\return null;
        );
    }

    w.indent -= 1;
    try w.writeLine(
        \\}
    );
}

fn writeConstant(w: *Writer, constant: *const Context.Constant) !void {
    try writeDocBlock(w, constant.doc);
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

fn writeGlobals(ctx: *const Context) !void {
    // global.zig
    {
        const file = try ctx.config.output.createFile("global.zig", .{});
        defer file.close();

        var buf = bufferedWriter(file.writer());
        var w = codeWriter(buf.writer().any());

        for (ctx.enums.values()) |@"enum"| {
            try w.printLine(
                \\pub const {1s} = @import("global/{0s}.zig").{1s};
            , .{ @"enum".module, @"enum".name });
        }

        try w.writeLine("");

        for (ctx.flags.values()) |flag| {
            try w.printLine(
                \\pub const {1s} = @import("global/{0s}.zig").{1s};
            , .{ flag.module, flag.name });
        }

        try buf.flush();
    }

    // global/[name].zig
    try ctx.config.output.makePath("global");
    for (ctx.enums.values()) |*@"enum"| {
        const filename = try std.fmt.allocPrint(ctx.rawAllocator(), "global/{s}.zig", .{@"enum".module});
        defer ctx.rawAllocator().free(filename);

        const file = try ctx.config.output.createFile(filename, .{});
        defer file.close();

        var buf = bufferedWriter(file.writer());
        var writer = codeWriter(buf.writer().any());

        try writeEnum(&writer, @"enum");

        try buf.flush();
    }

    for (ctx.flags.values()) |*flag| {
        const filename = try std.fmt.allocPrint(ctx.rawAllocator(), "global/{s}.zig", .{flag.module});
        defer ctx.rawAllocator().free(filename);

        const file = try ctx.config.output.createFile(filename, .{});
        defer file.close();

        var buf = bufferedWriter(file.writer());
        var writer = codeWriter(buf.writer().any());

        try writeFlag(&writer, flag);

        try buf.flush();
    }
}

fn writeEnum(w: *Writer, @"enum": *const Context.Enum) !void {
    try writeDocBlock(w, @"enum".doc);
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

fn writeFlag(w: *Writer, flag: *const Context.Flag) !void {
    try writeDocBlock(w, flag.doc);
    try w.printLine("pub const {s} = packed struct({s}) {{", .{
        flag.name, switch (flag.representation) {
            .u32 => "u32",
            .u64 => "u64",
        },
    });
    w.indent += 1;
    for (flag.fields.values()) |field| {
        try writeDocBlock(w, field.doc);
        try w.printLine("{s}: bool = {s},", .{ field.name, if (field.default) "true" else "false" });
    }
    if (flag.padding > 0) {
        try w.printLine("_: u{d} = 0,", .{flag.padding});
    }
    for (flag.consts.values()) |@"const"| {
        try writeDocBlock(w, @"const".doc);
        try w.printLine("pub const {s}: {s} = @bitCast(@as({s}, {d}));", .{ @"const".name, flag.name, switch (flag.representation) {
            .u32 => "u32",
            .u64 => "u64",
        }, @"const".value });
    }
    w.indent -= 1;
    try w.writeLine("};");
}

fn writeFunctionHeader(w: *Writer, function: *const Context.Function) !void {
    try writeDocBlock(w, function.doc);

    // Declaration
    try w.writeAll("");
    if (std.zig.Token.keywords.has(function.name)) {
        try w.print("pub fn @\"{s}\"(", .{function.name});
    } else {
        try w.print("pub fn {s}(", .{function.name});
    }

    var is_first = true;

    // Self parameter
    switch (function.self) {
        .static, .singleton => {},
        .constant => |self| {
            try w.print("self: *const {0s}", .{self});
            is_first = false;
        },
        .mutable => |self| {
            try w.print("self: *{0s}", .{self});
            is_first = false;
        },
        .value => |self| {
            try w.print("self: {0s}", .{self});
            is_first = false;
        },
    }

    // Positional parameters
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
        try writeTypeAtParameter(w, &param.type);
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
            if (std.mem.eql(u8, "null", param.default.?)) {
                try w.writeAll("?");
            }
            try writeTypeAtOptionalParameterField(w, &param.type);
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
    if (!function.is_vararg and function.operator_name == null and !function.can_init_directly) {
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
    if (function.is_vararg and function.operator_name == null) {
        try w.printLine("var args: [@\"...\".len + {d}]godot.c.GDExtensionConstTypePtr = undefined;", .{function.parameters.count()});
        for (function.parameters.values()[0..opt], 0..) |param, i| {
            try w.printLine("args[{d}] = &Variant.init(&{s});", .{ i, param.name });
        }
        for (function.parameters.values()[opt..], opt..) |param, i| {
            try w.printLine("args[{d}] = &Variant.init(&opt.{s});", .{ i, param.name });
        }
        try w.printLine(
            \\inline for (0..@"...".len) |i| {{
            \\    args[{d} + i] = &Variant.init(@"..."[i]);
            \\}}
        , .{function.parameters.count()});
    }

    // Return variable
    if (function.return_type != .void) {
        if (function.is_vararg) {
            try w.writeLine("var result: Variant = .nil;");
        } else {
            try w.writeAll("var result: ");
            if (function.return_type == .class) {
                try w.writeLine("?*anyopaque = null;");
            } else {
                try writeTypeAtReturn(w, &function.return_type);
                if (function.can_init_directly) {
                    try w.writeLine(" = undefined;");
                } else {
                    try w.writeAll(" = std.mem.zeroes(");
                    try writeTypeAtReturn(w, &function.return_type);
                    try w.writeLine(");");
                }
            }
        }
    }
}

fn writeFunctionFooter(w: *Writer, function: *const Context.Function) !void {
    switch (function.return_type) {
        // Class functions need to cast an object pointer
        .class => {
            try w.writeLine(
                \\return @ptrCast(result);
            );
        },

        // Variant return types can always be returned directly, even in a vararg function.
        .variant => {
            try w.writeLine(
                \\return result;
            );
        },

        // Void does nothing.
        .void => {},

        // Vararg and operator functions cast to the return type, fixed arity return directly.
        else => if (function.is_vararg) {
            try w.writeAll("return result.as(");
            try writeTypeAtReturn(w, &function.return_type);
            try w.writeLine(");");
        } else {
            try w.writeLine(
                \\return result;
            );
        },
    }

    // End function
    w.indent -= 1;
    try w.writeLine("}");
}

fn writeImports(w: *Writer, root: []const u8, imports: *const Context.Imports, ctx: *const Context) !void {
    try w.printLine(
        \\const std = @import("std");
        \\const godot = @import("{0s}/gdzig.zig");
    , .{root});

    var iter = imports.iterator();
    while (iter.next()) |import| {
        if (util.isBuiltinType(import.*)) continue;

        if (std.mem.eql(u8, import.*, "Variant")) {
            try w.printLine("const Variant = @import(\"{0s}/builtin/variant.zig\").Variant;", .{root});
        } else if (ctx.builtins.contains(import.*)) {
            try w.printLine("const {1s} = @import(\"{0s}/builtin.zig\").{1s};", .{ root, import.* });
        } else if (ctx.classes.contains(import.*)) {
            try w.printLine("const {1s} = @import(\"{0s}/class.zig\").{1s};", .{ root, import.* });
        } else if (ctx.enums.contains(import.*)) {
            try w.printLine("const {1s} = @import(\"{0s}/global.zig\").{1s};", .{ root, import.* });
        } else if (ctx.flags.contains(import.*)) {
            try w.printLine("const {1s} = @import(\"{0s}/global.zig\").{1s};", .{ root, import.* });
        } else {
            // TODO: native structures?
        }
    }
}

fn writeInterface(ctx: *Context) !void {
    const file = try ctx.config.output.createFile("Interface.zig", .{});
    defer file.close();

    var buf = bufferedWriter(file.writer());
    var w = codeWriter(buf.writer().any());

    try w.writeLine(
        \\const Interface = @This();
        \\
    );
    try w.writeLine(
        \\library: Child(godot.c.GDExtensionClassLibraryPtr),
        \\
    );

    for (ctx.interface.functions.items) |function| {
        try writeDocBlock(&w, function.docs);
        try w.printLine(
            \\{s}: Child(godot.c.{s}),
            \\
        , .{ function.name, function.ptr_type });
    }

    try w.writeLine("pub fn init(getProcAddress: Child(godot.c.GDExtensionInterfaceGetProcAddress), library: Child(godot.c.GDExtensionClassLibraryPtr)) Interface {");
    w.indent += 1;

    try w.writeLine(
        \\const self: Interface = .{
        \\    .library = library,
    );
    w.indent += 1;

    for (ctx.interface.functions.items) |function| {
        try w.printLine(
            \\.{s} = @ptrCast(getProcAddress("{s}").?),
        , .{ function.name, function.api_name });
    }

    w.indent -= 1;
    try w.writeLine(
        \\};
        \\
    );

    for (ctx.builtins.values()) |builtin| {
        try w.printLine(
            \\self.stringNameNewWithLatin1Chars(@ptrCast(getNamePtr(builtin.{0s})), @ptrCast("{1s}"), 1);
        , .{ builtin.name, builtin.name_api });
    }
    for (ctx.classes.values()) |class| {
        try w.printLine(
            \\self.stringNameNewWithLatin1Chars(@ptrCast(getNamePtr(class.{0s})), @ptrCast("{1s}"), 1);
        , .{ class.name, class.name_api });
    }
    for (ctx.enums.values()) |@"enum"| {
        try w.printLine(
            \\self.stringNameNewWithLatin1Chars(@ptrCast(getNamePtr(global.{0s})), @ptrCast("{1s}"), 1);
        , .{ @"enum".name, @"enum".name_api });
    }
    for (ctx.flags.values()) |flag| {
        try w.printLine(
            \\self.stringNameNewWithLatin1Chars(@ptrCast(getNamePtr(global.{0s})), @ptrCast("{1s}"), 1);
        , .{ flag.name, flag.name_api });
    }

    w.indent -= 1;
    try w.writeLine(
        \\
        \\    return self;
        \\}
    );

    try w.writeLine(
        \\const std = @import("std");
        \\const Child = std.meta.Child;
        \\
        \\const godot = @import("gdzig.zig");
        \\const builtin = godot.builtin;
        \\const class = godot.class;
        \\const global = godot.global;
    );
    try w.writeLine("const getNamePtr = godot.meta.getNamePtr;");

    try buf.flush();
    try file.sync();
}

fn writeModules(ctx: *const Context) !void {
    for (ctx.modules.values()) |*module| {
        const filename = try std.fmt.allocPrint(ctx.rawAllocator(), "{s}.zig", .{module.name});
        defer ctx.rawAllocator().free(filename);

        const file = try ctx.config.output.createFile(filename, .{});
        defer file.close();

        var buf = bufferedWriter(file.writer());
        var writer = codeWriter(buf.writer().any());

        try writeModule(&writer, module, ctx);

        try buf.flush();
    }
}

fn writeModule(w: *Writer, module: *const Context.Module, ctx: *const Context) !void {
    for (module.functions) |*function| {
        try writeModuleFunction(w, function);
    }
    try writeImports(w, ".", &module.imports, ctx);
}

fn writeModuleFunction(w: *Writer, function: *const Context.Function) !void {
    try writeFunctionHeader(w, function);

    try w.printLine(
        \\const function = godot.support.bindFunction("{s}", {d});
        \\function({s}, @ptrCast(&args), args.len);
    , .{
        function.name_api,
        function.hash.?,
        if (function.return_type != .void) "@ptrCast(&result)" else "null",
    });

    try writeFunctionFooter(w, function);
}

fn writeTypeAtField(w: *Writer, @"type": *const Context.Type) !void {
    switch (@"type".*) {
        .array => try w.writeAll("Array"),
        .class => |name| try w.print("*{0s}", .{name}),
        .node_path => try w.writeAll("NodePath"),
        .pointer => |child| {
            try w.writeAll("*");
            try writeTypeAtField(w, child);
        },
        .string => try w.writeAll("String"),
        .string_name => try w.writeAll("StringName"),
        .@"union" => @panic("cannot format a union types in a struct field position"),
        .variant => try w.writeAll("Variant"),
        .void => try w.writeAll("void"),
        inline else => |s| try w.writeAll(s),
    }
}

fn writeTypeAtReturn(w: *Writer, @"type": *const Context.Type) !void {
    switch (@"type".*) {
        .array => try w.writeAll("Array"),
        .class => |name| try w.print("?*{0s}", .{name}),
        .node_path => try w.writeAll("NodePath"),
        .pointer => |child| {
            try w.writeAll("*");
            try writeTypeAtField(w, child);
        },
        .string => try w.writeAll("String"),
        .string_name => try w.writeAll("StringName"),
        .@"union" => @panic("cannot format a union type in a return position"),
        .variant => try w.writeAll("Variant"),
        .void => try w.writeAll("void"),
        inline else => |s| try w.writeAll(s),
    }
}

/// Writes out a Type for a function parameter. Used to provide `anytype` where we do comptime type
/// checks and coercions.
fn writeTypeAtParameter(w: *Writer, @"type": *const Context.Type) !void {
    switch (@"type".*) {
        .array => try w.writeAll("Array"),
        .class => |name| try w.print("*{0s}", .{name}),
        .node_path => try w.writeAll("NodePath"),
        .pointer => |child| {
            try w.writeAll("*");
            try writeTypeAtField(w, child);
        },
        .string => try w.writeAll("String"),
        .string_name => try w.writeAll("StringName"),
        .@"union" => @panic("cannot format a union type in a function parameter position"),
        .variant => try w.writeAll("Variant"),
        .void => try w.writeAll("void"),
        inline else => |s| try w.writeAll(s),
    }
}

/// Writes out a Type for a function parameter. Used to provide `anytype` where we do comptime type
/// checks and coercions.
fn writeTypeAtOptionalParameterField(w: *Writer, @"type": *const Context.Type) !void {
    switch (@"type".*) {
        .array => try w.writeAll("Array"),
        .class => |name| try w.print("*{0s}", .{name}),
        .node_path => try w.writeAll("NodePath"),
        .pointer => |child| {
            try w.writeAll("*");
            try writeTypeAtField(w, child);
        },
        .string => try w.writeAll("String"),
        .string_name => try w.writeAll("StringName"),
        .@"union" => @panic("cannot format a union type in a function parameter position"),
        .variant => try w.writeAll("Variant"),
        .void => try w.writeAll("void"),
        inline else => |s| try w.writeAll(s),
    }
}

/// Writes out code necessary to both assert that arguments are the right type, and coerce them
/// into the form necessary to pass to the Godot function.
fn writeTypeCheck(w: *Writer, parameter: *const Context.Function.Parameter) !void {
    switch (parameter.type) {
        .class => |class| {
            try w.printLine(
                \\godot.debug.assertIs(godot.class.{1s}, {0s});
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

const std = @import("std");
const bufferedWriter = std.io.bufferedWriter;

const Context = @import("Context.zig");
const Writer = @import("writer.zig").AnyWriter;
const codeWriter = @import("writer.zig").codeWriter;
const util = @import("util.zig");
