pub fn generate(ctx: *Context) !void {
    try generateBuiltins(ctx);
    try generateClasses(ctx);
    try generateGlobalEnums(ctx);
    try generateModules(ctx);
    try generateUtilityFunctions(ctx);

    try generateCore(ctx);
}

fn generateBuiltins(ctx: *Context) !void {
    for (ctx.api.builtin_classes) |builtin| {
        if (util.shouldSkipClass(builtin.name)) {
            continue;
        }

        const filename = try std.fmt.allocPrint(ctx.allocator, "{s}.zig", .{builtin.name});
        defer ctx.allocator.free(filename);

        const file = try ctx.config.output.createFile(filename, .{});
        defer file.close();

        var buf = bufferedWriter(file.writer());
        var writer = codeWriter(buf.writer().any());

        try generateBuiltin(&writer, builtin, ctx);

        try buf.flush();
        try file.sync();
    }
}

fn generateBuiltin(w: *Writer, builtin: GodotApi.Builtin, ctx: *Context) !void {
    try generateDocBlock(w, builtin.description);

    // TODO: remove this
    var generated_method_map: StringHashMap(void) = .empty;

    try w.printLine("pub const {s} = extern struct {{", .{builtin.name});
    w.indent += 1;
    try w.writeLine("pub const Self = @This();");
    // TODO: refactor to generate actual members (instead of setters/getters and whatever this is)
    const size = ctx.class_sizes.get(builtin.name) orelse std.debug.panic("Could not get class size for {x}", .{builtin.name});
    try w.printLine("value: [{d}]u8,", .{size});
    // try generateBuiltinConstants(w, builtin, ctx);
    try generateBuiltinConstructors(w, builtin, ctx);
    try generateBuiltinMethods(w, builtin, &generated_method_map, ctx);
    try generateBuiltinMembers(w, builtin, &generated_method_map, ctx);
    try generateBuiltinEnums(w, builtin);
    w.indent -= 1;
    try w.printLine("}};", .{});

    if (ctx.builtin_imports.get(builtin.name)) |imports| {
        try generateImports(w, &imports);
    }
}

fn generateBuiltinEnums(w: *Writer, builtin: GodotApi.Builtin) !void {
    const enums = builtin.enums orelse return;

    for (enums) |@"enum"| {
        try generateBuiltinEnum(w, @"enum");
    }
}

fn generateBuiltinEnum(w: *Writer, @"enum": GodotApi.Builtin.Enum) !void {
    try w.printLine("pub const {s} = c_int;", .{@"enum".name});
    for (@"enum".values) |value| {
        try w.printLine("pub const {s}: c_int = {d};", .{ value.name, value.value });
    }
}

fn generateBuiltinConstants(w: *Writer, builtin: GodotApi.Builtin, ctx: *const Context) !void {
    const constants = builtin.constants orelse return;

    for (constants) |constant| {
        try generateBuiltinConstant(w, constant, ctx);
    }
}

fn generateBuiltinConstant(w: *Writer, constant: GodotApi.Builtin.Constant, ctx: *const Context) !void {
    try w.printLine("pub const {s}: {s} = {s};", .{ constant.name, ctx.correctType(constant.type, ""), constant.value });
}

fn generateBuiltinConstructors(w: *Writer, builtin: GodotApi.Builtin, ctx: *Context) !void {
    const name = ctx.correctName(builtin.name);

    if (std.mem.eql(u8, name, "String")) {
        try w.writeLine(
            \\pub fn initFromLatin1Chars(chars:[]const u8) Self{
            \\    var self: Self = undefined;
            \\    godot.core.stringNewWithLatin1CharsAndLen(@ptrCast(&self.value), chars.ptr, @intCast(chars.len));
            \\    return self;
            \\}
            \\pub fn initFromUtf8Chars(chars:[]const u8) Self{
            \\    var self: Self = undefined;
            \\    godot.core.stringNewWithUtf8CharsAndLen(@ptrCast(&self.value), chars.ptr, @intCast(chars.len));
            \\    return self;
            \\}
            \\pub fn initFromUtf16Chars(chars:[]const godot.char16_t) Self{
            \\    var self: Self = undefined;
            \\    godot.core.stringNewWithUtf16CharsAndLen(@ptrCast(&self.value), chars.ptr, @intCast(chars.len));
            \\    return self;
            \\}
            \\pub fn initFromUtf32Chars(chars:[]const godot.char32_t) Self{
            \\    var self: Self = undefined;
            \\    godot.core.stringNewWithUtf32CharsAndLen(@ptrCast(&self.value), chars.ptr, @intCast(chars.len));
            \\    return self;
            \\}
            \\pub fn initFromWideChars(chars:[]const godot.wchar_t) Self{
            \\    var self: Self = undefined;
            \\    godot.core.stringNewWithWideCharsAndLen(@ptrCast(&self.value), chars.ptr, @intCast(chars.len));
            \\    return self;
            \\}
        );
    }
    if (std.mem.eql(u8, name, "StringName")) {
        try w.writeLine(
            \\pub fn initStaticFromLatin1Chars(chars:[:0]const u8) Self {
            \\    var self: Self = undefined;
            \\    godot.core.stringNameNewWithLatin1Chars(@ptrCast(&self.value), chars.ptr, 1);
            \\    return self;
            \\}
            \\pub fn initFromLatin1Chars(chars:[:0]const u8) Self {
            \\    var self: Self = undefined;
            \\    godot.core.stringNameNewWithLatin1Chars(@ptrCast(&self.value), chars.ptr, 0);
            \\    return self;
            \\}
            \\pub fn initFromUtf8Chars(chars:[]const u8) Self {
            \\    var self: Self = undefined;
            \\    godot.core.stringNameNewWithUtf8CharsAndLen(@ptrCast(&self.value), chars.ptr, @intCast(chars.len));
            \\    return self;
            \\}
        );
    }

    for (builtin.constructors) |constructor| {
        // TODO: remove generateProc and replace with generateBuiltinConstructor
        try generateProc(w, constructor, name, "init", "Self", .Constructor, ctx);
    }

    if (builtin.has_destructor) {
        // TODO: remove generateProc and replace with generateBuiltinDestructor
        try generateProc(w, null, name, "deinit", "void", .Destructor, ctx);
    }
}

fn generateBuiltinMethods(w: *Writer, builtin: GodotApi.Builtin, generated_method_map: *StringHashMap(void), ctx: *Context) !void {
    const class_name = ctx.correctName(builtin.name);
    const is_builtin_class = true;
    const proc_type = ProcType.BuiltinMethod;

    const methods = builtin.methods orelse return;

    for (methods) |method| {
        const func_name = method.name;
        const zig_func_name = ctx.getZigFuncName(func_name);

        const return_type =
            if (is_builtin_class)
                ctx.correctType(method.return_type, "")
            else if (method.return_value) |ret|
                ctx.correctType(ret.type, ret.meta)
            else
                "void";

        if (!generated_method_map.contains(zig_func_name)) {
            try generated_method_map.putNoClobber(ctx.allocator, zig_func_name, {});
            try generateProc(w, method, class_name, func_name, return_type, proc_type, ctx);
        }
    }
}

fn generateBuiltinMembers(w: *Writer, builtin: GodotApi.Builtin, generated_method_map: *StringHashMap(void), ctx: *Context) !void {
    const name = ctx.correctName(builtin.name);
    const enum_type_name = ctx.getVariantTypeName(name);
    const members = builtin.members orelse return;

    for (members) |member| {
        try generateBuiltinMember(w, member, enum_type_name, generated_method_map, ctx);
    }
}

fn generateBuiltinMember(w: *Writer, member: GodotApi.Builtin.Member, enum_type_name: []const u8, generated_method_map: *StringHashMap(void), ctx: *Context) !void {
    const member_type = ctx.correctType(member.type, "");

    const temp_getter_name = try std.fmt.allocPrint(ctx.allocator, "get_{s}", .{member.name});
    const getter_name = ctx.getZigFuncName(temp_getter_name);

    if (!generated_method_map.contains(getter_name)) {
        try generated_method_map.putNoClobber(ctx.allocator, getter_name, {});
        try w.printLine(
            \\pub fn {s}(self: Self) {s} {{
            \\    var result: {s} = undefined;
            \\    const Binding = struct {{ pub var method: godot.c.GDExtensionPtrGetter = null; }};
            \\    if (Binding.method == null) {{
            \\        const func_name = godot.core.StringName.initFromLatin1Chars("{s}");
            \\        Binding.method = godot.core.variantGetPtrGetter({s}, @ptrCast(&func_name));
            \\    }}
            \\    Binding.method.?(@ptrCast(&self.value), @ptrCast(&result));
            \\    return result;
            \\}}
        , .{ getter_name, member_type, member_type, member.name, enum_type_name });
    }

    const temp_setter_name = try std.fmt.allocPrint(ctx.allocator, "set_{s}", .{member.name});
    const setter_name = ctx.getZigFuncName(temp_setter_name);

    if (!generated_method_map.contains(setter_name)) {
        try generated_method_map.putNoClobber(ctx.allocator, setter_name, {});

        try w.printLine(
            \\pub fn {s}(self: *Self, v: {s}) void {{
            \\    const Binding = struct{{ pub var method:godot.c.GDExtensionPtrSetter = null; }};
            \\    if( Binding.method == null ) {{
            \\        const func_name = godot.core.StringName.initFromLatin1Chars("{s}");
            \\        Binding.method = godot.core.variantGetPtrSetter({s}, @ptrCast(&func_name));
            \\    }}
            \\    Binding.method.?(@ptrCast(&self.value), @ptrCast(&v));
            \\}}
        , .{ setter_name, member_type, member.name, enum_type_name });
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
        try file.sync();
    }
}

fn generateClass(w: *Writer, class: GodotApi.Class, ctx: *Context) !void {
    try generateDocBlock(w, class.description);

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
        try generateImports(w, &imports);
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
            try w.printLine("/// {s} class method: {s}", .{ parent.name, method.name });
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
            \\if (@as(*StringName, @ptrCast(@constCast(p_name))).{1s}("{0s}") == 0 and @hasDecl(T, "{0s}")) {{
            \\    const MethodBinder = struct {{
            \\        pub fn {0s}(p_instance: godot.c.GDExtensionClassInstancePtr, p_args: [*c]const godot.c.GDExtensionConstTypePtr, p_ret: godot.c.GDExtensionTypePtr) callconv(.C) void {{
            \\            const MethodBinder = godot.MethodBinderT(@TypeOf(T.{0s}));
            \\            MethodBinder.bindPtrcall(@ptrCast(@constCast(&T.{0s})), p_instance, p_args, p_ret);
            \\        }}
            \\    }};
            \\    return MethodBinder.{0s};
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

fn generateGlobalEnums(ctx: *Context) !void {
    const file = try ctx.config.output.createFile("global.zig", .{});
    defer file.close();

    var buf = bufferedWriter(file.writer());
    var writer = codeWriter(buf.writer().any());

    for (ctx.enums.values()) |@"enum"| {
        // TODO: shouldSkip functions
        if (std.mem.startsWith(u8, @"enum".name, "Variant.")) continue;
        try generateGlobalEnum(&writer, @"enum");
    }

    for (ctx.flags.values()) |flag| {
        // TODO: shouldSkip functions
        if (std.mem.startsWith(u8, flag.name, "Variant.")) continue;
        try generateGlobalFlag(&writer, flag);
    }

    try buf.flush();
    try file.sync();
}

fn generateGlobalEnum(w: *Writer, @"enum": Context.Enum) !void {
    try w.printLine("pub const {s} = enum(i32) {{", .{@"enum".name});
    w.indent += 1;
    for (@"enum".values) |value| {
        try generateDocBlock(w, value.doc);
        try w.printLine("{s} = {d},", .{ value.name, value.value });
    }
    w.indent -= 1;
    try w.writeLine("};");
}

fn generateGlobalFlag(w: *Writer, flag: Context.Flag) !void {
    try w.printLine("pub const {s} = packed struct(i32) {{", .{flag.name});
    w.indent += 1;
    for (flag.fields) |field| {
        try generateDocBlock(w, field.doc);
        try w.printLine("{s}: bool = {s},", .{ field.name, if (field.default) "true" else "false" });
    }
    if (flag.padding > 0) {
        try w.printLine("_: u{d} = 0,", .{flag.padding});
    }
    for (flag.consts) |@"const"| {
        try generateDocBlock(w, @"const".doc);
        try w.printLine("pub const {s}: {s} = @bitCast(@as(u32, {d}));", .{ @"const".name, flag.name, @"const".value });
    }
    w.indent -= 1;
    try w.writeLine("};");
}

fn generateDocBlock(w: *Writer, docs: ?[]const u8) !void {
    if (docs) |d| {
        w.comment = .doc;
        try w.writeLine(d);
        w.comment = .off;
    }
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
        try generateDocBlock(w, fn_node.description);
    }

    if (proc_type == .Constructor) {
        var buf: [256]u8 = undefined;
        const atypes = ctx.getArgumentsTypes(fn_node, &buf);
        if (atypes.len > 0) {
            const temp_atypes_func_name = try std.fmt.allocPrint(ctx.allocator, "{s}_from_{s}", .{ func_name, atypes });
            const atypes_func_name = ctx.getZigFuncName(temp_atypes_func_name);

            try w.print("pub fn {s}(", .{atypes_func_name});
        } else {
            try w.print("pub fn {s}(", .{zig_func_name});
        }
    } else {
        try w.print("pub fn {s}(", .{zig_func_name});
    }

    const is_const = (proc_type == .BuiltinMethod or proc_type == .ClassMethod) and fn_node.is_const;
    const is_static = (proc_type == .BuiltinMethod or proc_type == .ClassMethod) and fn_node.is_static;
    const is_vararg = proc_type != .Constructor and proc_type != .Destructor and fn_node.is_vararg;

    var args = std.ArrayList([]const u8).init(ctx.allocator);
    defer args.deinit();
    var arg_types = std.ArrayList([]const u8).init(ctx.allocator);
    defer arg_types.deinit();
    const need_return = !std.mem.eql(u8, return_type, "void");
    var is_first_arg = true;
    if (!is_static) {
        if (proc_type == .BuiltinMethod or proc_type == .Destructor) {
            if (is_const) {
                _ = try w.write("self: Self");
            } else {
                _ = try w.write("self: *Self");
            }

            is_first_arg = false;
        } else if (proc_type == .ClassMethod) {
            _ = try w.write("self: anytype");
            is_first_arg = false;
        }
    }
    const arg_name_postfix = "_"; //to avoid shadowing member function, which is not allowed in Zig

    if (proc_type != .Destructor) {
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
                    if ((proc_type != .Constructor or !util.isStringType(class_name)) and (util.isStringType(arg_type))) {
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
                try w.printLine("args[{d}] = &godot.Variant.init(godot.core.String.initFromLatin1Chars({s}));", .{ i, args.items[i] });
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
                if ((proc_type != .Constructor or !util.isStringType(class_name)) and (util.isStringType(arg_type))) {
                    try w.printLine("if(@TypeOf({2s}) == {1s}) {{ args[{0d}] = @ptrCast(&{2s}); }} else {{ args[{0d}] = @ptrCast(&{1s}.initFromLatin1Chars({2s})); }}", .{ i, arg_type, arg });
                } else {
                    try w.printLine("args[{d}] = @ptrCast(&{s});", .{ i, arg });
                }
            }
        }
        arg_array = "@ptrCast(&args)";
        arg_count = "args.len";
    }

    const enum_type_name = ctx.getVariantTypeName(class_name);
    const result_string = if (need_return) "@ptrCast(&result)" else "null";

    switch (proc_type) {
        .UtilityFunction => {
            try w.printLine(
                \\const method = godot.support.bindFunction("{s}", {d});
                \\method({s}, {s}, {s});
            , .{
                func_name,
                fn_node.hash,
                result_string,
                arg_array,
                arg_count,
            });
        },
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
        .BuiltinMethod => {
            try w.printLine("const method = godot.support.bindBuiltinMethod({s}, \"{s}\", {d});", .{ enum_type_name, func_name, fn_node.hash });
            if (is_static) {
                try w.printLine("method(null, {s}, {s}, {s});", .{ arg_array, result_string, arg_count });
            } else {
                try w.printLine("method(@ptrCast(@constCast(&self.value)), {s}, {s}, {s});", .{ arg_array, result_string, arg_count });
            }
        },
        .Constructor => {
            try w.printLine(
                \\const method = godot.support.bindConstructor({s}, {d});
                \\method(@ptrCast(&result), {s});
            , .{ enum_type_name, fn_node.index, arg_array });
        },
        .Destructor => {
            try w.printLine(
                \\const method = godot.support.bindDestructor({s});
                \\method(@ptrCast(&self.value));
            , .{enum_type_name});
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
        \\pub const util = @import("util.zig");
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
            try w.printLine("godot.getClassName({0s}).* = godot.core.StringName.initFromLatin1Chars(\"{0s}\");", .{cls});
        }

        w.indent -= 1;
        try w.writeLine("}");
    }

    { // TODO: Separate function generateCoreDeinit
        try w.writeLine("pub fn deinitCore() void {");
        w.indent += 1;
        for (ctx.all_engine_classes.items) |cls| {
            try w.printLine("godot.getClassName({0s}).deinit();", .{cls});
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
    try file.sync();
}

fn generateImports(w: *Writer, imports: *const Context.Imports) !void {
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

fn generateUtilityFunctions(ctx: *Context) !void {
    const file = try ctx.config.output.createFile("util.zig", .{});
    defer file.close();

    var buf = bufferedWriter(file.writer());
    var writer = codeWriter(buf.writer().any());

    // TODO: should be managed at a module level in Context and we should generate modules
    var imports: Context.Imports = .empty;
    defer imports.deinit(ctx.allocator);

    for (ctx.api.utility_functions) |function| {
        const return_type = ctx.correctType(function.return_type, "");
        try generateProc(&writer, function, "", function.name, return_type, .UtilityFunction, ctx);

        if (ctx.function_imports.get(function.name)) |function_imports| {
            try imports.merge(ctx.allocator, &function_imports);
        }
    }

    try generateImports(&writer, &imports);

    try buf.flush();
    try file.sync();
}

fn generateModules(ctx: *Context) !void {
    for (ctx.modules.values()) |*module| {
        const filename = try std.fmt.allocPrint(ctx.allocator, "{s}.zig", .{module.name});
        defer ctx.allocator.free(filename);

        const file = try ctx.config.output.createFile(filename, .{});
        defer file.close();

        var buf = bufferedWriter(file.writer());
        var writer = codeWriter(buf.writer().any());

        try generateModule(&writer, module);

        try buf.flush();
        try file.sync();
    }
}

fn generateModule(w: *Writer, module: *const Context.Module) !void {
    for (module.functions) |*function| {
        try generateModuleFunction(w, function);
    }
    try generateImports(w, &module.imports);
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
fn generateModuleFunction(w: *Writer, function: *const Context.Function) !void {
    try generateFunctionHeader(w, function);

    try w.printLine(
        \\const function = godot.support.bindFunction("{s}", {d});
        \\function({s}, @ptrCast(&args), args.len);
    , .{
        function.name,
        function.hash,
        if (function.return_type != null) "@ptrCast(&out)" else "null",
    });

    try generateFunctionFooter(w, function);
}

fn generateFunctionHeader(w: *Writer, function: *const Context.Function) !void {
    try generateDocBlock(w, function.doc);

    // Declaration
    try w.print("pub fn {s}(", .{function.name});

    var is_first = true;

    // Self
    if (!function.is_static) {
        try w.writeAll("self: *");
        if (function.is_const) {
            try w.writeAll("const ");
        }
        try w.writeAll("@This()");
        is_first = false;
    }

    // Standard parameters
    var opt: usize = function.parameters.len;
    for (function.parameters, 0..) |param, i| {
        if (param.default != null) {
            opt = i;
            break;
        }
        if (!is_first) {
            try w.writeAll(", ");
        }
        try w.print("{s}: ", .{param.name});
        try generateFunctionParameterType(w, param.type);
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
    if (opt < function.parameters.len) {
        if (!is_first) {
            try w.writeAll(", ");
        }
        try w.writeAll("opt: struct {");
        is_first = true;
        for (function.parameters[opt..]) |param| {
            if (!is_first) {
                try w.writeAll(", ");
            }
            try w.print("{s}: ", .{param.name});
            try generateFunctionParameterType(w, param.type);
            try w.print(" = {s}", .{param.default.?});
            is_first = false;
        }
        try w.writeAll(" }");
        is_first = false;
    }

    // Return type
    try w.printLine(") {s} {{", .{function.return_type orelse "void"});
    w.indent += 1;

    // Parameter comptime type checking
    for (function.parameters) |_| {
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
        try w.printLine("var args: [{d}]godot.c.GDExtensionConstTypePtr = undefined;", .{function.parameters.len});
        for (function.parameters[0..opt], 0..) |param, i| {
            try w.printLine("args[{d}] = @ptrCast(&{s});", .{ i, param.name });
        }
        for (function.parameters[opt..], opt..) |param, i| {
            try w.printLine("args[{d}] @ptrCast(&opt.{s});", .{ i, param.name });
        }
    }

    // Variadic argument slice variable
    if (function.is_vararg) {
        try w.printLine("var args: [@\"...\".len + {d}]godot.c.GDExtensionConstTypePtr = undefined;", .{function.parameters.len});
        for (function.parameters[0..opt], 0..) |param, i| {
            try w.printLine("args[{d}] = &godot.Variant.init(&{s});", .{ i, param.name });
        }
        for (function.parameters[opt..], opt..) |param, i| {
            try w.printLine("args[{d}] = &godot.Variant.init(&opt.{s});", .{ i, param.name });
        }
        try w.printLine(
            \\inline for (0..@"...".len) |i| {{
            \\  args[{d} + i] = &godot.Variant.init(@field(@"...", i));
            \\}}
        , .{function.parameters.len});
    }

    // Return variable
    if (function.return_type) |return_type| {
        try w.printLine("var out: {s} = undefined;", .{
            if (function.is_vararg) "godot.Variant" else return_type,
        });
    }
}

fn generateFunctionFooter(w: *Writer, function: *const Context.Function) !void {
    // Return the value
    if (function.return_type) |return_type| {
        // Fixed arity functions
        if (function.is_vararg) {
            try w.writeLine(
                \\return out;
            );
        }
        // Variadic functions
        if (!function.is_vararg) {
            try w.printLine(
                \\return out.as({s});
            , .{return_type});
        }
    }

    // Return for variable argument funtions
    if (function.is_vararg and function.return_type != null) {
        // @panic("todo");
    }

    // End function
    w.indent -= 1;
    try w.writeLine("}");
}

/// Writes out a Type for a function parameter. Used to provide `anytype` where we do comptime type
/// checks and coercions.
fn generateFunctionParameterType(w: *Writer, @"type": Context.Type) !void {
    switch (@"type") {
        .basic => |name| try w.writeAll(name),
        else => try w.writeAll("anytype"),
    }
}

/// Writes out code necessary to both assert that arguments are the right type, and coerce them
/// into the form necessary to pass to the Godot function.
fn generateFunctionParameterTypeCheck(w: *Writer, parameter: Context.Function.Parameter) !void {
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

pub const ProcType = enum {
    UtilityFunction,
    BuiltinMethod,
    ClassMethod,
    Constructor,
    Destructor,
};

const std = @import("std");
const Allocator = std.mem.Allocator;
const bufferedWriter = std.io.bufferedWriter;
const StringHashMap = std.StringHashMapUnmanaged;
const fs = std.fs;

const case = @import("case");
const gdextension = @import("gdextension");

const Config = @import("Config.zig");
const Context = @import("Context.zig");
const GodotApi = @import("GodotApi.zig");
const Writer = @import("writer.zig").AnyWriter;
const codeWriter = @import("writer.zig").codeWriter;
const packed_array = @import("packed_array.zig");
const util = @import("util.zig");
