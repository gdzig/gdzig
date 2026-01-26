pub fn generate(ctx: *Context) !void {
    try writeBuiltins(ctx);
    try writeClasses(ctx);
    try writeGlobals(ctx);
    try writeDispatchTable(ctx);
    try writeModules(ctx);
}

fn writeBuiltins(ctx: *const Context) !void {
    var buf: [1024]u8 = undefined;

    // builtin.zig
    {
        const file = try ctx.config.output.createFile("builtin.zig", .{});
        defer file.close();

        var file_writer = file.writer(&buf);
        var writer = &file_writer.interface;
        var w: CodeWriter = .init(writer);

        try writeMixin(&w, "builtin.mixin.zig", .{}, ctx);

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

        try w.writeLine(
            \\
            \\test {
            \\  @import("std").testing.refAllDecls(@This());
            \\}
        );

        try writer.flush();
    }

    // builtin/[name].zig
    try ctx.config.output.makePath("builtin");

    for (ctx.builtins.values()) |*builtin| {
        const filename = try std.fmt.allocPrint(ctx.arena.allocator(), "builtin/{s}.zig", .{builtin.module});
        const file = try ctx.config.output.createFile(filename, .{});
        defer file.close();

        var file_writer = file.writer(&buf);
        var writer = &file_writer.interface;
        var cw = CodeWriter.init(writer);

        try writeBuiltin(&cw, builtin, ctx);

        try writer.flush();
    }
}

fn writeBuiltin(w: *CodeWriter, builtin: *const Context.Builtin, ctx: *const Context) !void {
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
                try writeField(w, field, null, ctx);
            }
        }
    }

    // Constants
    for (builtin.constants.values()) |*constant| {
        if (constant.skip) continue;

        try writeConstant(w, constant, null, ctx);
    }

    if (builtin.constants.count() > 0) {
        try w.writeLine("");
    }

    // Constructors
    for (builtin.constructors.values()) |*constructor| {
        if (constructor.skip) continue;

        try writeBuiltinConstructor(w, builtin.name, constructor, ctx);
        try w.writeLine("");
    }

    // Destructor
    if (builtin.has_destructor) {
        try writeBuiltinDestructor(w, builtin);
        try w.writeLine("");
    }

    // Methods
    for (builtin.methods.values()) |*method| {
        if (method.skip) continue;

        try writeBuiltinMethod(w, builtin.name, method, ctx);
        try w.writeLine("");
    }

    // Operators
    for (builtin.operators.items) |*operator| {
        try writeBuiltinOperator(w, builtin.name, operator, ctx);
        try w.writeLine("");
    }

    // Enums
    for (builtin.enums.values()) |*@"enum"| {
        try writeEnum(w, @"enum", ctx);
        try w.writeLine("");
    }

    // Helpers
    try w.printLine(
        \\/// Returns an opaque pointer to the {0s}.
        \\pub fn ptr(self: *{0s}) *anyopaque {{
        \\    return @ptrCast(self);
        \\}}
        \\
        \\/// Returns a constant opaque pointer to the {0s}.
        \\pub fn constPtr(self: *const {0s}) *const anyopaque {{
        \\    return @ptrCast(self);
        \\}}
        \\
    , .{builtin.name});

    // Mixin
    try writeMixin(w, "builtin/{s}.mixin.zig", .{builtin.name}, ctx);

    // Declaration end
    w.indent -= 1;
    try w.writeLine("};");

    // Imports
    try writeImports(w, &builtin.imports, null, ctx);
}

fn writeBuiltinConstructor(w: *CodeWriter, builtin_name: []const u8, constructor: *const Context.Function, ctx: *const Context) !void {
    try writeFunctionHeader(w, constructor, null, ctx);
    if (constructor.can_init_directly) {
        for (constructor.parameters.values()) |param| {
            if (param.type.castFunction()) |cast_fn| {
                try w.printLine(
                    \\result.{0s} = {2s}({1s});
                , .{ param.field_name.?, param.name, cast_fn });
            } else {
                try w.printLine(
                    \\result.{0s} = {1s};
                , .{ param.field_name.?, param.name });
            }
        }
    } else {
        try w.printLine(
            \\if ({0s}_ptr == null) {{
            \\    {0s}_ptr = raw.variantGetPtrConstructor(@intFromEnum(Variant.Tag.forType({2s})), {1d});
            \\}}
            \\{0s}_ptr.?(@ptrCast(&result), @ptrCast(&args));
        , .{
            constructor.name,
            constructor.index.?,
            builtin_name,
        });
    }
    try writeFunctionFooter(w, constructor, null, ctx);
    if (!constructor.can_init_directly) {
        try w.printLine(
            \\var {0s}_ptr: c.GDExtensionPtrConstructor = null;
        , .{constructor.name});
    }
}

fn writeBuiltinDestructor(w: *CodeWriter, builtin: *const Context.Builtin) !void {
    try w.printLine(
        \\pub fn deinit(self: *{0s}) void {{
        \\    if (deinit_ptr == null) {{
        \\        deinit_ptr = raw.variantGetPtrDestructor(@intFromEnum(Variant.Tag.forType({0s}))).?;
        \\    }}
        \\    deinit_ptr.?(@ptrCast(self));
        \\}}
        \\var deinit_ptr: c.GDExtensionPtrDestructor = null;
        \\
    , .{
        builtin.name,
    });
}

fn writeBuiltinMethod(w: *CodeWriter, builtin_name: []const u8, method: *const Context.Function, ctx: *const Context) !void {
    try writeFunctionHeader(w, method, null, ctx);
    try w.printLine(
        \\if ({0s}_ptr == null) {{
        \\    {0s}_ptr = raw.variantGetPtrBuiltinMethod(@intFromEnum(Variant.Tag.forType({3s})), @ptrCast(&StringName.fromComptimeLatin1("{1s}")), {2d}).?;
        \\}}
        \\{0s}_ptr.?({4s}, @ptrCast(&args), @ptrCast(&result), args.len);
    , .{
        method.name,
        method.name_api,
        method.hash.?,
        builtin_name,
        switch (method.self) {
            .static => "null",
            .singleton => @panic("singleton builtins not supported"),
            .constant => "@ptrCast(@constCast(self))",
            .mutable => "@ptrCast(self)",
            .value => "@ptrCast(@constCast(&self))",
        },
    });
    try writeFunctionFooter(w, method, null, ctx);
    try w.printLine(
        \\var {0s}_ptr: c.GDExtensionPtrBuiltInMethod = null;
    , .{method.name});
}

fn writeBuiltinOperator(w: *CodeWriter, builtin_name: []const u8, operator: *const Context.Function, ctx: *const Context) !void {
    try writeFunctionHeader(w, operator, null, ctx);

    // Lookup the method
    try w.print(
        \\if ({0s}_ptr == null) {{
        \\    {0s}_ptr = raw.variantGetPtrOperatorEvaluator(@intFromEnum(Variant.Operator.{1s}), @intFromEnum(Variant.Tag.forType({2s})),
    , .{ operator.name, operator.operator_name.?, builtin_name });
    w.indent += 1;
    if (operator.parameters.getPtr("rhs")) |rhs| {
        try w.writeAll(" @intFromEnum(Variant.Tag.forType(");
        try writeTypeAtField(w, &rhs.type, null, ctx);
        try w.writeAll("))");
    } else {
        try w.writeAll(" null");
    }
    w.indent -= 1;
    try w.writeLine(
        \\);
        \\}
    );

    // Call the method
    try w.print("{0s}_ptr.?(", .{operator.name});
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

    try writeFunctionFooter(w, operator, null, ctx);
    try w.printLine(
        \\var {0s}_ptr: c.GDExtensionPtrOperatorEvaluator = null;
    , .{operator.name});
}

fn writeClasses(ctx: *const Context) !void {
    var buf: [1024]u8 = undefined;

    // class.zig
    {
        const file = try ctx.config.output.createFile("class.zig", .{});
        defer file.close();

        var file_writer = file.writer(&buf);
        var writer = &file_writer.interface;
        var w = CodeWriter.init(writer);

        try writeMixin(&w, "class.mixin.zig", .{}, ctx);

        for (ctx.classes.values()) |class| {
            try w.printLine(
                \\pub const {1s} = @import("class/{0s}.zig").{1s};
            , .{ class.module, class.name });
        }

        try w.writeLine(
            \\
            \\test {
            \\  @setEvalBranchQuota(20000);
            \\  @import("std").testing.refAllDecls(@This());
            \\}
        );

        try writer.flush();
    }

    // class/[name].zig
    try ctx.config.output.makePath("class");
    for (ctx.classes.values()) |*class| {
        const filename = try std.fmt.allocPrint(ctx.rawAllocator(), "class/{s}.zig", .{class.module});
        defer ctx.rawAllocator().free(filename);

        const file = try ctx.config.output.createFile(filename, .{});
        defer file.close();

        var file_writer = file.writer(&buf);
        var writer = &file_writer.interface;
        var w = CodeWriter.init(writer);

        try writeClass(&w, class, ctx);

        try writer.flush();
    }
}

fn writeClass(w: *CodeWriter, class: *const Context.Class, ctx: *const Context) !void {
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
    } else {
        try w.writeLine(
            \\pub const Base = void;
            \\
        );
    }

    // Singleton storage
    if (class.is_singleton) {
        try w.printLine(
            \\pub var instance: ?*{0s} = null;
        , .{class.name});
    }

    // Constants
    for (class.constants.values()) |*constant| {
        if (constant.skip) continue;

        try writeConstant(w, constant, class, ctx);
    }
    if (class.constants.count() > 0) {
        try w.writeLine("");
    }

    // Signals
    for (class.signals.values()) |*signal| {
        try writeSignal(w, signal, class, ctx);
        try w.writeLine("");
    }

    // Constructor
    if (class.is_instantiable) {
        try w.printLine(
            \\/// Allocates an empty {0s}.
            \\pub fn init() *{0s} {{
            \\    return @ptrCast(raw.classdbConstructObject(@ptrCast(&StringName.fromComptimeLatin1("{1s}"))).?);
            \\}}
            \\
        , .{ class.name, class.name_api });
    }

    // Functions
    for (class.functions.values()) |*function| {
        if (function.skip) continue;

        if (function.mode != .final) continue;
        try writeClassFunction(w, class, function, ctx);
        try w.writeLine("");

        // Write allocating wrapper for vararg functions
        if (function.is_vararg) {
            try writeFunctionAlloc(w, function, class, ctx);
            try w.writeLine("");
        }
    }

    // TODO: write properties and signals

    // Properties
    // for (class.properties.values()) |*property| {
    //     try writeClassProperty(w, class.name, property);
    // }

    // Virtual dispatch
    try writeClassVirtualDispatch(w, class, ctx);
    try w.writeLine("");

    // Enums
    for (class.enums.values()) |*@"enum"| {
        try writeEnum(w, @"enum", ctx);
        try w.writeLine("");
    }

    // Flags
    for (class.flags.values()) |*flag| {
        try writeFlag(w, flag, ctx);
        try w.writeLine("");
    }

    // Self alias and name for mixins
    try w.printLine(
        \\const Self = @This();
        \\const self_name = "{0s}";
        \\
    , .{class.name_api});

    // Mixins (include parent class mixins)
    try writeClassMixins(w, class, ctx);

    // Declaration end
    w.indent -= 1;
    try w.writeLine("};");

    // Imports (with collision detection for signals/enums/flags)
    try writeImports(w, &class.imports, class, ctx);
}

fn writeSignal(w: *CodeWriter, signal: *const Context.Signal, class: *const Context.Class, ctx: *const Context) !void {
    try writeDocBlock(w, signal.doc);
    try w.print("pub const {s} = struct {{", .{signal.struct_name});

    if (signal.parameters.count() > 0) {
        try w.writeLine("");
    }

    w.indent += 1;
    for (signal.parameters.values()) |param| {
        try w.print("{s}: ", .{param.name});
        try w.writeAll("?");
        try writeTypeAtField(w, &param.type, class, ctx);
        try w.writeLine(" = null,");
    }
    w.indent -= 1;

    try w.writeLine("};");
}

fn writeClassFunction(w: *CodeWriter, class: *const Context.Class, function: *const Context.Function, ctx: *const Context) !void {
    // For vararg functions, generate a thin wrapper that does comptime check + delegates to Alloc version
    if (function.is_vararg) {
        try writeClassFunctionVarargWrapper(w, class, function, ctx);
        return;
    }

    try writeFunctionHeader(w, function, class, ctx);

    if (class.is_singleton) {
        try w.writeLine(
            \\if (instance == null) {
            \\    instance = @ptrCast(raw.globalGetSingleton(@ptrCast(&StringName.fromComptimeLatin1(self_name))).?);
            \\}
        );
    }

    try w.printLine(
        \\if ({0s}_ptr == null) {{
        \\    {0s}_ptr = raw.classdbGetMethodBind(@ptrCast(&StringName.fromComptimeLatin1("{2s}")), @ptrCast(&StringName.fromComptimeLatin1("{1s}")), {3d});
        \\}}
    , .{
        function.name,
        function.name_api,
        function.base.?,
        function.hash.?,
    });

    try w.print("raw.objectMethodBindPtrcall({0s}_ptr, ", .{function.name});
    try writeClassFunctionObjectPtr(w, class, function, ctx);
    try w.printLine(", @ptrCast(&args), {s});", .{
        if (function.return_type != .void)
            "@ptrCast(&result)"
        else
            "null",
    });

    try writeFunctionFooter(w, function, class, ctx);
    try w.printLine(
        \\var {0s}_ptr: c.GDExtensionMethodBindPtr = null;
    , .{function.name});
}

/// Writes a thin vararg wrapper that does comptime check and delegates to the Alloc version.
fn writeClassFunctionVarargWrapper(w: *CodeWriter, class: *const Context.Class, function: *const Context.Function, ctx: *const Context) !void {
    try w.writeLine(
        \\/// Guarantees no allocations when calling across the FFI. Passing packed arrays is a compile error; use the Alloc variant.
        \\///
    );
    try writeDocBlock(w, function.doc);

    // Function signature
    if (std.zig.Token.keywords.has(function.name)) {
        try w.print("pub fn @\"{s}\"(", .{function.name});
    } else {
        try w.print("pub fn {s}(", .{function.name});
    }

    var is_first = true;
    const has_self = switch (function.self) {
        .static, .singleton => false,
        else => true,
    };

    if (has_self) {
        try w.print("self: *{s}", .{class.name});
        is_first = false;
    }

    for (function.parameters.values()) |param| {
        if (!is_first) try w.writeAll(", ");
        try w.print("{s}: ", .{param.name});
        try writeTypeAtParameter(w, &param.type, class, ctx);
        is_first = false;
    }

    if (!is_first) try w.writeAll(", ");
    try w.writeAll("@\"...\": anytype) ");
    try writeTypeAtReturn(w, &function.return_type, class, ctx);
    try w.writeLine(" {");
    w.indent += 1;

    // Comptime check - skip Variant type (already a Variant, no wrapping needed)
    try w.printLine(
        \\inline for (0..@"...".len) |_i| {{
        \\    if (@TypeOf(@"..."[_i]) != Variant and comptime Variant.Tag.allocatesForType(@TypeOf(@"..."[_i]))) {{
        \\        @compileError(@typeName(@TypeOf(@"..."[_i])) ++ " requires allocation; use {s}Alloc() or pass a Variant instead.");
        \\    }}
        \\}}
    , .{function.name});

    // Delegate to Alloc version
    if (function.return_type != .void) {
        try w.writeAll("return ");
    }

    if (has_self) {
        try w.print("self.{s}Alloc(", .{function.name});
    } else {
        try w.print("{s}Alloc(", .{function.name});
    }

    is_first = true;
    for (function.parameters.values()) |param| {
        if (!is_first) try w.writeAll(", ");
        try w.print("{s}", .{param.name});
        is_first = false;
    }

    if (!is_first) try w.writeAll(", ");
    try w.writeLine("@\"...\");");

    w.indent -= 1;
    try w.writeLine("}");
}

/// Writes the allocating version of a vararg function that does the actual FFI call.
fn writeFunctionAlloc(w: *CodeWriter, function: *const Context.Function, class: ?*const Context.Class, ctx: *const Context) !void {
    try w.writeLine(
        \\/// Will allocate when calling across the FFI with packed arrays.
        \\///
    );
    try writeDocBlock(w, function.doc);

    // Declaration with Alloc suffix
    if (std.zig.Token.keywords.has(function.name)) {
        try w.print("pub fn @\"{s}Alloc\"(", .{function.name});
    } else {
        try w.print("pub fn {s}Alloc(", .{function.name});
    }

    var is_first = true;

    // Self parameter
    switch (function.self) {
        .static, .singleton => {},
        .constant => |api_name| {
            const name = if (ctx.classes.get(api_name)) |c| c.name else if (ctx.builtins.get(api_name)) |b| b.name else api_name;
            try w.print("self: *const {0s}", .{name});
            is_first = false;
        },
        .mutable => |api_name| {
            const name = if (ctx.classes.get(api_name)) |c| c.name else if (ctx.builtins.get(api_name)) |b| b.name else api_name;
            try w.print("self: *{0s}", .{name});
            is_first = false;
        },
        .value => |api_name| {
            const name = if (ctx.classes.get(api_name)) |c| c.name else if (ctx.builtins.get(api_name)) |b| b.name else api_name;
            try w.print("self: {0s}", .{name});
            is_first = false;
        },
    }

    // Positional parameters
    for (function.parameters.values()) |param| {
        if (!is_first) {
            try w.writeAll(", ");
        }
        try w.print("{s}: ", .{param.name});
        try writeTypeAtParameter(w, &param.type, class, ctx);
        is_first = false;
    }

    // Variadic parameters as anytype
    if (!is_first) {
        try w.writeAll(", ");
    }
    try w.writeAll("@\"...\": anytype");

    // Return type
    try w.writeAll(") ");
    try writeTypeAtReturn(w, &function.return_type, class, ctx);
    try w.writeLine(" {");
    w.indent += 1;

    const param_count = function.parameters.count();

    // Build pointer array to stack-temporary Variants
    try w.printLine("var args: [{d} + @\"...\".len]*Variant = undefined;", .{param_count});

    // Fixed parameters - wrap in Variant (unless already Variant)
    // Use wrap() for non-allocating types, init() for allocating types (packed arrays)
    for (function.parameters.values(), 0..) |param, i| {
        if (param.type == .variant) {
            try w.printLine("args[{d}] = @constCast(&{s});", .{ i, param.name });
        } else {
            // Check if this type requires allocation (packed arrays)
            const needs_alloc = if (param.type == .basic) blk: {
                const name = param.type.basic;
                break :blk std.mem.startsWith(u8, name, "Packed");
            } else false;

            if (needs_alloc) {
                try w.print("args[{d}] = @constCast(&Variant.init(", .{i});
                try writeTypeAtParameter(w, &param.type, class, ctx);
                try w.printLine(", {s}));", .{param.name});
                try w.printLine("defer args[{d}].deinit();", .{i});
            } else {
                try w.print("args[{d}] = @constCast(&Variant.wrap(", .{i});
                try writeTypeAtParameter(w, &param.type, class, ctx);
                try w.printLine(", &{s}));", .{param.name});
            }
        }
    }

    // Varargs - check if already a Variant before wrapping
    // Use wrap() for non-allocating types, init() for allocating types (packed arrays)
    try w.printLine("inline for (0..@\"...\".len, {d}..args.len) |i, j| {{", .{param_count});
    w.indent += 1;
    try w.writeLine("if (@TypeOf(@\"...\"[i]) == Variant) {");
    w.indent += 1;
    try w.writeLine("args[j] = @constCast(&@\"...\"[i]);");
    w.indent -= 1;
    try w.writeLine("} else if (comptime Variant.Tag.allocatesForType(@TypeOf(@\"...\"[i]))) {");
    w.indent += 1;
    try w.writeLine("args[j] = @constCast(&Variant.init(@TypeOf(@\"...\"[i]), @\"...\"[i]));");
    w.indent -= 1;
    try w.writeLine("} else {");
    w.indent += 1;
    try w.writeLine("const val = @\"...\"[i];");
    try w.writeLine("args[j] = @constCast(&Variant.wrap(@TypeOf(val), &val));");
    w.indent -= 1;
    try w.writeLine("}");
    w.indent -= 1;
    try w.writeLine("}");

    // Defer deinit for varargs - only for allocating types (packed arrays)
    try w.printLine("defer inline for (0..@\"...\".len, {d}..args.len) |i, j| {{", .{param_count});
    w.indent += 1;
    try w.writeLine("if (@TypeOf(@\"...\"[i]) != Variant and comptime Variant.Tag.allocatesForType(@TypeOf(@\"...\"[i]))) {");
    w.indent += 1;
    try w.writeLine("args[j].deinit();");
    w.indent -= 1;
    try w.writeLine("}");
    w.indent -= 1;
    try w.writeLine("};");

    // Return variable
    try w.writeLine("var result: Variant = .nil;");

    // Method bind lookup and call
    if (class) |cls| {
        try w.writeLine("var err: c.GDExtensionCallError = undefined;");
        // Class method
        if (cls.is_singleton) {
            try w.writeLine("if (instance == null) {");
            w.indent += 1;
            try w.writeLine("instance = @ptrCast(raw.globalGetSingleton(@ptrCast(&StringName.fromComptimeLatin1(self_name))).?);");
            w.indent -= 1;
            try w.writeLine("}");
        }

        try w.printLine("if ({0s}Alloc_ptr == null) {{", .{function.name});
        w.indent += 1;
        try w.printLine("{0s}Alloc_ptr = raw.classdbGetMethodBind(@ptrCast(&StringName.fromComptimeLatin1(\"{1s}\")), @ptrCast(&StringName.fromComptimeLatin1(\"{2s}\")), {3d});", .{
            function.name,
            function.base.?,
            function.name_api,
            function.hash.?,
        });
        w.indent -= 1;
        try w.writeLine("}");

        try w.print("raw.objectMethodBindCall({0s}Alloc_ptr, ", .{function.name});
        try writeClassFunctionObjectPtr(w, cls, function, ctx);
        try w.writeLine(", @ptrCast(@alignCast(&args[0])), @intCast(args.len), @ptrCast(&result), &err);");
    } else {
        // Utility function
        try w.printLine("if ({0s}Alloc_ptr == null) {{", .{function.name});
        w.indent += 1;
        try w.printLine("{0s}Alloc_ptr = raw.variantGetPtrUtilityFunction(@ptrCast(@constCast(&StringName.fromComptimeLatin1(\"{1s}\"))), {2d});", .{
            function.name,
            function.name_api,
            function.hash.?,
        });
        w.indent -= 1;
        try w.writeLine("}");
        try w.printLine("{0s}Alloc_ptr.?(@ptrCast(&result), @ptrCast(&args), @intCast(args.len));", .{function.name});
    }

    // Return
    switch (function.return_type) {
        .class => try w.writeLine("return @ptrCast(result);"),
        .variant => try w.writeLine("return result;"),
        .void => {},
        else => {
            try w.writeAll("return result.as(");
            try writeTypeAtReturn(w, &function.return_type, class, ctx);
            try w.writeLine(").?;");
        },
    }

    w.indent -= 1;
    try w.writeLine("}");

    // Method bind pointer storage
    if (class != null) {
        try w.printLine("var {0s}Alloc_ptr: c.GDExtensionMethodBindPtr = null;", .{function.name});
    } else {
        try w.printLine("var {0s}Alloc_ptr: c.GDExtensionPtrUtilityFunction = null;", .{function.name});
    }
}

fn writeClassFunctionObjectPtr(w: *CodeWriter, class: *const Context.Class, function: *const Context.Function, ctx: *const Context) !void {
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

fn writeClassVirtualDispatch(w: *CodeWriter, class: *const Context.Class, ctx: *const Context) !void {
    _ = ctx;

    if (class.base) |base| {
        // Derived class - extend parent's VTable
        try w.printLine("pub const VTable = {s}.VTable.extend({s}, .{{", .{ base, class.name });

        w.indent += 1;
        for (class.functions.values()) |*function| {
            if (function.mode == .final) continue;
            try w.printLine("\"{s}\",", .{function.name});
        }
        w.indent -= 1;

        try w.writeLine("});");
    } else {
        // Root Object class - define the base VTable
        try w.printLine("pub const VTable = gdzig.class.VTable({s}, .{{", .{class.name});

        w.indent += 1;
        for (class.functions.values()) |*function| {
            if (function.mode == .final) continue;
            try w.printLine("\"{s}\",", .{function.name});
        }
        w.indent -= 1;

        try w.writeLine("});");
    }

    // Note: Virtual method implementations are not generated here.
    // The VTable uses comptime reflection on the user's type to find and wrap
    // the method implementations, so we only need to list the method names.
}

fn writeConstant(w: *CodeWriter, constant: *const Context.Constant, class: ?*const Context.Class, ctx: *const Context) !void {
    try writeDocBlock(w, constant.doc);
    try w.print("pub const {s}: ", .{constant.name});
    try writeTypeAtField(w, &constant.type, class, ctx);
    try w.printLine(" = {s};", .{constant.value});
}

fn writeDocBlock(w: *CodeWriter, docs: ?[]const u8) !void {
    if (docs) |d| {
        w.comment = .doc;
        try w.writeLine(d);
        w.comment = .off;
    }
}

fn writeGlobals(ctx: *const Context) !void {
    var buf: [1024]u8 = undefined;

    // global.zig
    {
        const file = try ctx.config.output.createFile("global.zig", .{});
        defer file.close();

        var file_writer = file.writer(&buf);
        var writer = &file_writer.interface;
        var w = CodeWriter.init(writer);

        try writeMixin(&w, "global.mixin.zig", .{}, ctx);

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

        // try w.writeLine(
        //     \\
        //     \\test {
        //     \\  @import("std").testing.refAllDecls(@This());
        //     \\}
        // );

        try writer.flush();
    }

    // global/[name].zig
    try ctx.config.output.makePath("global");
    for (ctx.enums.values()) |*@"enum"| {
        const filename = try std.fmt.allocPrint(ctx.rawAllocator(), "global/{s}.zig", .{@"enum".module});
        defer ctx.rawAllocator().free(filename);

        const file = try ctx.config.output.createFile(filename, .{});
        defer file.close();

        var file_writer = file.writer(&buf);
        var writer = &file_writer.interface;
        var w = CodeWriter.init(writer);

        try writeEnum(&w, @"enum", ctx);

        try writer.flush();
    }

    for (ctx.flags.values()) |*flag| {
        const filename = try std.fmt.allocPrint(ctx.rawAllocator(), "global/{s}.zig", .{flag.module});
        defer ctx.rawAllocator().free(filename);

        const file = try ctx.config.output.createFile(filename, .{});
        defer file.close();

        var file_writer = file.writer(&buf);
        var writer = &file_writer.interface;
        var w = CodeWriter.init(writer);

        try writeFlag(&w, flag, ctx);

        try writer.flush();
    }
}

fn writeEnum(w: *CodeWriter, @"enum": *const Context.Enum, ctx: *const Context) !void {
    try writeDocBlock(w, @"enum".doc);
    try w.printLine("pub const {s} = enum(i32) {{", .{@"enum".name});
    w.indent += 1;
    var values = @"enum".values.valueIterator();
    while (values.next()) |value| {
        try writeDocBlock(w, value.doc);
        try w.printLine("{s} = {d},", .{ value.name, value.value });
    }
    try writeMixin(w, "global/{s}.mixin.zig", .{@"enum".name}, ctx);
    w.indent -= 1;
    try w.writeLine("};");
}

fn writeField(w: *CodeWriter, field: *const Context.Field, class: ?*const Context.Class, ctx: *const Context) !void {
    try writeDocBlock(w, field.doc);
    try w.print("{s}: ", .{field.name});
    try writeTypeAtField(w, &field.type, class, ctx);
    try w.writeLine(
        \\,
        \\
    );
}

fn writeFlag(w: *CodeWriter, flag: *const Context.Flag, ctx: *const Context) !void {
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
    try writeMixin(w, "global/{s}.mixin.zig", .{flag.module}, ctx);
    w.indent -= 1;
    try w.writeLine("};");
}

fn writeFunctionHeader(w: *CodeWriter, function: *const Context.Function, class: ?*const Context.Class, ctx: *const Context) !void {
    if (function.is_vararg) {
        try w.writeLine(
            \\/// Guarantees no allocations when calling across the FFI. Passing Transform2d, Aabb, Basis, Transform3d, or Projection is a compile error; use the Alloc variant.
            \\///
        );
    }
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
        .constant => |api_name| {
            // Look up the converted name for the self type
            const name = if (ctx.classes.get(api_name)) |c| c.name else if (ctx.builtins.get(api_name)) |b| b.name else api_name;
            try w.print("self: *const {0s}", .{name});
            is_first = false;
        },
        .mutable => |api_name| {
            const name = if (ctx.classes.get(api_name)) |c| c.name else if (ctx.builtins.get(api_name)) |b| b.name else api_name;
            try w.print("self: *{0s}", .{name});
            is_first = false;
        },
        .value => |api_name| {
            const name = if (ctx.classes.get(api_name)) |c| c.name else if (ctx.builtins.get(api_name)) |b| b.name else api_name;
            try w.print("self: {0s}", .{name});
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
        // For vararg functions, allocating types are passed as Variant
        if (function.is_vararg and param.type.allocatesAsVariant(ctx)) {
            try w.writeAll("Variant");
        } else {
            try writeTypeAtParameter(w, &param.type, class, ctx);
        }
        is_first = false;
    }

    // Variadic parameters
    if (function.is_vararg) {
        if (!is_first) {
            try w.writeAll(", ");
        }
        try w.writeAll("@\"...\": anytype");
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

            // Check if parameter needs runtime initialization
            if (param.needsRuntimeInit(ctx)) {
                // Use nullable type with null default for runtime-init params
                try w.writeAll("?");
                try writeTypeAtOptionalParameterField(w, &param.type, class, ctx);
                try w.writeAll(" = null");
            } else {
                if (param.default.?.isNullable()) {
                    try w.writeAll("?");
                }
                try writeTypeAtOptionalParameterField(w, &param.type, class, ctx);
                try w.writeAll(" = ");
                try writeValue(w, param.default.?, ctx);
            }
            is_first = false;
        }
        try w.writeAll(" }");
        is_first = false;
    }

    // Return type
    try w.writeAll(") ");
    try writeTypeAtReturn(w, &function.return_type, class, ctx);
    try w.writeLine(" {");
    w.indent += 1;

    // Parameter comptime type checking
    for (function.parameters.values()) |_| {
        // try generateFunctionParameterTypeCheck(w, param);
    }

    // Initialize runtime default values
    if (opt < function.parameters.count()) {
        for (function.parameters.values()[opt..]) |param| {
            if (param.needsRuntimeInit(ctx)) {
                try w.print("const actual_{s} = opt.{s} orelse ", .{ param.name, param.name });
                try writeValue(w, param.default.?, ctx);
                try w.writeLine(";");
            }
        }
    }

    // Fixed argument slice variable
    if (!function.is_vararg and function.operator_name == null and !function.can_init_directly) {
        try w.printLine("var args: [{d}]c.GDExtensionConstTypePtr = undefined;", .{function.parameters.count()});
        for (function.parameters.values()[0..opt], 0..) |param, i| {
            try w.printLine("args[{d}] = @ptrCast(&{s});", .{ i, param.name });
        }
        for (function.parameters.values()[opt..], opt..) |param, i| {
            if (param.needsRuntimeInit(ctx)) {
                try w.printLine("args[{d}] = @ptrCast(&actual_{s});", .{ i, param.name });
            } else {
                try w.printLine("args[{d}] = @ptrCast(&opt.{s});", .{ i, param.name });
            }
        }
    }

    // Variadic argument handling
    if (function.is_vararg and function.operator_name == null) {
        const param_count = function.parameters.count();

        // Comptime verification that vararg types don't allocate
        try w.printLine(
            \\inline for (0..@"...".len) |_i| {{
            \\    if (comptime Variant.Tag.allocatesForType(@TypeOf(@"..."[_i]))) {{
            \\        @compileError(@typeName(@TypeOf(@"..."[_i])) ++ " allocates as Variant; use {s}Alloc() or pass a Variant instead.");
            \\    }}
            \\}}
        , .{function.name});

        // Build varargs array
        try w.writeLine("var _varargs: [@\"...\".len]Variant = undefined;");
        try w.writeLine("inline for (0..@\"...\".len) |_i| _varargs[_i] = Variant.init(@TypeOf(@\"...\"[_i]), @\"...\"[_i]);");
        try w.writeLine("defer for (&_varargs) |*v| v.deinit();");

        try w.printLine("var args: [{d} + @\"...\".len]c.GDExtensionConstTypePtr = undefined;", .{param_count});

        for (function.parameters.values()[0..opt], 0..) |param, i| {
            if (param.type == .variant or param.type.allocatesAsVariant(ctx)) {
                try w.printLine("args[{d}] = @ptrCast(&{s});", .{ i, param.name });
            } else {
                try w.print("args[{d}] = @ptrCast(&Variant.init(", .{i});
                try writeTypeAtParameter(w, &param.type, class, ctx);
                try w.printLine(", {s}));", .{param.name});
            }
        }
        for (function.parameters.values()[opt..], opt..) |param, i| {
            if (param.type == .variant or param.type.allocatesAsVariant(ctx)) {
                if (param.needsRuntimeInit(ctx)) {
                    try w.printLine("args[{d}] = @ptrCast(&actual_{s});", .{ i, param.name });
                } else {
                    try w.printLine("args[{d}] = @ptrCast(&opt.{s});", .{ i, param.name });
                }
            } else {
                if (param.needsRuntimeInit(ctx)) {
                    try w.print("args[{d}] = @ptrCast(&Variant.init(", .{i});
                    try writeTypeAtParameter(w, &param.type, class, ctx);
                    try w.printLine(", actual_{s}));", .{param.name});
                } else {
                    try w.print("args[{d}] = @ptrCast(&Variant.init(", .{i});
                    try writeTypeAtParameter(w, &param.type, class, ctx);
                    try w.printLine(", opt.{s}));", .{param.name});
                }
            }
        }

        try w.printLine("inline for (0..@\"...\".len) |_i| args[{d} + _i] = @ptrCast(&_varargs[_i]);", .{param_count});
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
                try writeTypeAtReturn(w, &function.return_type, class, ctx);
                const return_type_initializer = function.return_type.getDefaultInitializer(ctx);

                if (function.can_init_directly) {
                    try w.writeLine(" = undefined;");
                } else if (function.self != .static and return_type_initializer != null) {
                    try w.printLine(" = {s};", .{return_type_initializer.?});
                } else {
                    try w.writeAll(" = std.mem.zeroes(");
                    try writeTypeAtReturn(w, &function.return_type, class, ctx);
                    try w.writeLine(");");
                }
            }
        }
    }
}

fn writeValue(w: *CodeWriter, value: Context.Value, ctx: *const Context) !void {
    switch (value) {
        inline .null, .string => try w.writeAll("null"),
        .boolean => |b| try w.print("{}", .{b}),
        .primitive => |p| try w.writeAll(p),
        .constructor => |c| {
            const type_name = c.type.getName().?;
            const builtin = ctx.builtins.get(type_name) orelse std.debug.panic("Unsupported constructor: {s}", .{type_name});
            if (builtin.findConstructorByArgumentCount(c.args.len)) |function| {
                try w.print("{s}.{s}(", .{ builtin.name, function.name });

                for (c.args, 0..) |arg, i| {
                    const pval = Context.Constant.replacements.get(arg) orelse arg;

                    try w.writeAll(pval);

                    if (i != c.args.len - 1) {
                        try w.writeAll(", ");
                    }
                }
                try w.writeAll(")");
            } else {
                std.debug.panic("Unsupported constructor: {s}", .{type_name});
            }
        },
    }
}

fn writeFunctionFooter(w: *CodeWriter, function: *const Context.Function, class: ?*const Context.Class, ctx: *const Context) !void {
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
            try writeTypeAtReturn(w, &function.return_type, class, ctx);
            try w.writeLine(").?;");
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

fn writeImports(w: *CodeWriter, imports: *const Context.Imports, class: ?*const Context.Class, ctx: *const Context) !void {
    // std first
    try w.writeLine(
        \\
        \\const std = @import("std");
    );

    // Collect imports into separate lists for sorting
    var builtins: std.ArrayList([]const u8) = .empty;
    var classes: std.ArrayList([]const u8) = .empty;
    var globals: std.ArrayList([]const u8) = .empty;
    var typedefs: std.ArrayList([]const u8) = .empty;
    const allocator = ctx.arena.allocator();

    var iter = imports.iterator();
    while (iter.next()) |import| {
        if (util.isBuiltinType(import.*)) continue;

        // Skip the current type being defined (via imports.skip)
        if (imports.skip) |skip| {
            if (std.mem.eql(u8, import.*, skip)) continue;
        }

        if (std.mem.eql(u8, import.*, "Variant")) {
            try builtins.append(allocator, import.*);
        } else if (ctx.builtins.contains(import.*)) {
            try builtins.append(allocator, import.*);
        } else if (ctx.classes.contains(import.*)) {
            try classes.append(allocator, import.*);
        } else if (ctx.enums.contains(import.*)) {
            try globals.append(allocator, import.*);
        } else if (ctx.flags.contains(import.*)) {
            try globals.append(allocator, import.*);
        } else if (ctx.dispatch_table.typedefs.contains(import.*)) {
            try typedefs.append(allocator, import.*);
        } else {
            // TODO: native structures?
        }
    }

    // Sort each list alphabetically
    const sortFn = struct {
        fn cmp(_: void, a: []const u8, b: []const u8) bool {
            return std.mem.order(u8, a, b) == .lt;
        }
    }.cmp;

    std.mem.sort([]const u8, builtins.items, {}, sortFn);
    std.mem.sort([]const u8, classes.items, {}, sortFn);
    std.mem.sort([]const u8, globals.items, {}, sortFn);
    std.mem.sort([]const u8, typedefs.items, {}, sortFn);

    // c (gdextension)
    try w.writeLine(
        \\
        \\const c = @import("gdextension");
    );

    // Write sorted imports (typdefstogether under c)
    for (typedefs.items) |api_name| {
        // Note: We do not currently check for name collisions for interface typedefs.
        try w.printLine("const {0s} = c.{0s};", .{api_name});
    }

    // gdzig with all aliases
    try w.writeLine(
        \\
        \\const gdzig = @import("gdzig");
        \\const raw = &gdzig.raw;
    );

    // Write sorted imports (builtins, classes, globals all together under gdzig)
    // Note: import lists contain API names, but we need to use converted names
    // If a name collides with something in the current class, skip the const alias
    // and the code will use the fully qualified gdzig.class.X / gdzig.builtin.X path
    for (builtins.items) |api_name| {
        const name = if (ctx.builtins.get(api_name)) |b| b.name else api_name;
        // Check if this name collides with a signal/enum/flag in the class
        if (class) |c| {
            if (c.hasCollision(name)) continue;
        }
        try w.printLine("const {0s} = gdzig.builtin.{0s};", .{name});
    }
    for (classes.items) |api_name| {
        const name = if (ctx.classes.get(api_name)) |c| c.name else api_name;
        // Check if this name collides with a signal/enum/flag in the class
        if (class) |c| {
            if (c.hasCollision(name)) continue;
        }
        try w.printLine("const {0s} = gdzig.class.{0s};", .{name});
    }
    for (globals.items) |api_name| {
        const name = if (ctx.enums.get(api_name)) |e| e.name else if (ctx.flags.get(api_name)) |f| f.name else api_name;
        // Check if this name collides with a signal/enum/flag in the class
        if (class) |c| {
            if (c.hasCollision(name)) continue;
        }
        try w.printLine("const {0s} = gdzig.global.{0s};", .{name});
    }
}

/// Writes mixins for a class and all its parent classes.
/// Parent mixins are written first (from root to leaf), so child classes
/// can override or extend parent mixin functionality.
fn writeClassMixins(w: *CodeWriter, class: *const Context.Class, ctx: *const Context) !void {
    // Recurse to parent first (writes from root to leaf)
    if (class.getBasePtr(ctx)) |parent| {
        try writeClassMixins(w, parent, ctx);
    }
    try writeMixin(w, "class/{s}.mixin.zig", .{class.name}, ctx);
}

fn writeMixin(w: *CodeWriter, comptime fmt: []const u8, args: anytype, ctx: *const Context) !void {
    const filename = try std.fmt.allocPrint(ctx.arena.allocator(), fmt, args);
    const file: ?std.fs.File = ctx.config.input.openFile(filename, .{}) catch null;
    if (file) |f| {
        defer f.close();

        var buf: [1024]u8 = undefined;
        var file_reader = f.reader(&buf);
        var reader = &file_reader.interface;

        // Skip lines until we find @mixin start (or copy from beginning if not found)
        var found_start = false;
        while (true) {
            const line = reader.takeDelimiterInclusive('\n') catch |err| switch (err) {
                error.EndOfStream => break,
                else => return err,
            };

            if (std.mem.startsWith(u8, line, "// @mixin start")) {
                found_start = true;
                break;
            }
        }

        // If no @mixin start found, reopen file to read from beginning
        if (!found_start) {
            file_reader.seekTo(0) catch return;
        }

        // Copy lines until we find @mixin stop
        while (true) {
            const line = reader.takeDelimiterInclusive('\n') catch |err| switch (err) {
                error.EndOfStream => break,
                else => return err,
            };

            if (std.mem.startsWith(u8, line, "// @mixin stop")) {
                break;
            }

            try w.writeAll(line);
        }
    }
}

fn writeDispatchTable(ctx: *Context) !void {
    var buf: [1024]u8 = undefined;

    const file = try ctx.config.output.createFile("DispatchTable.zig", .{});
    defer file.close();

    var file_writer = file.writer(&buf);
    var writer = &file_writer.interface;
    var w = CodeWriter.init(writer);

    try w.writeLine(
        \\const DispatchTable = @This();
        \\
    );
    try w.writeLine(
        \\library: Child(c.GDExtensionClassLibraryPtr),
        \\
    );

    // Write struct fields - required (4.1) functions are non-nullable, optional (4.2+) are nullable
    for (ctx.dispatch_table.functions.items) |function| {
        try writeDocBlock(&w, function.docs);
        if (function.isRequired()) {
            try w.printLine(
                \\{s}: Child(c.{s}),
                \\
            , .{ function.name, function.ptr_type });
        } else {
            try w.printLine(
                \\{s}: c.{s},
                \\
            , .{ function.name, function.ptr_type });
        }
    }

    // Write init function
    try w.writeLine("pub fn init(getProcAddress: Child(c.GDExtensionInterfaceGetProcAddress), library: Child(c.GDExtensionClassLibraryPtr)) DispatchTable {");
    w.indent += 1;

    try w.writeLine(
        \\return .{
        \\    .library = library,
    );
    w.indent += 1;

    for (ctx.dispatch_table.functions.items) |function| {
        if (function.isRequired()) {
            try w.printLine(
                \\.{s} = @ptrCast(getProcAddress("{s}").?),
            , .{ function.name, function.api_name });
        } else {
            try w.printLine(
                \\.{s} = @ptrCast(getProcAddress("{s}")),
            , .{ function.name, function.api_name });
        }
    }

    w.indent -= 1;
    try w.writeLine(
        \\};
    );

    w.indent -= 1;
    try w.writeLine(
        \\}
        \\
    );

    try w.writeLine(
        \\const std = @import("std");
        \\const Child = std.meta.Child;
        \\
        \\const c = @import("gdextension");
        \\
        \\const builtin = @import("builtin.zig");
        \\const class = @import("class.zig");
        \\const global = @import("global.zig");
    );

    try writer.flush();
    try file.sync();
}

fn writeModules(ctx: *const Context) !void {
    var buf: [1024]u8 = undefined;

    for (ctx.modules.values()) |*module| {
        const filename = try std.fmt.allocPrint(ctx.rawAllocator(), "{s}.zig", .{module.name});
        defer ctx.rawAllocator().free(filename);

        const file = try ctx.config.output.createFile(filename, .{});
        defer file.close();

        var file_writer = file.writer(&buf);
        var writer = &file_writer.interface;
        var w = CodeWriter.init(writer);

        try writeModule(&w, module, ctx);

        try writer.flush();
    }
}

fn writeModule(w: *CodeWriter, module: *const Context.Module, ctx: *const Context) !void {
    try writeMixin(w, "{s}.mixin.zig", .{module.name}, ctx);

    for (module.functions) |*function| {
        if (function.skip) continue;

        try writeModuleFunction(w, function, ctx);

        // Write allocating wrapper for vararg functions
        if (function.is_vararg) {
            try writeFunctionAlloc(w, function, null, ctx);
        }
    }
    try writeImports(w, &module.imports, null, ctx);
}

fn writeModuleFunction(w: *CodeWriter, function: *const Context.Function, ctx: *const Context) !void {
    // For vararg functions, generate a thin wrapper that does comptime check + delegates to Alloc version
    if (function.is_vararg) {
        try writeModuleFunctionVarargWrapper(w, function, ctx);
        return;
    }

    try writeFunctionHeader(w, function, null, ctx);

    try w.printLine(
        \\if ({0s}_ptr == null) {{
        \\    {0s}_ptr = raw.variantGetPtrUtilityFunction(@ptrCast(@constCast(&StringName.fromComptimeLatin1("{1s}"))), {2d});
        \\}}
        \\{0s}_ptr.?({3s}, @ptrCast(&args), @intCast(args.len));
    , .{
        function.name,
        function.name_api,
        function.hash.?,
        if (function.return_type != .void) "@ptrCast(&result)" else "null",
    });
    try writeFunctionFooter(w, function, null, ctx);
    try w.printLine(
        \\var {0s}_ptr: c.GDExtensionPtrUtilityFunction = null;
        \\
    , .{function.name});
}

/// Writes a thin vararg wrapper for a module function that does comptime check and delegates to the Alloc version.
fn writeModuleFunctionVarargWrapper(w: *CodeWriter, function: *const Context.Function, ctx: *const Context) !void {
    try w.writeLine(
        \\/// Guarantees no allocations when calling across the FFI. Passing packed arrays is a compile error; use the Alloc variant.
        \\///
    );
    try writeDocBlock(w, function.doc);

    // Function signature
    if (std.zig.Token.keywords.has(function.name)) {
        try w.print("pub fn @\"{s}\"(", .{function.name});
    } else {
        try w.print("pub fn {s}(", .{function.name});
    }

    var is_first = true;
    for (function.parameters.values()) |param| {
        if (!is_first) try w.writeAll(", ");
        try w.print("{s}: ", .{param.name});
        try writeTypeAtParameter(w, &param.type, null, ctx);
        is_first = false;
    }

    if (!is_first) try w.writeAll(", ");
    try w.writeAll("@\"...\": anytype) ");
    try writeTypeAtReturn(w, &function.return_type, null, ctx);
    try w.writeLine(" {");
    w.indent += 1;

    // Comptime check - skip Variant type (already a Variant, no wrapping needed)
    try w.printLine(
        \\inline for (0..@"...".len) |_i| {{
        \\    if (@TypeOf(@"..."[_i]) != Variant and comptime Variant.Tag.allocatesForType(@TypeOf(@"..."[_i]))) {{
        \\        @compileError(@typeName(@TypeOf(@"..."[_i])) ++ " requires allocation; use {s}Alloc() or pass a Variant instead.");
        \\    }}
        \\}}
    , .{function.name});

    // Delegate to Alloc version
    if (function.return_type != .void) {
        try w.writeAll("return ");
    }

    try w.print("{s}Alloc(", .{function.name});

    is_first = true;
    for (function.parameters.values()) |param| {
        if (!is_first) try w.writeAll(", ");
        try w.print("{s}", .{param.name});
        is_first = false;
    }

    if (!is_first) try w.writeAll(", ");
    try w.writeLine("@\"...\");");

    w.indent -= 1;
    try w.writeLine("}");
}

/// Converts a possibly qualified type name (e.g., "AStarGrid2D.CellShape") to use converted class prefixes.
/// For qualified names, splits on "." and converts the class prefix.
/// For simple names, looks them up in the appropriate ctx map (enums or flags).
fn convertQualifiedName(api_name: []const u8, ctx: *const Context, comptime map_type: enum { enums, flags }) []const u8 {
    // Check if it's a qualified name (contains a dot)
    if (std.mem.indexOf(u8, api_name, ".")) |dot_idx| {
        const class_api_name = api_name[0..dot_idx];
        const enum_name = api_name[dot_idx..]; // includes the dot
        // Look up the class to get its converted name
        if (ctx.classes.get(class_api_name)) |class| {
            // Return converted class name + original enum/flag suffix
            // We need to allocate, but can use the arena
            return std.fmt.allocPrint(ctx.arena.allocator(), "{s}{s}", .{ class.name, enum_name }) catch api_name;
        }
        // Fallback to original if class not found
        return api_name;
    }

    // Not qualified, look up in the appropriate map
    return switch (map_type) {
        .enums => if (ctx.enums.get(api_name)) |e| e.name else api_name,
        .flags => if (ctx.flags.get(api_name)) |f| f.name else api_name,
    };
}

fn writeTypeAtField(w: *CodeWriter, @"type": *const Context.Type, class: ?*const Context.Class, ctx: *const Context) !void {
    switch (@"type".*) {
        .array => try w.writeAll("Array"),
        .class => |api_name| {
            const name = if (ctx.classes.get(api_name)) |c| c.name else api_name;
            if (class) |cl| if (cl.hasCollision(name)) {
                try w.print("*gdzig.class.{0s}", .{name});
                return;
            };
            try w.print("*{0s}", .{name});
        },
        .node_path => try w.writeAll("NodePath"),
        .pointer => |child| {
            try w.writeAll("*");
            try writeTypeAtField(w, child, class, ctx);
        },
        .string => try w.writeAll("String"),
        .string_name => try w.writeAll("StringName"),
        .@"union" => @panic("cannot format a union types in a struct field position"),
        .variant => try w.writeAll("Variant"),
        .void => try w.writeAll("void"),
        .basic => |api_name| {
            const name = if (ctx.builtins.get(api_name)) |b| b.name else api_name;
            if (class) |cl| if (cl.hasCollision(name)) {
                try w.print("gdzig.builtin.{0s}", .{name});
                return;
            };
            try w.writeAll(name);
        },
        .@"enum" => |api_name| {
            const name = convertQualifiedName(api_name, ctx, .enums);
            if (class) |cl| if (cl.hasCollision(name)) {
                try w.print("gdzig.global.{0s}", .{name});
                return;
            };
            try w.writeAll(name);
        },
        .flag => |api_name| {
            const name = convertQualifiedName(api_name, ctx, .flags);
            if (class) |cl| if (cl.hasCollision(name)) {
                try w.print("gdzig.global.{0s}", .{name});
                return;
            };
            try w.writeAll(name);
        },
        inline else => |s| try w.writeAll(s),
    }
}

fn writeTypeAtReturn(w: *CodeWriter, @"type": *const Context.Type, class: ?*const Context.Class, ctx: *const Context) !void {
    switch (@"type".*) {
        .array => try w.writeAll("Array"),
        .class => |api_name| {
            const name = if (ctx.classes.get(api_name)) |c| c.name else api_name;
            if (class) |cl| if (cl.hasCollision(name)) {
                try w.print("?*gdzig.class.{0s}", .{name});
                return;
            };
            try w.print("?*{0s}", .{name});
        },
        .node_path => try w.writeAll("NodePath"),
        .pointer => |child| {
            try w.writeAll("*");
            try writeTypeAtField(w, child, class, ctx);
        },
        .string => try w.writeAll("String"),
        .string_name => try w.writeAll("StringName"),
        .@"union" => @panic("cannot format a union type in a return position"),
        .variant => try w.writeAll("Variant"),
        .void => try w.writeAll("void"),
        .basic => |api_name| {
            const name = if (ctx.builtins.get(api_name)) |b| b.name else api_name;
            if (class) |cl| if (cl.hasCollision(name)) {
                try w.print("gdzig.builtin.{0s}", .{name});
                return;
            };
            try w.writeAll(name);
        },
        .@"enum" => |api_name| {
            const name = convertQualifiedName(api_name, ctx, .enums);
            if (class) |cl| if (cl.hasCollision(name)) {
                try w.print("gdzig.global.{0s}", .{name});
                return;
            };
            try w.writeAll(name);
        },
        .flag => |api_name| {
            const name = convertQualifiedName(api_name, ctx, .flags);
            if (class) |cl| if (cl.hasCollision(name)) {
                try w.print("gdzig.global.{0s}", .{name});
                return;
            };
            try w.writeAll(name);
        },
        inline else => |s| try w.writeAll(s),
    }
}

/// Writes out a Type for a function parameter. Used to provide `anytype` where we do comptime type
/// checks and coercions.
fn writeTypeAtParameter(w: *CodeWriter, @"type": *const Context.Type, class: ?*const Context.Class, ctx: *const Context) !void {
    switch (@"type".*) {
        .array => try w.writeAll("Array"),
        .class => |api_name| {
            const name = if (ctx.classes.get(api_name)) |c| c.name else api_name;
            if (class) |cl| if (cl.hasCollision(name)) {
                try w.print("*gdzig.class.{0s}", .{name});
                return;
            };
            try w.print("*{0s}", .{name});
        },
        .node_path => try w.writeAll("NodePath"),
        .pointer => |child| {
            try w.writeAll("*");
            try writeTypeAtField(w, child, class, ctx);
        },
        .string => try w.writeAll("String"),
        .string_name => try w.writeAll("StringName"),
        .@"union" => @panic("cannot format a union type in a function parameter position"),
        .variant => try w.writeAll("Variant"),
        .void => try w.writeAll("void"),
        .basic => |api_name| {
            const name = if (ctx.builtins.get(api_name)) |b| b.name else api_name;
            if (class) |cl| if (cl.hasCollision(name)) {
                try w.print("gdzig.builtin.{0s}", .{name});
                return;
            };
            try w.writeAll(name);
        },
        .@"enum" => |api_name| {
            const name = convertQualifiedName(api_name, ctx, .enums);
            if (class) |cl| if (cl.hasCollision(name)) {
                try w.print("gdzig.global.{0s}", .{name});
                return;
            };
            try w.writeAll(name);
        },
        .flag => |api_name| {
            const name = convertQualifiedName(api_name, ctx, .flags);
            if (class) |cl| if (cl.hasCollision(name)) {
                try w.print("gdzig.global.{0s}", .{name});
                return;
            };
            try w.writeAll(name);
        },
        inline else => |s| try w.writeAll(s),
    }
}

/// Writes out a Type for a function parameter. Used to provide `anytype` where we do comptime type
/// checks and coercions.
fn writeTypeAtOptionalParameterField(w: *CodeWriter, @"type": *const Context.Type, class: ?*const Context.Class, ctx: *const Context) !void {
    switch (@"type".*) {
        .array => try w.writeAll("Array"),
        .class => |api_name| {
            const name = if (ctx.classes.get(api_name)) |c| c.name else api_name;
            if (class) |cl| if (cl.hasCollision(name)) {
                try w.print("*gdzig.class.{0s}", .{name});
                return;
            };
            try w.print("*{0s}", .{name});
        },
        .node_path => try w.writeAll("NodePath"),
        .pointer => |child| {
            try w.writeAll("*");
            try writeTypeAtField(w, child, class, ctx);
        },
        .string => try w.writeAll("String"),
        .string_name => try w.writeAll("StringName"),
        .@"union" => @panic("cannot format a union type in a function parameter position"),
        .variant => try w.writeAll("Variant"),
        .void => try w.writeAll("void"),
        .basic => |api_name| {
            const name = if (ctx.builtins.get(api_name)) |b| b.name else api_name;
            if (class) |cl| if (cl.hasCollision(name)) {
                try w.print("gdzig.builtin.{0s}", .{name});
                return;
            };
            try w.writeAll(name);
        },
        .@"enum" => |api_name| {
            const name = convertQualifiedName(api_name, ctx, .enums);
            if (class) |cl| if (cl.hasCollision(name)) {
                try w.print("gdzig.global.{0s}", .{name});
                return;
            };
            try w.writeAll(name);
        },
        .flag => |api_name| {
            const name = convertQualifiedName(api_name, ctx, .flags);
            if (class) |cl| if (cl.hasCollision(name)) {
                try w.print("gdzig.global.{0s}", .{name});
                return;
            };
            try w.writeAll(name);
        },
        inline else => |s| try w.writeAll(s),
    }
}

const std = @import("std");

const CodeWriter = @import("CodeWriter.zig");
const Context = @import("Context.zig");
const util = @import("util.zig");
