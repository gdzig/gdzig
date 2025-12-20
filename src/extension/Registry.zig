const Registry = @This();

allocator: Allocator,
arena: ArenaAllocator,
classes: std.ArrayListUnmanaged(*AnyClass),
callbacks: std.ArrayListUnmanaged(*AnyCallbacks),

pub fn init(backing_allocator: Allocator) Registry {
    return .{
        .allocator = backing_allocator,
        .arena = .init(backing_allocator),
        .classes = .{},
        .callbacks = .{},
    };
}

pub fn deinit(self: *Registry) void {
    self.arena.deinit();
    self.* = undefined;
}

/// The value type that the user passes to addClass.
/// If ClassUserdataOf(T) is a pointer, this is the child type.
/// Otherwise it's the same as ClassUserdataOf(T).
fn ClassUserdataValue(comptime T: type) type {
    const Userdata = class_mod.ClassUserdataOf(T);
    return switch (@typeInfo(Userdata)) {
        .pointer => |p| p.child,
        else => Userdata,
    };
}

/// Add a class without needing configuration.
pub fn addClass(self: *Registry, comptime T: type, userdata: ClassUserdataValue(T), options: Class(T).CreateOptions) void {
    _ = self.createClass(T, userdata, options);
}

/// Create a class and return it for further configuration.
pub fn createClass(self: *Registry, comptime T: type, userdata: ClassUserdataValue(T), options: Class(T).CreateOptions) *Class(T) {
    const alloc = self.arena.allocator();
    const Userdata = class_mod.ClassUserdataOf(T);

    // Store userdata in arena and get stable pointer if needed
    const stored_userdata: Userdata = switch (@typeInfo(Userdata)) {
        .pointer => blk: {
            const stored = alloc.create(ClassUserdataValue(T)) catch @panic("OOM");
            stored.* = userdata;
            break :blk stored;
        },
        else => userdata,
    };

    const class_builder = alloc.create(Class(T)) catch @panic("OOM");
    class_builder.* = Class(T).init(self, stored_userdata, options);
    self.classes.append(alloc, class_builder.erased()) catch @panic("OOM");
    return class_builder;
}

/// Add a module. The module must have a `pub fn register(r: *Registry) void` function.
pub fn addModule(self: *Registry, comptime Module: type) void {
    Module.register(self);
}

/// Add lifecycle callbacks.
pub fn addCallbacks(self: *Registry, comptime T: type, userdata: T, options: Callbacks(T).CreateOptions) void {
    const alloc = self.arena.allocator();

    // Store userdata in arena
    const userdata_ptr = alloc.create(T) catch @panic("OOM");
    userdata_ptr.* = userdata;

    const callbacks_obj = alloc.create(Callbacks(T)) catch @panic("OOM");
    callbacks_obj.* = Callbacks(T).init(userdata_ptr, options);
    self.callbacks.append(alloc, callbacks_obj.erased()) catch @panic("OOM");
}

pub fn enter(self: *Registry, level: InitializationLevel) void {
    // Commit registrations for this level
    for (self.classes.items) |any| {
        any.commit(any, level);
    }

    // Call enter callbacks
    for (self.callbacks.items) |any| {
        if (any.enter_fn) |enter_fn| {
            enter_fn(any, level);
        }
    }
}

pub fn exit(self: *Registry, level: InitializationLevel) void {
    for (self.callbacks.items) |any| {
        if (any.exit_fn) |exit_fn| {
            exit_fn(any, level);
        }
    }
}

/// Type-erased class handle for heterogeneous storage.
const AnyClass = struct {
    commit: *const fn (*AnyClass, InitializationLevel) void,
};

pub fn Class(comptime T: type) type {
    return struct {
        const Self = @This();

        pub const CreateOptions = struct {
            /// Initialization level for this class.
            level: InitializationLevel = .scene,
            /// Class cannot be instantiated directly.
            is_virtual: bool = false,
            /// Class is abstract.
            is_abstract: bool = false,
            /// Class is visible in editor and accessible from scripts.
            is_exposed: bool = true,
            /// Class is created at runtime (not saved to disk). Requires Godot 4.3+.
            is_runtime: bool = false,
            /// Custom icon path for the editor. Requires Godot 4.4+.
            icon_path: ?*const String = null,

            pub const auto: CreateOptions = .{};
        };

        any: AnyClass,
        registry: *Registry,
        userdata: class_mod.ClassUserdataOf(T),

        methods: std.ArrayListUnmanaged(*Method(T)),
        signals: std.ArrayListUnmanaged(*AnySignal),
        groups: std.ArrayListUnmanaged(*Group(T)),
        ungrouped_properties: std.ArrayListUnmanaged(*AnyProperty),
        constants: std.ArrayListUnmanaged(Constant),

        /// Initialization level for this class. Default is `.scene`.
        level: InitializationLevel,
        /// Class cannot be instantiated directly.
        is_virtual: bool,
        /// Class is abstract.
        is_abstract: bool,
        /// Class is visible in editor and accessible from scripts.
        is_exposed: bool,
        /// Class is created at runtime (not saved to disk). Requires Godot 4.3+.
        is_runtime: bool,
        /// Custom icon path for the editor. Requires Godot 4.4+.
        icon_path: ?*const String,

        pub fn init(registry: *Registry, userdata: class_mod.ClassUserdataOf(T), options: CreateOptions) Self {
            return .{
                .any = .{
                    .commit = @ptrCast(&commit),
                },
                .registry = registry,
                .userdata = userdata,
                .methods = .{},
                .signals = .{},
                .groups = .{},
                .ungrouped_properties = .{},
                .constants = .{},
                .level = options.level,
                .is_virtual = options.is_virtual,
                .is_abstract = options.is_abstract,
                .is_exposed = options.is_exposed,
                .is_runtime = options.is_runtime,
                .icon_path = options.icon_path,
            };
        }

        fn allocator(self: *Self) Allocator {
            return self.registry.arena.allocator();
        }

        pub fn erased(self: *Self) *AnyClass {
            return &self.any;
        }

        /// Add a method by name. Auto-detects the Zig decl from snake_case name.
        pub fn addMethod(self: *Self, comptime name: [:0]const u8, comptime options: Method(T).CreateOptions) void {
            _ = self.createMethod(name, options);
        }

        /// Create a method by name and return it for further configuration.
        /// Auto-detects the Zig decl from snake_case name.
        pub fn createMethod(self: *Self, comptime name: [:0]const u8, comptime options: Method(T).CreateOptions) *Method(T) {
            const alloc = self.allocator();
            const method = alloc.create(Method(T)) catch @panic("OOM");
            method.* = Method(T).fromName(name, options);
            self.methods.append(alloc, method) catch @panic("OOM");
            return method;
        }

        /// Add a property by name.
        /// Auto-detects getter/setter methods or field, unless overridden.
        pub fn addProperty(self: *Self, comptime name: [:0]const u8, options: Property(T, name).CreateOptions) void {
            _ = self.createProperty(name, options);
        }

        /// Create a property by name and return it for further configuration.
        /// Auto-detects getter/setter methods or field, unless overridden.
        pub fn createProperty(self: *Self, comptime name: [:0]const u8, options: Property(T, name).CreateOptions) *Property(T, name) {
            const alloc = self.allocator();
            const property = alloc.create(Property(T, name)) catch @panic("OOM");
            property.* = Property(T, name).init(self, options);
            self.ungrouped_properties.append(alloc, property.erased()) catch @panic("OOM");
            return property;
        }

        /// Add a signal.
        pub fn addSignal(self: *Self, comptime S: type) void {
            _ = self.createSignal(S);
        }

        /// Create a signal and return it for further configuration.
        pub fn createSignal(self: *Self, comptime S: type) *Signal(T, S) {
            const alloc = self.allocator();
            const signal = alloc.create(Signal(T, S)) catch @panic("OOM");
            signal.* = Signal(T, S).init();
            self.signals.append(alloc, signal.erased()) catch @panic("OOM");
            return signal;
        }

        /// Create a property group. Use the returned Group to add properties to it.
        pub fn createGroup(self: *Self, name: [:0]const u8) *Group(T) {
            const alloc = self.allocator();
            const grp = alloc.create(Group(T)) catch @panic("OOM");
            grp.* = Group(T).init(self, name);
            self.groups.append(alloc, grp) catch @panic("OOM");
            return grp;
        }

        /// Register an enum type. Must be `enum(i32)`.
        pub fn addEnum(self: *Self, comptime E: type) void {
            const info = @typeInfo(E);
            if (info != .@"enum") {
                @compileError("addEnum requires an enum type, got " ++ @typeName(E));
            }
            if (info.@"enum".tag_type != i32) {
                @compileError("addEnum requires enum(i32), got " ++ @typeName(E));
            }

            const alloc = self.allocator();
            const enum_name = @typeName(E);
            // Get just the type name without module path
            const short_name = blk: {
                var i = enum_name.len;
                while (i > 0) : (i -= 1) {
                    if (enum_name[i - 1] == '.') break :blk enum_name[i..];
                }
                break :blk enum_name;
            };

            inline for (info.@"enum".fields) |field| {
                self.constants.append(alloc, .{
                    .enum_name = short_name,
                    .name = field.name,
                    .value = field.value,
                    .is_bitfield = false,
                }) catch @panic("OOM");
            }
        }

        /// Register a flags type. Must be `packed struct(u32)` with bool fields.
        pub fn addFlags(self: *Self, comptime F: type) void {
            const info = @typeInfo(F);
            if (info != .@"struct" or info.@"struct".layout != .@"packed") {
                @compileError("addFlags requires a packed struct, got " ++ @typeName(F));
            }
            if (info.@"struct".backing_integer != u32) {
                @compileError("addFlags requires packed struct(u32), got " ++ @typeName(F));
            }

            const alloc = self.allocator();
            const flags_name = @typeName(F);
            // Get just the type name without module path
            const short_name = blk: {
                var i = flags_name.len;
                while (i > 0) : (i -= 1) {
                    if (flags_name[i - 1] == '.') break :blk flags_name[i..];
                }
                break :blk flags_name;
            };

            comptime var bit: u5 = 0;
            inline for (info.@"struct".fields) |field| {
                if (field.type == bool) {
                    self.constants.append(alloc, .{
                        .enum_name = short_name,
                        .name = field.name,
                        .value = @as(i64, 1) << bit,
                        .is_bitfield = true,
                    }) catch @panic("OOM");
                    bit += 1;
                }
                // Skip padding fields (non-bool integer types)
            }
        }

        /// Register a standalone integer constant.
        /// Auto-detects value from T's decl if using .auto, converting snake_case to SCREAMING_SNAKE_CASE.
        pub fn addConst(self: *Self, comptime name: [:0]const u8, comptime options: ConstCreateOptions) void {
            const decl_name = comptime casez.comptimeConvert(gdzig_case.constant, name);
            const value: i64 = if (options.value) |v| v else blk: {
                if (!@hasDecl(T, decl_name)) {
                    @compileError("No decl '" ++ decl_name ++ "' found on " ++ @typeName(T) ++ " for constant '" ++ name ++ "'");
                }
                const decl_value = @field(T, decl_name);
                break :blk switch (@typeInfo(@TypeOf(decl_value))) {
                    .int, .comptime_int => @intCast(decl_value),
                    else => @compileError("Constant '" ++ decl_name ++ "' must be an integer type"),
                };
            };

            const alloc = self.allocator();
            self.constants.append(alloc, .{
                .enum_name = "",
                .name = name,
                .value = value,
                .is_bitfield = false,
            }) catch @panic("OOM");
        }

        pub const ConstCreateOptions = struct {
            value: ?i64 = null,

            pub const auto: ConstCreateOptions = .{};
        };

        //
        // Registration
        //

        fn commit(any: *AnyClass, level: InitializationLevel) void {
            const self: *Self = @fieldParentPtr("any", any);
            if (self.level != level) return;

            // 1. Register the class itself
            self.registerClass();

            // 2. Resolve properties first (may create new methods for auto-detected getters/setters)
            for (self.ungrouped_properties.items) |property| {
                property.resolve(property, @ptrCast(&self.methods));
            }
            for (self.groups.items) |grp| {
                grp.resolveEntries();
            }

            // 3. Register all methods (including auto-generated ones from properties)
            for (self.methods.items) |method| {
                method.register();
            }

            // 4. Register all signals
            for (self.signals.items) |signal| {
                signal.register(signal);
            }

            // 5. Register ungrouped properties
            for (self.ungrouped_properties.items) |property| {
                property.register(property);
            }

            // 6. Register groups with their properties and subgroups
            for (self.groups.items) |grp| {
                grp.register();
                grp.registerEntries();
            }

            // 7. Register constants (enums, flags, standalone constants)
            const class_name: StringName = .fromType(T);
            for (self.constants.items) |constant| {
                var enum_name: StringName = .fromLatin1(constant.enum_name, true);
                var const_name: StringName = .fromLatin1(constant.name, true);
                classdb.registerIntegerConstant(&class_name, &enum_name, &const_name, constant.value, constant.is_bitfield);
            }
        }

        const Constant = struct {
            enum_name: [:0]const u8,
            name: [:0]const u8,
            value: i64,
            is_bitfield: bool,
        };

        fn registerClass(self: *Self) void {
            const Userdata = class_mod.ClassUserdataOf(T);
            class_mod.registerClass(T, if (Userdata != void) .{
                .userdata = self.userdata,
                .is_virtual = self.is_virtual,
                .is_abstract = self.is_abstract,
                .is_exposed = self.is_exposed,
                .is_runtime = self.is_runtime,
                .icon_path = self.icon_path,
            } else .{
                .is_virtual = self.is_virtual,
                .is_abstract = self.is_abstract,
                .is_exposed = self.is_exposed,
                .is_runtime = self.is_runtime,
                .icon_path = self.icon_path,
            });
        }
    };
}

/// Method registration info, generic over class type.
pub fn Method(comptime T: type) type {
    return struct {
        const Self = @This();

        pub const CreateOptions = struct {
            /// Method flags.
            flags: MethodFlags = .{},
            /// Default argument values.
            default_arguments: []const *const Variant = &.{},

            pub const auto: CreateOptions = .{};
        };

        name: [:0]const u8,
        // These are needed for Property to infer property type
        return_info: ?classdb.PropertyInfo,
        arg_info: []const classdb.PropertyInfo,
        // Registration function captures the method config at comptime
        register_fn: *const fn () void,

        /// Create a method from a name string.
        /// Looks up the corresponding camelCase decl on T (e.g., "on_timeout" -> T.onTimeout).
        pub fn fromName(comptime name: [:0]const u8, comptime options: CreateOptions) Self {
            // Convert snake_case to camelCase and verify decl exists
            const decl_name = comptime casez.comptimeConvert(gdzig_case.method, name);
            if (!@hasDecl(T, decl_name)) {
                @compileError("No decl '" ++ decl_name ++ "' found on " ++ @typeName(T) ++ " for method '" ++ name ++ "'");
            }
            return fromDecl(name, decl_name, options);
        }

        /// Create a method from an explicit decl name.
        /// name: the method name Godot sees (e.g., "get_health")
        /// decl_name: the Zig decl name (e.g., "getHealth")
        pub fn fromDecl(comptime name: [:0]const u8, comptime decl_name: [:0]const u8, comptime options: CreateOptions) Self {
            const config = method_mod.MethodConfig(T).fromName(name, decl_name, options);
            return .{
                .name = name,
                .return_info = if (config.return_value_info) |info| info.* else null,
                .arg_info = config.argument_info,
                .register_fn = &struct {
                    fn doRegister() void {
                        method_mod.registerMethod(T, config);
                    }
                }.doRegister,
            };
        }

        /// Create a getter method for a field.
        pub fn fieldGetter(comptime name: [:0]const u8, comptime field_name: [:0]const u8) Self {
            const config = method_mod.MethodConfig(T).getter(name, field_name);
            return .{
                .name = name,
                .return_info = if (config.return_value_info) |info| info.* else null,
                .arg_info = config.argument_info,
                .register_fn = &struct {
                    fn doRegister() void {
                        method_mod.registerMethod(T, config);
                    }
                }.doRegister,
            };
        }

        /// Create a setter method for a field.
        pub fn fieldSetter(comptime name: [:0]const u8, comptime field_name: [:0]const u8) Self {
            const config = method_mod.MethodConfig(T).setter(name, field_name);
            return .{
                .name = name,
                .return_info = if (config.return_value_info) |info| info.* else null,
                .arg_info = config.argument_info,
                .register_fn = &struct {
                    fn doRegister() void {
                        method_mod.registerMethod(T, config);
                    }
                }.doRegister,
            };
        }

        pub fn register(self: *const Self) void {
            self.register_fn();
        }
    };
}

/// Property accessor: auto-detect, none, or explicit method.
pub fn Accessor(comptime T: type) type {
    return union(enum) {
        auto,
        none,
        method: *const Method(T),
    };
}

/// Type-erased property for heterogeneous storage.
const AnyProperty = struct {
    resolve: *const fn (*AnyProperty, *anyopaque) void,
    register: *const fn (*AnyProperty) void,
};

/// Property registration info, generic over class type and property name.
pub fn Property(comptime T: type, comptime name: [:0]const u8) type {
    return struct {
        const Self = @This();

        pub const CreateOptions = struct {
            /// Override the getter (.auto = auto-detect, .none = no getter, .method = use this).
            getter: Accessor(T) = .auto,
            /// Override the setter (.auto = auto-detect, .none = no setter, .method = use this).
            setter: Accessor(T) = .auto,
            /// Property hint.
            hint: PropertyHint = .property_hint_none,
            /// Hint string.
            hint_string: String = .empty,
            /// Usage flags.
            usage: PropertyUsageFlags = .property_usage_default,
            /// Index for indexed properties. Requires Godot 4.2+.
            index: ?i64 = null,

            pub const auto: CreateOptions = .{};
        };

        any: AnyProperty,
        class: *Class(T),
        options: CreateOptions,

        // Resolved at commit time
        resolved_getter: ?*const Method(T) = null,
        resolved_setter: ?*const Method(T) = null,

        pub fn init(class: *Class(T), options: CreateOptions) Self {
            return .{
                .any = .{
                    .resolve = @ptrCast(&doResolve),
                    .register = @ptrCast(&doRegister),
                },
                .class = class,
                .options = options,
            };
        }

        pub fn erased(self: *Self) *AnyProperty {
            return &self.any;
        }

        /// Resolve getter/setter methods (may create new methods for auto-detection).
        fn doResolve(any: *AnyProperty, methods_opaque: *anyopaque) void {
            const self: *Self = @alignCast(@fieldParentPtr("any", any));
            const methods: *std.ArrayListUnmanaged(*Method(T)) = @ptrCast(@alignCast(methods_opaque));
            const alloc = self.class.allocator();

            // Indexed properties cannot use auto-detection
            if (self.options.index != null) {
                if (self.options.getter == .auto or self.options.setter == .auto) {
                    @panic("Indexed properties cannot use .auto for getter/setter. Use explicit .{ .method = ... } instead.");
                }
            }

            // Resolve getter/setter and store for later registration
            self.resolved_getter = resolveGetter(self.options.getter, alloc, methods);
            self.resolved_setter = resolveSetter(self.options.setter, alloc, methods);
        }

        /// Register the property with Godot (after methods have been registered).
        fn doRegister(any: *AnyProperty) void {
            const self: *Self = @alignCast(@fieldParentPtr("any", any));

            // Determine property type from getter or setter
            const prop_type: Variant.Tag = if (self.resolved_getter) |g|
                g.return_info.?.type
            else if (self.resolved_setter) |s|
                s.arg_info[0].type
            else
                .nil;

            // Register the property
            const class_name: StringName = .fromType(T);
            var property_name: StringName = .fromLatin1(name, true);

            var getter_name: StringName = if (self.resolved_getter) |g| .fromLatin1(g.name, true) else .empty;
            var setter_name: StringName = if (self.resolved_setter) |s| .fromLatin1(s.name, true) else .empty;

            const info: classdb.PropertyInfo = .{
                .type = prop_type,
                .name = &property_name,
                .hint = self.options.hint,
                .hint_string = &self.options.hint_string,
                .usage = self.options.usage,
            };

            if (self.options.index) |idx| {
                classdb.registerPropertyIndexed(&class_name, &info, &setter_name, &getter_name, idx);
            } else {
                classdb.registerProperty(&class_name, &info, &setter_name, &getter_name);
            }
        }

        // Comptime constants for auto-detection
        const camel = casez.comptimeConvert(gdzig_case.method, name);
        const upper_first = [1]u8{std.ascii.toUpper(camel[0])};
        const getter_decl = "get" ++ upper_first ++ camel[1..];
        const setter_decl = "set" ++ upper_first ++ camel[1..];
        const getter_method_name = "get_" ++ name;
        const setter_method_name = "set_" ++ name;

        // Whether auto-detection can find a getter/setter
        const can_auto_getter = @hasDecl(T, getter_decl) or @hasField(T, camel) or @hasField(T, name);
        const can_auto_setter = @hasDecl(T, setter_decl) or @hasField(T, camel) or @hasField(T, name);

        fn resolveGetter(
            getter: Accessor(T),
            alloc: Allocator,
            methods: *std.ArrayListUnmanaged(*Method(T)),
        ) ?*const Method(T) {
            return switch (getter) {
                .auto => if (can_auto_getter) autoDetectGetter(alloc, methods) else unreachable,
                .none => null,
                .method => |m| m,
            };
        }

        fn resolveSetter(
            setter: Accessor(T),
            alloc: Allocator,
            methods: *std.ArrayListUnmanaged(*Method(T)),
        ) ?*const Method(T) {
            return switch (setter) {
                .auto => if (can_auto_setter) autoDetectSetter(alloc, methods) else unreachable,
                .none => null,
                .method => |m| m,
            };
        }

        fn autoDetectGetter(
            alloc: Allocator,
            methods: *std.ArrayListUnmanaged(*Method(T)),
        ) *const Method(T) {
            // Auto-detect: check for getX method, then field
            if (@hasDecl(T, getter_decl)) {
                const m = alloc.create(Method(T)) catch @panic("OOM");
                m.* = Method(T).fromDecl(getter_method_name, getter_decl, .{});
                methods.append(alloc, m) catch @panic("OOM");
                return m;
            } else if (@hasField(T, camel)) {
                const m = alloc.create(Method(T)) catch @panic("OOM");
                m.* = Method(T).fieldGetter(getter_method_name, camel);
                methods.append(alloc, m) catch @panic("OOM");
                return m;
            } else {
                const m = alloc.create(Method(T)) catch @panic("OOM");
                m.* = Method(T).fieldGetter(getter_method_name, name);
                methods.append(alloc, m) catch @panic("OOM");
                return m;
            }
        }

        fn autoDetectSetter(
            alloc: Allocator,
            methods: *std.ArrayListUnmanaged(*Method(T)),
        ) *const Method(T) {
            // Auto-detect: check for setX method, then field
            if (@hasDecl(T, setter_decl)) {
                const m = alloc.create(Method(T)) catch @panic("OOM");
                m.* = Method(T).fromDecl(setter_method_name, setter_decl, .{});
                methods.append(alloc, m) catch @panic("OOM");
                return m;
            } else if (@hasField(T, camel)) {
                const m = alloc.create(Method(T)) catch @panic("OOM");
                m.* = Method(T).fieldSetter(setter_method_name, camel);
                methods.append(alloc, m) catch @panic("OOM");
                return m;
            } else {
                const m = alloc.create(Method(T)) catch @panic("OOM");
                m.* = Method(T).fieldSetter(setter_method_name, name);
                methods.append(alloc, m) catch @panic("OOM");
                return m;
            }
        }
    };
}

/// Type-erased signal for heterogeneous storage.
const AnySignal = struct {
    register: *const fn (*AnySignal) void,
};

pub fn Signal(comptime T: type, comptime S: type) type {
    return struct {
        const Self = @This();

        any: AnySignal,

        pub fn init() Self {
            return .{
                .any = .{
                    .register = @ptrCast(&doRegister),
                },
            };
        }

        pub fn erased(self: *Self) *AnySignal {
            return &self.any;
        }

        fn doRegister(_: *AnySignal) void {
            const class_name: StringName = .fromType(T);
            const signal_name: StringName = .fromSignal(S);

            const fields = @typeInfo(S).@"struct".fields;
            var arg_info: [fields.len]classdb.PropertyInfo = undefined;
            var names: [fields.len]StringName = undefined;
            inline for (fields, 0..) |field, i| {
                names[i] = .fromComptimeLatin1(field.name);
                arg_info[i] = .{
                    .type = Variant.Tag.forType(field.type),
                    .name = &names[i],
                };
            }

            classdb.registerSignal(&class_name, &signal_name, &arg_info);
        }
    };
}

/// Property group, generic over class type.
/// Groups own their properties and subgroups, handling registration order.
pub fn Group(comptime T: type) type {
    return struct {
        const Self = @This();

        const Entry = union(enum) {
            property: *AnyProperty,
            subgroup: *Subgroup(T),
        };

        class: *Class(T),
        name: [:0]const u8,
        entries: std.ArrayListUnmanaged(Entry),

        pub fn init(class: *Class(T), name: [:0]const u8) Self {
            return .{
                .class = class,
                .name = name,
                .entries = .{},
            };
        }

        /// Add a property by name to this group.
        pub fn addProperty(self: *Self, comptime prop_name: [:0]const u8, options: Property(T, prop_name).CreateOptions) void {
            _ = self.createProperty(prop_name, options);
        }

        /// Create a property by name and return it for further configuration.
        pub fn createProperty(self: *Self, comptime prop_name: [:0]const u8, options: Property(T, prop_name).CreateOptions) *Property(T, prop_name) {
            const alloc = self.class.allocator();
            const property = alloc.create(Property(T, prop_name)) catch @panic("OOM");
            property.* = Property(T, prop_name).init(self.class, options);
            self.entries.append(alloc, .{ .property = property.erased() }) catch @panic("OOM");
            return property;
        }

        /// Add a subgroup within this group.
        pub fn createSubgroup(self: *Self, subgroup_name: [:0]const u8) *Subgroup(T) {
            const alloc = self.class.allocator();
            const subgrp = alloc.create(Subgroup(T)) catch @panic("OOM");
            subgrp.* = Subgroup(T).init(self.class, subgroup_name);
            self.entries.append(alloc, .{ .subgroup = subgrp }) catch @panic("OOM");
            return subgrp;
        }

        pub fn register(self: *const Self) void {
            const class_name: StringName = .fromType(T);
            const group_string: String = .fromLatin1(self.name);
            const empty_prefix: String = .empty;

            classdb.registerPropertyGroup(&class_name, &group_string, &empty_prefix);
        }

        /// Resolve all properties in this group (creates auto-detected methods).
        pub fn resolveEntries(self: *Self) void {
            for (self.entries.items) |entry| {
                switch (entry) {
                    .property => |property| property.resolve(property, @ptrCast(&self.class.methods)),
                    .subgroup => |subgroup| subgroup.resolveProperties(),
                }
            }
        }

        /// Register all properties in this group (after methods have been registered).
        pub fn registerEntries(self: *Self) void {
            for (self.entries.items) |entry| {
                switch (entry) {
                    .property => |property| property.register(property),
                    .subgroup => |subgroup| {
                        subgroup.register();
                        subgroup.registerProperties();
                    },
                }
            }
        }
    };
}

/// Property subgroup, generic over class type.
/// Subgroups can only contain properties (no nesting).
pub fn Subgroup(comptime T: type) type {
    return struct {
        const Self = @This();

        class: *Class(T),
        name: [:0]const u8,
        properties: std.ArrayListUnmanaged(*AnyProperty),

        pub fn init(class: *Class(T), subgroup_name: [:0]const u8) Self {
            return .{
                .class = class,
                .name = subgroup_name,
                .properties = .{},
            };
        }

        /// Add a property by name to this subgroup.
        pub fn addProperty(self: *Self, comptime prop_name: [:0]const u8, options: Property(T, prop_name).CreateOptions) void {
            _ = self.createProperty(prop_name, options);
        }

        /// Create a property by name and return it for further configuration.
        pub fn createProperty(self: *Self, comptime prop_name: [:0]const u8, options: Property(T, prop_name).CreateOptions) *Property(T, prop_name) {
            const alloc = self.class.allocator();
            const property = alloc.create(Property(T, prop_name)) catch @panic("OOM");
            property.* = Property(T, prop_name).init(self.class, options);
            self.properties.append(alloc, property.erased()) catch @panic("OOM");
            return property;
        }

        pub fn register(self: *const Self) void {
            const class_name: StringName = .fromType(T);
            const subgroup_string: String = .fromLatin1(self.name);
            const empty_prefix: String = .empty;

            classdb.registerPropertySubgroup(&class_name, &subgroup_string, &empty_prefix);
        }

        /// Resolve all properties in this subgroup (creates auto-detected methods).
        pub fn resolveProperties(self: *Self) void {
            for (self.properties.items) |property| {
                property.resolve(property, @ptrCast(&self.class.methods));
            }
        }

        /// Register all properties in this subgroup (after methods have been registered).
        pub fn registerProperties(self: *Self) void {
            for (self.properties.items) |property| {
                property.register(property);
            }
        }
    };
}

/// Type-erased callbacks for heterogeneous storage.
const AnyCallbacks = struct {
    enter_fn: ?*const fn (*AnyCallbacks, InitializationLevel) void,
    exit_fn: ?*const fn (*AnyCallbacks, InitializationLevel) void,
};

fn Callbacks(comptime T: type) type {
    return struct {
        const Self = @This();

        pub const CreateOptions = struct {
            enter: ?*const fn (*T, InitializationLevel) void = if (@hasDecl(T, "enter")) T.enter else null,
            exit: ?*const fn (*T, InitializationLevel) void = if (@hasDecl(T, "exit")) T.exit else null,

            pub const auto: CreateOptions = .{};
        };

        any: AnyCallbacks,
        userdata: *T,
        enter: ?*const fn (*T, InitializationLevel) void,
        exit: ?*const fn (*T, InitializationLevel) void,

        pub fn init(userdata: *T, options: CreateOptions) Self {
            return .{
                .any = .{
                    .enter_fn = if (options.enter != null) @ptrCast(&doEnter) else null,
                    .exit_fn = if (options.exit != null) @ptrCast(&doExit) else null,
                },
                .userdata = userdata,
                .enter = options.enter,
                .exit = options.exit,
            };
        }

        pub fn erased(self: *Self) *AnyCallbacks {
            return &self.any;
        }

        fn doEnter(any: *AnyCallbacks, level: InitializationLevel) void {
            const self: *Self = @fieldParentPtr("any", any);
            self.enter.?(self.userdata, level);
        }

        fn doExit(any: *AnyCallbacks, level: InitializationLevel) void {
            const self: *Self = @fieldParentPtr("any", any);
            self.exit.?(self.userdata, level);
        }
    };
}

const std = @import("std");
const Allocator = std.mem.Allocator;
const ArenaAllocator = std.heap.ArenaAllocator;

const casez = @import("casez");
const common = @import("common");
const gdzig_case = common.gdzig_case;
const godot_case = common.godot_case;

const gdzig = @import("gdzig");
const classdb = gdzig.class.ClassDb;
const MethodFlags = gdzig.global.MethodFlags;
const PropertyHint = gdzig.global.PropertyHint;
const PropertyUsageFlags = gdzig.global.PropertyUsageFlags;
const String = gdzig.builtin.String;
const StringName = gdzig.builtin.StringName;
const Variant = gdzig.builtin.Variant;

const class_mod = @import("class.zig");
const method_mod = @import("method.zig");
const InitializationLevel = @import("../extension.zig").InitializationLevel;
