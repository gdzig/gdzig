/// Generate the root module and all API binding modules from the built context.
pub fn generate(ctx: *Context) !void {
    try writeRoot(ctx);
    try writeBuiltins(ctx);
    try writeClasses(ctx);
    try writeGlobals(ctx);
    try writeDispatchTable(ctx);
    try writeModules(ctx);
}

fn writeRoot(ctx: *const Context) !void {
    const file = try ctx.config.output.createFile(ctx.config.io, "gdzig.zig", .{});
    defer file.close(ctx.config.io);
    var buf: [1024]u8 = undefined;
    var file_writer = file.writerStreaming(ctx.config.io, &buf);
    var writer: CodeWriter = .init(&file_writer.interface);
    // Keep the source module documentation before generated declarations.
    const mixin_file = try ctx.config.input.openFile(ctx.config.io, "gdzig.mixin.zig", .{});
    defer mixin_file.close(ctx.config.io);
    var mixin_reader = mixin_file.readerStreaming(ctx.config.io, &buf);
    const mixin = try mixin_reader.interface.allocRemaining(ctx.allocator(), .unlimited);
    const marker = std.mem.indexOf(u8, mixin, "// @mixin start") orelse 0;
    try writer.writeAll(mixin[0..marker]);
    if (ctx.config.godot_compatibility_minimum) |minimum| {
        try writer.printLine(
            \\const godot_compatibility_minimum: ?Version = .{{ .major = {d}, .minor = {d}, .patch = {d} }};
            \\/// Effective compile-time compatibility floor, not the actual engine identity.
            \\pub const version: Version = godot_compatibility_minimum.?;
        , .{ minimum.major, minimum.minor, minimum.patch });
    } else {
        try writer.writeLine(
            \\const godot_compatibility_minimum: ?Version = null;
            \\/// Actual engine version, populated during extension initialization.
            \\pub var version: Version = undefined;
        );
    }
    try writer.writeLine("");
    try writer.writeAll(util.mixinContents(mixin));
    try file_writer.interface.flush();
}

fn writeBuiltins(ctx: *const Context) !void {
    var buf: [1024]u8 = undefined;

    // builtin.zig
    {
        const file = try ctx.config.output.createFile(ctx.config.io, "builtin.zig", .{});
        defer file.close(ctx.config.io);

        var file_writer = file.writerStreaming(ctx.config.io, &buf);
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
    try ctx.config.output.createDirPath(ctx.config.io, "builtin");

    for (ctx.builtins.values()) |*builtin| {
        const filename = try std.fmt.allocPrint(ctx.arena.allocator(), "builtin/{s}.zig", .{builtin.module});
        const file = try ctx.config.output.createFile(ctx.config.io, filename, .{});
        defer file.close(ctx.config.io);

        var file_writer = file.writerStreaming(ctx.config.io, &buf);
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

    if (method.selected_hash != null or method.hash_compatibility.items.len == 0) {
        try w.printLine(
            \\if ({0s}_ptr == null) {{
            \\    {0s}_ptr = raw.variantGetPtrBuiltinMethod(@intFromEnum(Variant.Tag.forType({3s})), @ptrCast(&StringName.fromComptimeLatin1("{1s}")), {2d}).?;
            \\}}
            \\{0s}_ptr.?({4s}, @ptrCast(&args), {5s}, args.len);
        , .{
            method.name,
            method.name_api,
            method.selected_hash orelse method.hash.?,
            builtin_name,
            switch (method.self) {
                .static => "null",
                .singleton => @panic("singleton builtins not supported"),
                .constant => "@ptrCast(@constCast(self))",
                .mutable => "@ptrCast(self)",
                .value => "@ptrCast(@constCast(&self))",
            },
            if (method.return_type != .void) "@ptrCast(&result)" else "null",
        });
    } else {
        try w.printLine(
            \\if ({0s}_ptr == null) {{
            \\    {0s}_ptr = raw.variantGetPtrBuiltinMethod(@intFromEnum(Variant.Tag.forType({2s})), @ptrCast(&StringName.fromComptimeLatin1("{1s}")), {3d});
        , .{
            method.name,
            method.name_api,
            builtin_name,
            method.hash.?,
        });
        w.indent += 1;
        try w.writeAll("inline for ([_]i64{ ");
        for (method.hash_compatibility.items, 0..) |compat_hash, i| {
            if (i > 0) try w.writeAll(", ");
            try w.print("{d}", .{compat_hash});
        }
        try w.writeLine(" }) |compat_hash| {");
        w.indent += 1;
        try w.printLine(
            \\if ({0s}_ptr == null) {{
            \\    {0s}_ptr = raw.variantGetPtrBuiltinMethod(@intFromEnum(Variant.Tag.forType({2s})), @ptrCast(&StringName.fromComptimeLatin1("{1s}")), compat_hash);
            \\}}
        , .{
            method.name,
            method.name_api,
            builtin_name,
        });
        w.indent -= 1;
        try w.writeLine("}");
        // Preserve the unresolved-bind failure semantics of the non-compat path.
        try w.printLine("_ = {0s}_ptr.?;", .{method.name});
        w.indent -= 1;
        try w.writeLine("}");
        try w.printLine(
            \\{0s}_ptr.?({1s}, @ptrCast(&args), {2s}, args.len);
        , .{
            method.name,
            switch (method.self) {
                .static => "null",
                .singleton => @panic("singleton builtins not supported"),
                .constant => "@ptrCast(@constCast(self))",
                .mutable => "@ptrCast(self)",
                .value => "@ptrCast(@constCast(&self))",
            },
            if (method.return_type != .void) "@ptrCast(&result)" else "null",
        });
    }
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
        const file = try ctx.config.output.createFile(ctx.config.io, "class.zig", .{});
        defer file.close(ctx.config.io);

        var file_writer = file.writerStreaming(ctx.config.io, &buf);
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
    try ctx.config.output.createDirPath(ctx.config.io, "class");
    for (ctx.classes.values()) |*class| {
        const filename = try std.fmt.allocPrint(ctx.rawAllocator(), "class/{s}.zig", .{class.module});
        defer ctx.rawAllocator().free(filename);

        const file = try ctx.config.output.createFile(ctx.config.io, filename, .{});
        defer file.close(ctx.config.io);

        var file_writer = file.writerStreaming(ctx.config.io, &buf);
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
        if (class.is_refcounted) {
            // Godot leaves a freshly constructed RefCounted's initial reference
            // "pending": refcount is 1, but nothing has claimed it yet. The
            // first time engine code wraps the raw pointer in a Ref<T> (e.g. as
            // a temporary inside some unrelated method call), it silently
            // consumes that pending ref without incrementing the count, so
            // releasing that temporary drops the count to zero and frees the
            // object out from under the caller. Consuming the pending ref here
            // (mirroring Ref<T>::instantiate()) makes init() return an object
            // that is plainly owned at refcount 1, like everything else.
            try w.printLine(
                \\/// Allocates an empty {0s} with a refcount of 1, plainly owned by the caller.
                \\pub fn init() *{0s} {{
                \\    const self: *{0s} = @ptrCast(raw.classdbConstructObject(@ptrCast(&StringName.fromComptimeLatin1("{1s}"))).?);
                \\    _ = self.initRef();
                \\    return self;
                \\}}
                \\
            , .{ class.name, class.name_api });
        } else {
            try w.printLine(
                \\/// Allocates an empty {0s}.
                \\pub fn init() *{0s} {{
                \\    return @ptrCast(raw.classdbConstructObject(@ptrCast(&StringName.fromComptimeLatin1("{1s}"))).?);
                \\}}
                \\
            , .{ class.name, class.name_api });
        }
    }

    // Functions
    for (class.functions.values()) |*function| {
        if (!shouldEmitLegacy(function, ctx)) continue;
        if (function.mode != .final) continue;
        if (function.skip and !function.mixin_override) continue;
        var emitted: Context.Function = function.*;
        const delegate_name = if (function.mixin_override) try std.fmt.allocPrint(ctx.rawAllocator(), "{s}Raw", .{function.name}) else null;
        defer if (delegate_name) |name| ctx.rawAllocator().free(name);
        if (delegate_name) |name| {
            try checkClassDeclarationName(class, name);
            const storage = try std.fmt.allocPrint(ctx.rawAllocator(), "{s}_ptr", .{name});
            defer ctx.rawAllocator().free(storage);
            try checkClassDeclarationName(class, storage);
            if (function.is_vararg) {
                const alloc_name = try std.fmt.allocPrint(ctx.rawAllocator(), "{s}Alloc", .{name});
                defer ctx.rawAllocator().free(alloc_name);
                try checkClassDeclarationName(class, alloc_name);
                const alloc_storage = try std.fmt.allocPrint(ctx.rawAllocator(), "{s}_ptr", .{alloc_name});
                defer ctx.rawAllocator().free(alloc_storage);
                try checkClassDeclarationName(class, alloc_storage);
            }
            emitted.name = name;
            emitted.is_public = false;
        }
        try writeClassFunction(w, class, &emitted, ctx);
        try w.writeLine("");

        // Write allocating wrapper for vararg functions
        if (function.is_vararg) {
            try writeFunctionAlloc(w, &emitted, class, ctx);
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

fn checkClassDeclarationName(class: *const Context.Class, name: []const u8) !void {
    if (class.mixin_names.contains(name) or class.hasCollision(name)) return error.GeneratedDeclarationCollision;
    for (class.functions.values()) |function| {
        if (std.mem.eql(u8, function.name, name)) return error.GeneratedDeclarationCollision;
    }
    for (class.constants.values()) |constant| {
        if (std.mem.eql(u8, constant.name, name)) return error.GeneratedDeclarationCollision;
    }
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

/// Write a standalone class using the real legacy method writer for range tests.
pub fn writeLegacyFixture(
    output: *std.Io.Writer,
    allocator: std.mem.Allocator,
    minimum: ?common.Version,
    call: bool,
    runtime_minor: u32,
) !void {
    try writeBindingFixture(output, allocator, minimum, call, runtime_minor, null, false);
}

/// Write real dispatcher output with a private adapter or an unshimmed range.
pub fn writeDispatchFixture(
    output: *std.Io.Writer,
    allocator: std.mem.Allocator,
    minimum: ?common.Version,
    call: bool,
    runtime_minor: u32,
    adapter: bool,
) !void {
    try writeBindingFixture(output, allocator, minimum, call, runtime_minor, adapter, false);
}

/// Emit a non-vacuous optimized witness whose selected hash reaches an opaque call.
pub fn writeDispatchIrFixture(
    output: *std.Io.Writer,
    allocator: std.mem.Allocator,
    minimum: common.Version,
) !void {
    try writeBindingFixture(output, allocator, minimum, false, 6, true, true);
}

fn writeBindingFixture(
    output: *std.Io.Writer,
    allocator: std.mem.Allocator,
    minimum: ?common.Version,
    call: bool,
    runtime_minor: u32,
    dispatch: ?bool,
    inspect_ir: bool,
) !void {
    var arena: std.heap.ArenaAllocator = .init(allocator);
    defer arena.deinit();
    var ctx: Context = .{
        .arena = &arena,
        .api = undefined,
        .config = undefined,
        .compatibility_minimum = minimum,
    };
    const class: Context.Class = .{ .name = "Probe", .name_api = "Probe" };
    var function: Context.Function = .{
        .name = "probe_4_6_legacy",
        .name_api = "probe",
        .base = "Probe",
        .hash = 111,
        .legacy_range = .{
            .lower = .{ .major = 4, .minor = 6, .patch = 0 },
            .upper = .{ .major = 4, .minor = 7, .patch = 0 },
            .old_hash = 111,
            .layout = .incompatible,
            .adapter = "probe_4_6",
            .available = false,
            .signature = fixtureSignature("fixture"),
        },
    };
    var group = function.legacy_range.?;
    group.available = dispatch orelse false;
    if (dispatch != null) {
        function.name = "probe";
        function.hash = 222;
        function.legacy_range = null;
        function.dispatch_ranges = &.{group};
    }
    var w: CodeWriter = .init(output);
    try w.writeLine(
        \\const std = @import("std");
        \\const Version = @import("common").Version;
        \\const c = struct {
        \\    const GDExtensionMethodBindPtr = ?*anyopaque;
        \\    const GDExtensionConstTypePtr = ?*const anyopaque;
        \\};
        \\const StringName = struct {
        \\    fn fromComptimeLatin1(comptime text: []const u8) u8 { _ = text; return 0; }
        \\};
        \\var lookups: usize = 0;
        \\var calls: usize = 0;
        \\var token: u8 = 0;
        \\extern fn observeHash(hash: i64) void;
        \\const raw = struct {
        \\    fn classdbGetMethodBind(_: *const anyopaque, _: *const anyopaque, hash: i64) c.GDExtensionMethodBindPtr {
        \\        std.debug.assert(hash == 111 or hash == 222);
        \\        if (@hasDecl(@import("root"), "dispatch_ir")) observeHash(hash);
        \\        lookups += 1;
        \\        return &token;
        \\    }
        \\    fn objectMethodBindPtrcall(_: c.GDExtensionMethodBindPtr, _: ?*anyopaque, _: *const anyopaque, result: ?*anyopaque) void {
        \\        std.debug.assert(result == null);
        \\        calls += 1;
        \\    }
        \\};
    );
    try w.printLine(
        "const gdzig = struct {{ {s} version: Version = .{{ .major = 4, .minor = {d}, .patch = 2 }}; }};",
        .{ if (minimum != null) "const" else "var", if (minimum) |value| value.minor else runtime_minor },
    );
    try w.writeLine("const Probe = struct {");
    w.indent += 1;
    try writeClassFunction(&w, &class, &function, &ctx);
    if (dispatch orelse false) {
        var legacy = function;
        legacy.name = "probe_4_6_legacy";
        legacy.hash = 111;
        legacy.dispatch_ranges = &.{};
        legacy.legacy_range = group;
        try writeClassFunction(&w, &class, &legacy, &ctx);
        try w.writeLine("fn probe_4_6() void { @This().probe_4_6_legacy(); }");
    }
    try w.writeLine("test { std.testing.refAllDecls(@This()); }");
    w.indent -= 1;
    try w.writeLine("};");
    try w.writeLine("test { std.testing.refAllDecls(Probe); }");
    try w.writeLine("pub fn main() void {");
    if (call) {
        try w.printLine("    Probe.{s}();", .{function.name});
        try w.printLine("    Probe.{s}();", .{function.name});
        try w.writeLine("    std.debug.assert(lookups == 1 and calls == 2);");
    }
    try w.writeLine("}");
    if (inspect_ir) {
        try w.writeLine("pub const dispatch_ir = true;");
        try w.writeLine("export fn dispatchWitness() void { Probe.probe(); }");
    }
}

fn shouldEmitLegacy(function: *const Context.Function, ctx: *const Context) bool {
    const group = function.legacy_range orelse return true;
    const minimum = ctx.compatibility_minimum orelse return true;
    return minimum.lt(group.upper);
}

fn writeLegacyRangeGuard(w: *CodeWriter, function: *const Context.Function, ctx: *const Context) !void {
    const group = function.legacy_range orelse return;
    if (ctx.compatibility_minimum) |minimum| {
        if (minimum.range(group.lower, group.upper)) return;
    }

    try w.printLine(
        "if (!gdzig.version.range(.{{ .major = {d}, .minor = {d}, .patch = {d} }}, .{{ .major = {d}, .minor = {d}, .patch = {d} }})) {{",
        .{ group.lower.major, group.lower.minor, group.lower.patch, group.upper.major, group.upper.minor, group.upper.patch },
    );
    w.indent += 1;
    const message = try std.fmt.allocPrint(
        ctx.rawAllocator(),
        "{s}.{s} is only valid on Godot [{d}.{d}.{d}, {d}.{d}.{d}); running {{d}}.{{d}}.{{d}}",
        .{ function.base.?, function.name, group.lower.major, group.lower.minor, group.lower.patch, group.upper.major, group.upper.minor, group.upper.patch },
    );
    defer ctx.rawAllocator().free(message);
    try w.printLine("var legacy_message: [{d}]u8 = undefined;", .{message.len + 30});
    try w.printLine(
        "const message = std.fmt.bufPrint(&legacy_message, \"{f}\", .{{ gdzig.version.major, gdzig.version.minor, gdzig.version.patch }}) catch std.debug.panic(\"legacy range message overflow\", .{{}});",
        .{std.zig.fmtString(message)},
    );
    try w.writeLine("@panic(message);");
    w.indent -= 1;
    try w.writeLine("}");
}

fn writeVersionDispatch(
    w: *CodeWriter,
    function: *const Context.Function,
    ctx: *const Context,
) !void {
    for (function.dispatch_ranges) |group| {
        if (ctx.compatibility_minimum) |minimum| {
            if (!minimum.lt(group.upper)) continue;
        }
        try w.printLine(
            "if (gdzig.version.range(.{{ .major = {d}, .minor = {d}, .patch = {d} }}, " ++
                ".{{ .major = {d}, .minor = {d}, .patch = {d} }})) {{",
            .{ group.lower.major, group.lower.minor, group.lower.patch, group.upper.major, group.upper.minor, group.upper.patch },
        );
        w.indent += 1;
        if (group.available) {
            try w.print("return {s}(", .{group.adapter});
            var first = true;
            switch (function.self) {
                .static, .singleton => {},
                else => {
                    try w.writeAll("self");
                    first = false;
                },
            }
            const optional = firstOptionalParameter(function);
            for (function.parameters.values()[0..optional]) |parameter| {
                if (!first) try w.writeAll(", ");
                try w.writeAll(parameter.name);
                first = false;
            }
            if (optional < function.parameters.count()) {
                if (!first) try w.writeAll(", ");
                try w.writeAll("opt");
            }
            try w.writeLine(");");
        } else {
            const message = try missingShimMessage(ctx.rawAllocator(), function, group);
            defer ctx.rawAllocator().free(message);
            try w.printLine("{s}(\"{f}\");", .{
                if (ctx.compatibility_minimum != null) "@compileError" else "@panic",
                std.zig.fmtString(message),
            });
        }
        w.indent -= 1;
        try w.writeLine("}");
    }
}

fn missingShimMessage(
    allocator: std.mem.Allocator,
    function: *const Context.Function,
    group: version_dispatch.Group,
) ![]const u8 {
    return std.fmt.allocPrint(
        allocator,
        "{s}.{s}: Godot {d}.{d}.{d} layout is {t} ({s}) and has no shim; " ++
            "add {s} or build with -Dgodot_compatibility_minimum={d}.{d}.{d}",
        .{ function.base.?, function.name_api, group.lower.major, group.lower.minor, group.lower.patch, group.layout, group.signature.difference, group.adapter, group.upper.major, group.upper.minor, group.upper.patch },
    );
}

fn writeClassFunction(w: *CodeWriter, class: *const Context.Class, function: *const Context.Function, ctx: *const Context) !void {
    if (!shouldEmitLegacy(function, ctx)) return;
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

    try writeClassMethodBind(w, function, "");

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

/// Lazy class bind lookup shared by fixed-arity and Alloc vararg methods.
/// Keep primary first, then API-order compatibility hashes. A null result is
/// deliberately passed to the caller as before, rather than changing failures.
fn writeClassMethodBind(w: *CodeWriter, function: *const Context.Function, suffix: []const u8) !void {
    try w.printLine("if ({s}{s}_ptr == null) {{", .{ function.name, suffix });
    w.indent += 1;
    try w.printLine("{s}{s}_ptr = raw.classdbGetMethodBind(@ptrCast(&StringName.fromComptimeLatin1(\"{s}\")), @ptrCast(&StringName.fromComptimeLatin1(\"{s}\")), {d});", .{
        function.name,                                 suffix, function.base.?, function.name_api,
        function.selected_hash orelse function.hash.?,
    });
    if (function.selected_hash == null and function.dispatch_ranges.len == 0 and
        function.hash_compatibility.items.len > 0)
    {
        try w.writeAll("inline for ([_]i64{ ");
        for (function.hash_compatibility.items, 0..) |hash, i| {
            if (i > 0) try w.writeAll(", ");
            try w.print("{d}", .{hash});
        }
        try w.writeLine(" }) |compat_hash| {");
        w.indent += 1;
        try w.printLine("if ({s}{s}_ptr == null) {{", .{ function.name, suffix });
        w.indent += 1;
        try w.printLine("{s}{s}_ptr = raw.classdbGetMethodBind(@ptrCast(&StringName.fromComptimeLatin1(\"{s}\")), @ptrCast(&StringName.fromComptimeLatin1(\"{s}\")), compat_hash);", .{
            function.name, suffix, function.base.?, function.name_api,
        });
        w.indent -= 1;
        try w.writeLine("}");
        w.indent -= 1;
        try w.writeLine("}");
    }
    w.indent -= 1;
    try w.writeLine("}");
}

/// Writes a thin vararg wrapper that does comptime check and delegates to the Alloc version.
fn writeClassFunctionVarargWrapper(w: *CodeWriter, class: *const Context.Class, function: *const Context.Function, ctx: *const Context) !void {
    try writeFunctionOptions(w, function, class, ctx);
    try w.writeLine(
        \\/// Guarantees no allocations when calling across the FFI. Passing packed arrays is a compile error; use the Alloc variant.
        \\///
    );
    try writeDocBlock(w, function.doc);

    // Function signature
    if (std.zig.Token.keywords.has(function.name)) {
        try w.print("{s}fn @\"{s}\"(", .{ if (function.is_public) "pub " else "", function.name });
    } else {
        try w.print("{s}fn {s}(", .{ if (function.is_public) "pub " else "", function.name });
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

    const opt = firstOptionalParameter(function);
    for (function.parameters.values()[0..opt]) |param| {
        if (!is_first) try w.writeAll(", ");
        try w.print("{s}: ", .{param.name});
        try writeTypeAtParameter(w, &param.type, class, ctx);
        is_first = false;
    }

    if (!is_first) try w.writeAll(", ");
    try w.writeAll("@\"...\": anytype");
    if (opt < function.parameters.count()) {
        try w.writeAll(", opt: ");
        try writeOptionsName(w, function, ctx);
    }
    try w.writeAll(") ");
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
    for (function.parameters.values()[0..opt]) |param| {
        if (!is_first) try w.writeAll(", ");
        try w.print("{s}", .{param.name});
        is_first = false;
    }

    if (!is_first) try w.writeAll(", ");
    try w.writeAll("@\"...\"");
    if (opt < function.parameters.count()) try w.writeAll(", opt");
    try w.writeLine(");");

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
        try w.print("{s}fn @\"{s}Alloc\"(", .{ if (function.is_public) "pub " else "", function.name });
    } else {
        try w.print("{s}fn {s}Alloc(", .{ if (function.is_public) "pub " else "", function.name });
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
    const opt = firstOptionalParameter(function);
    for (function.parameters.values()[0..opt]) |param| {
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
    if (opt < function.parameters.count()) {
        try w.writeAll(", opt: ");
        try writeOptionsName(w, function, ctx);
    }

    // Return type
    try w.writeAll(") ");
    try writeTypeAtReturn(w, &function.return_type, class, ctx);
    try w.writeLine(" {");
    w.indent += 1;

    const param_count = function.parameters.count();
    var defaults: Context.Function = function.*;
    defaults.is_vararg = false;
    try writeRuntimeDefaults(w, &defaults, opt, class, ctx);

    // Build pointer array to stack-temporary Variants
    try w.printLine("var args: [{d} + @\"...\".len]*Variant = undefined;", .{param_count});

    // Fixed parameters - wrap in Variant (unless already Variant)
    // Use wrap() for non-allocating types, init() for allocating types (packed arrays)
    for (function.parameters.values(), 0..) |param, i| {
        var source_buf: [256]u8 = undefined;
        const source = if (i < opt) param.name else try std.fmt.bufPrint(&source_buf, "{s}{s}", .{ if (param.needsRuntimeInit(ctx) or optNullMaterializer(&param, ctx) != null) "actual_" else "opt.", param.name });
        if (param.type == .variant) {
            try w.printLine("args[{d}] = @constCast(&{s});", .{ i, source });
        } else {
            // Check if this type requires allocation (packed arrays)
            const needs_alloc = if (param.type == .basic) blk: {
                const name = param.type.basic;
                break :blk std.mem.startsWith(u8, name, "Packed");
            } else false;

            if (needs_alloc) {
                try w.print("args[{d}] = @constCast(&Variant.init(", .{i});
                try writeTypeAtParameter(w, &param.type, class, ctx);
                try w.printLine(", {s}));", .{source});
                try w.printLine("defer args[{d}].deinit();", .{i});
            } else {
                try w.print("args[{d}] = @constCast(&Variant.wrap(", .{i});
                try writeTypeAtParameter(w, &param.type, class, ctx);
                try w.printLine(", &{s}));", .{source});
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

        try writeClassMethodBind(w, function, "Alloc");

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
        const file = try ctx.config.output.createFile(ctx.config.io, "global.zig", .{});
        defer file.close(ctx.config.io);

        var file_writer = file.writerStreaming(ctx.config.io, &buf);
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
    try ctx.config.output.createDirPath(ctx.config.io, "global");
    for (ctx.enums.values()) |*@"enum"| {
        const filename = try std.fmt.allocPrint(ctx.rawAllocator(), "global/{s}.zig", .{@"enum".module});
        defer ctx.rawAllocator().free(filename);

        const file = try ctx.config.output.createFile(ctx.config.io, filename, .{});
        defer file.close(ctx.config.io);

        var file_writer = file.writerStreaming(ctx.config.io, &buf);
        var writer = &file_writer.interface;
        var w = CodeWriter.init(writer);

        try writeEnum(&w, @"enum", ctx);

        try writer.flush();
    }

    for (ctx.flags.values()) |*flag| {
        const filename = try std.fmt.allocPrint(ctx.rawAllocator(), "global/{s}.zig", .{flag.module});
        defer ctx.rawAllocator().free(filename);

        const file = try ctx.config.output.createFile(ctx.config.io, filename, .{});
        defer file.close(ctx.config.io);

        var file_writer = file.writerStreaming(ctx.config.io, &buf);
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

    // Godot enums sometimes alias multiple names onto the same value (e.g.
    // RenderingDevice.ShaderStage's *_BIT members, or DriverResource's
    // PHYSICAL_DEVICE/VULKAN_PHYSICAL_DEVICE pair). Zig enums can't have
    // duplicate tag values, so only the first-declared name per value (in
    // extension_api.json order) becomes a tag; later names sharing that
    // value are emitted as alias constants instead. Zig requires all
    // container fields before any decls, so alias entries are buffered
    // during this single pass over values and flushed as decls afterward.
    var seen: std.AutoArrayHashMapUnmanaged(i64, []const u8) = .empty;
    defer seen.deinit(ctx.rawAllocator());

    const Alias = struct { doc: ?[]const u8, name: []const u8, first_name: []const u8 };
    var aliases: std.ArrayListUnmanaged(Alias) = .empty;
    defer aliases.deinit(ctx.rawAllocator());

    for (@"enum".values.values()) |value| {
        if (seen.get(value.value)) |first_name| {
            try aliases.append(ctx.rawAllocator(), .{ .doc = value.doc, .name = value.name, .first_name = first_name });
        } else {
            try seen.put(ctx.rawAllocator(), value.value, value.name);

            try writeDocBlock(w, value.doc);
            try w.printLine("{s} = {d},", .{ value.name, value.value });
        }
    }

    for (aliases.items) |alias| {
        try writeDocBlock(w, alias.doc);
        try w.printLine("pub const {s}: @This() = .{s};", .{ alias.name, alias.first_name });
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
        flag.name, flag.representation.name(),
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
        try w.printLine("pub const {s}: {s} = @bitCast(@as({s}, {d}));", .{ @"const".name, flag.name, flag.representation.name(), @"const".value });
    }
    try writeMixin(w, "global/{s}.mixin.zig", .{flag.module}, ctx);
    w.indent -= 1;
    try w.writeLine("};");
}

fn firstOptionalParameter(function: *const Context.Function) usize {
    for (function.parameters.values(), 0..) |param, i| {
        if (param.default != null) return i;
    }
    return function.parameters.count();
}

fn writeOptionsName(w: *CodeWriter, function: *const Context.Function, ctx: *const Context) !void {
    // API names are stable across Raw/Alloc wrappers. Constructors/operators
    // have no unique API method name, so retain their generated Zig names.
    const original = if (function.index != null or function.operator_name != null or std.mem.eql(u8, function.name_api, "_")) function.name else function.name_api;
    const name = try casez.allocConvert(ctx.rawAllocator(), common.gdzig_case.type, original);
    defer ctx.rawAllocator().free(name);
    try w.print("{s}Options", .{name});
}

fn writeFunctionOptions(w: *CodeWriter, function: *const Context.Function, class: ?*const Context.Class, ctx: *const Context) !void {
    const opt = firstOptionalParameter(function);
    if (opt == function.parameters.count()) return;
    if (class) |cls| {
        var name_out: std.Io.Writer.Allocating = .init(ctx.rawAllocator());
        defer name_out.deinit();
        var name_writer: CodeWriter = .init(&name_out.writer);
        try writeOptionsName(&name_writer, function, ctx);
        try checkClassDeclarationName(cls, name_out.written());
    }
    try w.writeAll("pub const ");
    try writeOptionsName(w, function, ctx);
    try w.writeLine(" = struct {");
    w.indent += 1;
    for (function.parameters.values()[opt..]) |param| {
        try w.print("{s}: ", .{param.name});
        if (param.needsRuntimeInit(ctx)) {
            try w.writeAll("?");
            try writeTypeAtOptionalParameterField(w, &param.type, class, ctx);
            try w.writeLine(" = null,");
        } else {
            if (param.default.?.isNullable()) try w.writeAll("?");
            try writeTypeAtOptionalParameterField(w, &param.type, class, ctx);
            try w.writeAll(" = ");
            try writeValue(w, param.default.?, ctx);
            try w.writeLine(",");
        }
    }
    w.indent -= 1;
    try w.writeLine("};");
}

fn writeRuntimeDefaults(w: *CodeWriter, function: *const Context.Function, opt: usize, class: ?*const Context.Class, ctx: *const Context) !void {
    for (function.parameters.values()[opt..]) |param| {
        if (param.needsRuntimeInit(ctx)) {
            const default_value = param.default.?;
            try w.print("{0s} actual_{1s} = opt.{1s} orelse ", .{ if (default_value.runtimeInitNeedsDeinit()) "var" else "const", param.name });
            try writeValue(w, default_value, ctx);
            try w.writeLine(";");
            if (default_value.runtimeInitNeedsDeinit()) try w.printLine("defer if (opt.{0s} == null) actual_{0s}.deinit();", .{param.name});
        } else if (!function.is_vararg and function.operator_name == null and !function.can_init_directly) {
            if (optNullMaterializer(&param, ctx)) |init_expr| {
                try w.print("var actual_{s}: ", .{param.name});
                try writeTypeAtOptionalParameterField(w, &param.type, class, ctx);
                try w.printLine(" = opt.{s} orelse {s};", .{ param.name, init_expr });
                try w.printLine("defer if (opt.{0s} == null) actual_{0s}.deinit();", .{param.name});
            }
        }
    }
}

fn writeFunctionHeader(w: *CodeWriter, function: *const Context.Function, class: ?*const Context.Class, ctx: *const Context) !void {
    try writeFunctionOptions(w, function, class, ctx);
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
        try w.print("{s}fn @\"{s}\"(", .{ if (function.is_public) "pub " else "", function.name });
    } else {
        try w.print("{s}fn {s}(", .{ if (function.is_public) "pub " else "", function.name });
    }

    var is_first = true;
    if (function.type_selected_scalar != .none) {
        try w.writeAll("comptime T: type");
        is_first = false;
    }

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
        // For vararg functions, allocating types are passed as Variant.
        // Type-selected scalar utility functions use generic caller-facing
        // arguments, then marshal through metadata-selected ABI slots below.
        if (function.type_selected_scalar != .none) {
            try w.writeAll("anytype");
        } else if (function.is_vararg and param.type.allocatesAsVariant(ctx)) {
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
        try w.writeAll("opt: ");
        try writeOptionsName(w, function, ctx);
        is_first = false;
    }

    // Return type
    try w.writeAll(") ");
    if (function.type_selected_scalar != .none) {
        try w.writeAll("T");
    } else {
        try writeTypeAtReturn(w, &function.return_type, class, ctx);
    }
    try w.writeLine(" {");
    w.indent += 1;
    try writeLegacyRangeGuard(w, function, ctx);
    if (class != null) try writeVersionDispatch(w, function, ctx);
    switch (function.type_selected_scalar) {
        .none => {},
        .float => try w.writeLine("if (T != f32 and T != f64) @compileError(\"result type must be f32 or f64\");"),
        .int => try w.writeLine("if (T != i32 and T != i64) @compileError(\"result type must be i32 or i64\");"),
    }

    // Parameter comptime type checking
    for (function.parameters.values()) |_| {
        // try generateFunctionParameterTypeCheck(w, param);
    }

    // Initialize runtime default values
    try writeRuntimeDefaults(w, function, opt, class, ctx);

    // Fixed argument slice variable
    if (!function.is_vararg and function.operator_name == null and !function.can_init_directly) {
        try w.printLine("var args: [{d}]c.GDExtensionConstTypePtr = undefined;", .{function.parameters.count()});
        for (function.parameters.values()[0..opt], 0..) |param, i| {
            if (function.type_selected_scalar != .none) {
                try writeTypeSelectedScalarArgSlot(w, i, &param);
            } else {
                try writeArgSlot(w, i, &param, null, ctx);
            }
        }
        for (function.parameters.values()[opt..], opt..) |param, i| {
            const materialized = param.needsRuntimeInit(ctx) or optNullMaterializer(&param, ctx) != null;
            if (function.type_selected_scalar != .none) {
                try writeTypeSelectedScalarArgSlot(w, i, &param);
            } else {
                try writeArgSlot(w, i, &param, materialized, ctx);
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
        } else if (function.type_selected_scalar != .none) {
            switch (function.return_type) {
                .float => try w.writeLine("var result: f64 = 0;"),
                .int => try w.writeLine("var result: i64 = 0;"),
                else => unreachable,
            }
        } else {
            try w.writeAll("var result: ");
            if (function.return_type == .class) {
                try w.writeLine("?*anyopaque = null;");
            } else if (wideSlot(&function.return_type, ctx) != .none) {
                // Widen sub-8-byte scalar/enum/flag returns to an int64 slot so the engine's
                // 8-byte ptrcall write cannot overrun a narrow result; narrowed in the footer.
                try w.writeLine("i64 = 0;");
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

/// For an optional parameter whose nullable default (empty String/Array/Dictionary/...)
/// maps to a by-value builtin, returns the initializer expression used to materialize a
/// real empty value at call time. Godot dereferences these builtins' internal pointers, so
/// a null/undefined optional payload passed as `&opt.name` is a dangling pointer -> segfault.
/// Returns null when the field is safe to pass by address as-is: object/raw pointers (a null
/// ptrcall slot is valid) and concrete-value defaults (non-nullable, already materialized).
fn optNullMaterializer(param: *const Context.Function.Parameter, ctx: *const Context) ?[]const u8 {
    if (param.needsRuntimeInit(ctx)) return null;
    const default = param.default orelse return null;
    if (!default.isNullable()) return null;
    return switch (param.type) {
        .array, .string, .string_name, .node_path => ".init()",
        .variant => ".nil",
        .basic => param.type.getDefaultInitializer(ctx) orelse ".init()",
        else => null, // .class, .pointer: a null ptrcall slot is a valid null object
    };
}

/// How a scalar/enum/flag must be marshalled through the ptrcall ABI, which passes every
/// integer and enum as int64 and every bitfield as int64 (godot-cpp method_ptrcall.h). A
/// sub-8-byte value needs a widened i64 temporary so the engine reads a full 8 bytes for an
/// argument (instead of over-reading adjacent stack) and writes a full 8 bytes into a return
/// slot (instead of over-writing memory past a narrow slot). Floats are already f64 in gdzig
/// and bool is 1 byte (matches uint8_t), so both marshal as `.none`.
///
/// This is the emission-side half of the ABI width rule; `src/class/ptrcall.zig` is the
/// runtime side, reading/writing the widened slots this function decides to emit.
const WideSlot = enum { none, int, @"enum", flag };

fn wideSlot(@"type": *const Context.Type, ctx: *const Context) WideSlot {
    return switch (@"type".*) {
        .int => |name| if (std.mem.eql(u8, name, "i64") or std.mem.eql(u8, name, "u64")) .none else .int,
        // Unconditional: writeEnum always emits `enum(i32)`, so no 64-bit enum exists to guard
        // against, unlike the .int/.flag arms above/below which check the representation width.
        .@"enum" => .@"enum",
        .flag => |api_name| if (std.mem.eql(u8, ctx.flagRepr(api_name), "u64")) .none else .flag,
        else => .none,
    };
}

/// Emits `args[i]`, widening sub-8-byte scalars/enums/flags into an int64 temporary whose
/// address is passed instead of the narrow value's. `materialized` selects the value
/// expression: `null` for a plain required parameter (`p_name`), `true`/`false` for an
/// optional parameter's runtime-materialized (`actual_name`) or as-passed (`opt.name`) form.
fn writeArgSlot(w: *CodeWriter, i: usize, param: *const Context.Function.Parameter, materialized: ?bool, ctx: *const Context) !void {
    var buf: [128]u8 = undefined;
    const src = if (materialized) |use_actual|
        try std.fmt.bufPrint(&buf, "{s}{s}", .{ if (use_actual) "actual_" else "opt.", param.name })
    else
        param.name;

    switch (wideSlot(&param.type, ctx)) {
        .none => try w.printLine("args[{d}] = @ptrCast(&{s});", .{ i, src }),
        .int => {
            try w.printLine("const arg{d}_slot: i64 = @intCast({s});", .{ i, src });
            try w.printLine("args[{d}] = @ptrCast(&arg{d}_slot);", .{ i, i });
        },
        .@"enum" => {
            try w.printLine("const arg{d}_slot: i64 = @intFromEnum({s});", .{ i, src });
            try w.printLine("args[{d}] = @ptrCast(&arg{d}_slot);", .{ i, i });
        },
        .flag => {
            try w.printLine("const arg{d}_slot: i64 = @as({s}, @bitCast({s}));", .{ i, ctx.flagRepr(param.type.flag), src });
            try w.printLine("args[{d}] = @ptrCast(&arg{d}_slot);", .{ i, i });
        },
    }
}

fn writeTypeSelectedScalarArgSlot(w: *CodeWriter, i: usize, param: *const Context.Function.Parameter) !void {
    switch (param.type) {
        .float => try w.printLine(
            "const arg{0d}_slot: f64 = if (@TypeOf({1s}) == f64) {1s} else @floatCast({1s});",
            .{ i, param.name },
        ),
        .int => try w.printLine(
            "const arg{0d}_slot: i64 = if (@TypeOf({1s}) == i64) {1s} else @intCast({1s});",
            .{ i, param.name },
        ),
        else => unreachable,
    }
    try w.printLine("args[{0d}] = @ptrCast(&arg{0d}_slot);", .{i});
}

fn writeValue(w: *CodeWriter, value: Context.Value, ctx: *const Context) !void {
    switch (value) {
        .null => try w.writeAll("null"),
        .string => |s| try w.print("String.fromNullTerminatedUtf8(\"{f}\")", .{std.zig.fmtString(s)}),
        .string_name => |s| try w.print("StringName.fromNullTerminatedUtf8(\"{f}\")", .{std.zig.fmtString(s)}),
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
    switch (function.type_selected_scalar) {
        .none => {},
        .float => {
            try w.writeLine("return @as(T, @floatCast(result));");
            w.indent -= 1;
            try w.writeLine("}");
            return;
        },
        .int => {
            try w.writeLine("return @as(T, @intCast(result));");
            w.indent -= 1;
            try w.writeLine("}");
            return;
        },
    }

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
        } else switch (wideSlot(&function.return_type, ctx)) {
            // Narrow the int64 result slot back to the declared sub-8-byte return type.
            .none => try w.writeLine("return result;"),
            .int => try w.writeLine("return @intCast(result);"),
            .@"enum" => try w.writeLine("return @enumFromInt(result);"),
            .flag => try w.printLine("return @bitCast(@as({s}, @intCast(result)));", .{ctx.flagRepr(function.return_type.flag)}),
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
    const arena = ctx.arena.allocator();
    const filename = try std.fmt.allocPrint(arena, fmt, args);
    const file = ctx.config.input.openFile(ctx.config.io, filename, .{}) catch return;
    defer file.close(ctx.config.io);

    var buf: [1024]u8 = undefined;
    var file_reader = file.readerStreaming(ctx.config.io, &buf);
    const contents = try file_reader.interface.allocRemaining(arena, .unlimited);

    try w.writeAll(util.mixinContents(contents));
}

fn writeDispatchTable(ctx: *Context) !void {
    var buf: [1024]u8 = undefined;

    const file = try ctx.config.output.createFile(ctx.config.io, "DispatchTable.zig", .{});
    defer file.close(ctx.config.io);

    var file_writer = file.writerStreaming(ctx.config.io, &buf);
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
    try file.sync(ctx.config.io);
}

fn writeModules(ctx: *const Context) !void {
    var buf: [1024]u8 = undefined;

    for (ctx.modules.values()) |*module| {
        const filename = try std.fmt.allocPrint(ctx.rawAllocator(), "{s}.zig", .{module.name});
        defer ctx.rawAllocator().free(filename);

        const file = try ctx.config.output.createFile(ctx.config.io, filename, .{});
        defer file.close(ctx.config.io);

        var file_writer = file.writerStreaming(ctx.config.io, &buf);
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
    try writeFunctionOptions(w, function, null, ctx);
    try w.writeLine(
        \\/// Guarantees no allocations when calling across the FFI. Passing packed arrays is a compile error; use the Alloc variant.
        \\///
    );
    try writeDocBlock(w, function.doc);

    // Function signature
    if (std.zig.Token.keywords.has(function.name)) {
        try w.print("{s}fn @\"{s}\"(", .{ if (function.is_public) "pub " else "", function.name });
    } else {
        try w.print("{s}fn {s}(", .{ if (function.is_public) "pub " else "", function.name });
    }

    var is_first = true;
    const opt = firstOptionalParameter(function);
    for (function.parameters.values()[0..opt]) |param| {
        if (!is_first) try w.writeAll(", ");
        try w.print("{s}: ", .{param.name});
        try writeTypeAtParameter(w, &param.type, null, ctx);
        is_first = false;
    }

    if (!is_first) try w.writeAll(", ");
    try w.writeAll("@\"...\": anytype");
    if (opt < function.parameters.count()) {
        try w.writeAll(", opt: ");
        try writeOptionsName(w, function, ctx);
    }
    try w.writeAll(") ");
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
    for (function.parameters.values()[0..opt]) |param| {
        if (!is_first) try w.writeAll(", ");
        try w.print("{s}", .{param.name});
        is_first = false;
    }

    if (!is_first) try w.writeAll(", ");
    try w.writeAll("@\"...\"");
    if (opt < function.parameters.count()) try w.writeAll(", opt");
    try w.writeLine(");");

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

test "class bind primary then compatibility order, including Alloc and no metadata" {
    var out: std.Io.Writer.Allocating = .init(std.testing.allocator);
    defer out.deinit();
    var w: CodeWriter = .init(&out.writer);
    var function: Context.Function = .{ .name = "probe", .name_api = "probe", .base = "Object", .hash = 123 };
    try function.hash_compatibility.appendSlice(std.testing.allocator, &.{ 456, 789 });
    defer function.hash_compatibility.deinit(std.testing.allocator);
    for ([_][]const u8{ "", "Alloc" }) |suffix| {
        out.clearRetainingCapacity();
        try writeClassMethodBind(&w, &function, suffix);
        const text = out.written();
        const primary = std.mem.indexOf(u8, text, ", 123);").?;
        const fallback = std.mem.indexOf(u8, text, "inline for ([_]i64{ 456, 789 }").?;
        try std.testing.expect(primary < fallback);
        try std.testing.expectEqual(@as(usize, 0), w.indent);
        const guard = try std.fmt.allocPrint(std.testing.allocator, "if (probe{s}_ptr == null)", .{suffix});
        defer std.testing.allocator.free(guard);
        try std.testing.expectEqual(@as(usize, 2), std.mem.count(u8, text, guard));
    }
    function.hash_compatibility.clearRetainingCapacity();
    out.clearRetainingCapacity();
    try writeClassMethodBind(&w, &function, "");
    try std.testing.expect(std.mem.indexOf(u8, out.written(), "inline for") == null);
    try std.testing.expectEqualStrings(
        "if (probe_ptr == null) {\n    probe_ptr = raw.classdbGetMethodBind(@ptrCast(&StringName.fromComptimeLatin1(\"Object\")), @ptrCast(&StringName.fromComptimeLatin1(\"probe\")), 123);\n}\n",
        out.written(),
    );
}

test "named options use original API names and preserve runtime defaults" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const ctx: Context = .{ .arena = &arena, .api = undefined, .config = undefined };
    var function: Context.Function = .{ .name = "probeRaw", .name_api = "probe", .base = "Object", .hash = 123 };
    try function.parameters.put(arena.allocator(), "count", .{ .name = "count", .type = .{ .int = "i64" }, .default = .{ .primitive = "7" } });
    try function.parameters.put(arena.allocator(), "label", .{ .name = "label", .type = .string, .default = .{ .string = "default" } });
    var out: std.Io.Writer.Allocating = .init(std.testing.allocator);
    defer out.deinit();
    var w: CodeWriter = .init(&out.writer);
    try writeFunctionHeader(&w, &function, null, &ctx);
    const text = out.written();
    try std.testing.expect(std.mem.indexOf(u8, text, "pub const ProbeOptions = struct") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "opt: ProbeOptions") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "count: i64 = 7") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "label: ?String = null") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "actual_label = opt.label orelse") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "defer if (opt.label == null) actual_label.deinit();") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "ProbeRawOptions") == null);
}

test "private fixed and Alloc delegates share API options and singleton shape" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const ctx: Context = .{ .arena = &arena, .api = undefined, .config = undefined };
    const cls: Context.Class = .{ .name = "Probe" };
    var function: Context.Function = .{ .name = "probeRaw", .name_api = "probe", .base = "Object", .hash = 123, .is_public = false, .self = .singleton };
    try function.parameters.put(arena.allocator(), "count", .{ .name = "count", .type = .{ .int = "i64" }, .default = .{ .primitive = "7" } });
    var out: std.Io.Writer.Allocating = .init(std.testing.allocator);
    defer out.deinit();
    var w: CodeWriter = .init(&out.writer);
    try writeClassFunction(&w, &cls, &function, &ctx);
    try std.testing.expect(std.mem.indexOf(u8, out.written(), "fn probeRaw(opt: ProbeOptions)") != null);
    try std.testing.expect(std.mem.indexOf(u8, out.written(), "pub fn probeRaw") == null);
    out.clearRetainingCapacity();
    function.is_vararg = true;
    try writeClassFunctionVarargWrapper(&w, &cls, &function, &ctx);
    try writeFunctionAlloc(&w, &function, &cls, &ctx);
    const text = out.written();
    try std.testing.expectEqual(@as(usize, 1), std.mem.count(u8, text, "pub const ProbeOptions"));
    try std.testing.expectEqual(@as(usize, 2), std.mem.count(u8, text, "opt: ProbeOptions"));
    try std.testing.expect(std.mem.indexOf(u8, text, "probeRawAlloc(@\"...\", opt)") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "pub fn probeRaw") == null);
    try std.testing.expect(std.mem.indexOf(u8, text, "self:") == null);
    out.clearRetainingCapacity();
    try writeModuleFunctionVarargWrapper(&w, &function, &ctx);
    try writeFunctionAlloc(&w, &function, null, &ctx);
    try std.testing.expectEqual(@as(usize, 1), std.mem.count(u8, out.written(), "pub const ProbeOptions"));
    try std.testing.expectEqual(@as(usize, 2), std.mem.count(u8, out.written(), "opt: ProbeOptions"));
    try function.parameters.put(arena.allocator(), "value", .{ .name = "value", .type = .variant, .default = .null });
    out.clearRetainingCapacity();
    try writeFunctionAlloc(&w, &function, null, &ctx);
    try std.testing.expect(std.mem.indexOf(u8, out.written(), "actual_value: Variant = opt.value orelse .nil") != null);
    try std.testing.expect(std.mem.indexOf(u8, out.written(), "@constCast(&actual_value)") != null);
}

test "generated declaration names reject API and private mixin collisions" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    var cls: Context.Class = .{};
    try cls.functions.put(arena.allocator(), "other", .{ .name = "probeRaw" });
    try cls.mixin_names.put(arena.allocator(), "probeRawAlloc", {});
    try cls.mixin_names.put(arena.allocator(), "ProbeOptions", {});
    try std.testing.expectError(error.GeneratedDeclarationCollision, checkClassDeclarationName(&cls, "probeRaw"));
    try std.testing.expectError(error.GeneratedDeclarationCollision, checkClassDeclarationName(&cls, "probeRawAlloc"));
    try std.testing.expectError(error.GeneratedDeclarationCollision, checkClassDeclarationName(&cls, "ProbeOptions"));
    try checkClassDeclarationName(&cls, "unrelated");
}

test "legacy writer guards runtime ranges and omits declarations above a minimum" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    var ctx: Context = .{ .arena = &arena, .api = undefined, .config = undefined };
    const class: Context.Class = .{ .name = "Probe" };
    const function: Context.Function = .{
        .name = "probe_4_6_legacy",
        .name_api = "probe",
        .base = "Probe",
        .hash = 111,
        .legacy_range = .{
            .lower = common.Version.parse("4.6.0"),
            .upper = common.Version.parse("4.7.0"),
            .old_hash = 111,
            .layout = .return_added,
            .adapter = "probe_4_6",
            .available = false,
            .signature = fixtureSignature("void -> bool"),
        },
    };
    var out: std.Io.Writer.Allocating = .init(std.testing.allocator);
    defer out.deinit();
    var writer: CodeWriter = .init(&out.writer);
    try writeClassFunction(&writer, &class, &function, &ctx);
    try std.testing.expect(std.mem.indexOf(u8, out.written(), "gdzig.version.range") != null);
    try std.testing.expect(std.mem.indexOf(u8, out.written(), "probe_4_6_legacy_ptr") != null);
    try std.testing.expect(std.mem.indexOf(u8, out.written(), ", 111);") != null);
    out.clearRetainingCapacity();
    ctx.compatibility_minimum = common.Version.parse("4.6.0");
    try writeClassFunction(&writer, &class, &function, &ctx);
    try std.testing.expect(std.mem.indexOf(u8, out.written(), "gdzig.version") == null);
    out.clearRetainingCapacity();
    ctx.compatibility_minimum = common.Version.parse("4.7.0");
    try writeClassFunction(&writer, &class, &function, &ctx);
    try std.testing.expectEqual(@as(usize, 0), out.written().len);
}

test "dispatch preserves range order patch adapters and above-range omission" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    var ctx: Context = .{
        .arena = &arena,
        .api = undefined,
        .config = undefined,
    };
    const group: version_dispatch.Group = .{
        .lower = .@"4.6",
        .upper = .{ .major = 4, .minor = 6, .patch = 2 },
        .old_hash = 111,
        .layout = .incompatible,
        .adapter = "probe_4_6",
        .available = true,
        .signature = fixtureSignature("argument type"),
    };
    var later = group;
    later.lower = group.upper;
    later.upper = .@"4.7";
    later.adapter = "probe_4_6_2";
    const function: Context.Function = .{
        .name = "probe",
        .name_api = "probe",
        .base = "Probe",
        .dispatch_ranges = &.{ group, later },
    };
    var output: std.Io.Writer.Allocating = .init(std.testing.allocator);
    defer output.deinit();
    var writer: CodeWriter = .init(&output.writer);
    try writeVersionDispatch(&writer, &function, &ctx);
    const first = std.mem.indexOf(u8, output.written(), "return probe_4_6();").?;
    const second = std.mem.indexOf(u8, output.written(), "return probe_4_6_2();").?;
    try std.testing.expect(first < second);

    ctx.compatibility_minimum = .@"4.7";
    var above: std.Io.Writer.Allocating = .init(std.testing.allocator);
    defer above.deinit();
    var above_writer: CodeWriter = .init(&above.writer);
    try writeVersionDispatch(&above_writer, &function, &ctx);
    try std.testing.expectEqual(@as(usize, 0), above.written().len);
}

test "unshimmed dispatch emits runtime panic or inside-minimum compile error" {
    const cases = [_]struct {
        minimum: ?common.Version,
        required: []const u8,
        excluded: []const u8,
    }{
        .{
            .minimum = null,
            .required = "@panic",
            .excluded = "@compileError",
        },
        .{
            .minimum = .@"4.6",
            .required = "@compileError",
            .excluded = "@panic",
        },
    };
    for (cases) |case| {
        var output: std.Io.Writer.Allocating = .init(std.testing.allocator);
        defer output.deinit();
        try writeDispatchFixture(&output.writer, std.testing.allocator, case.minimum, true, 6, false);
        try std.testing.expect(std.mem.indexOf(u8, output.written(), case.required) != null);
        try std.testing.expect(std.mem.indexOf(u8, output.written(), case.excluded) == null);
        try std.testing.expect(std.mem.indexOf(u8, output.written(), "add probe_4_6") != null);
        try std.testing.expect(std.mem.indexOf(u8, output.written(), "refAllDecls(@This())") != null);
    }
}

test "selected minimum emits one fixed and Alloc class bind" {
    var function: Context.Function = .{
        .name = "probe",
        .name_api = "probe",
        .base = "Node",
        .hash = 123,
        .selected_hash = 456,
    };
    try function.hash_compatibility.append(std.testing.allocator, 789);
    defer function.hash_compatibility.deinit(std.testing.allocator);
    for ([_][]const u8{ "", "Alloc" }) |suffix| {
        var output: std.Io.Writer.Allocating = .init(std.testing.allocator);
        defer output.deinit();
        var writer: CodeWriter = .init(&output.writer);
        try writeClassMethodBind(&writer, &function, suffix);
        const text = output.written();
        try std.testing.expectEqual(@as(usize, 1), std.mem.count(u8, text, "classdbGetMethodBind"));
        try std.testing.expect(std.mem.indexOf(u8, text, ", 456);") != null);
        try std.testing.expect(std.mem.indexOf(u8, text, "inline for") == null);
    }
}

fn fixtureSignature(difference: []const u8) @import("compat").manifest.Legacy {
    return .fromRecord(.{
        .kind = .class,
        .owner = "Probe",
        .method = "probe",
        .hash = 111,
        .compatibility = &.{},
        .virtual = false,
        .is_const = false,
        .is_static = false,
        .is_vararg = false,
        .arguments = &.{},
        .@"return" = null,
    }, difference);
}

const std = @import("std");

const casez = @import("casez");
const common = @import("common");

const CodeWriter = @import("CodeWriter.zig");
const Context = @import("Context.zig");
const util = @import("util.zig");
const version_dispatch = @import("version_dispatch.zig");
