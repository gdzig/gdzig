header: Header,
builtin_class_sizes: []BuiltinSize,
builtin_class_member_offsets: []BuiltinMemberOffset,
global_constants: []GlobalConstant,
global_enums: []GlobalEnum,
utility_functions: []UtilityFunction,
builtin_classes: []Builtin,
classes: []Class,
singletons: []Singleton,
native_structures: []NativeStructure,

pub const Header = struct {
    version_major: i64,
    version_minor: i64,
    version_patch: i64,
    version_status: []const u8,
    version_build: []const u8,
    version_full_name: []const u8,
};

pub const SizeInfo = struct {
    name: []const u8,
    size: i64,
};

pub const BuiltinSize = struct {
    build_configuration: []const u8,
    sizes: []SizeInfo,
};

pub const MemberOffset = struct {
    member: []const u8,
    offset: i64,
    meta: []const u8,
};

pub const ClassMemberOffsets = struct {
    name: []const u8,
    members: []MemberOffset,
};

pub const BuiltinMemberOffset = struct {
    build_configuration: []const u8,
    classes: []ClassMemberOffsets,
};

pub const Builtin = struct {
    name: []const u8,
    indexing_return_type: []const u8 = "",
    is_keyed: bool,
    members: ?[]Member = null,
    constants: ?[]Constant = null,
    enums: ?[]Enum = null,
    operators: []Operator,
    methods: ?[]Method = null,
    constructors: []Constructor,
    has_destructor: bool,
    brief_description: ?[]const u8 = null,
    description: ?[]const u8 = null,

    pub const Constructor = struct {
        index: i64,
        arguments: ?[]Argument = null,
        description: ?[]const u8 = null,

        pub const Argument = struct {
            name: []const u8,
            type: []const u8,
        };
    };

    pub const Method = struct {
        name: []const u8,
        return_type: []const u8 = "void",
        is_vararg: bool,
        is_const: bool,
        is_static: bool,
        hash: u64,
        arguments: ?[]Argument = null,
        description: ?[]const u8 = null,

        pub fn isPrivate(self: Method) bool {
            return std.mem.startsWith(u8, self.name, "_");
        }

        pub fn isPublic(self: Method) bool {
            return !self.isPrivate();
        }

        pub const Argument = struct {
            name: []const u8,
            type: []const u8,
            default_value: []const u8 = "",
        };
    };

    pub const Operator = struct {
        name: []const u8,
        right_type: []const u8 = "",
        return_type: []const u8,
        description: ?[]const u8 = null,
    };

    pub const Enum = struct {
        name: []const u8,
        values: []Value,

        pub const Value = struct {
            name: []const u8,
            value: i64,
            description: ?[]const u8 = null,
        };
    };

    pub const Constant = struct {
        name: []const u8,
        type: []const u8,
        value: []const u8,
    };

    pub const Member = struct {
        name: []const u8,
        type: []const u8,
        description: ?[]const u8 = null,
    };
};

pub const Class = struct {
    name: []const u8,
    is_refcounted: bool,
    is_instantiable: bool,
    inherits: ?[]const u8,
    api_type: []const u8,

    constants: ?[]Constant = null,
    enums: ?[]Enum = null,
    methods: ?[]Method = null,
    properties: ?[]Property = null,
    signals: ?[]Signal = null,

    brief_description: ?[]const u8,
    description: ?[]const u8,

    pub fn findMethod(self: Class, name: []const u8) ?Method {
        if (self.methods) |methods| {
            for (methods) |method| {
                if (std.mem.eql(u8, method.name, name)) {
                    return method;
                }
            }
        }
        return null;
    }

    pub const Property = struct {
        type: []const u8,
        name: []const u8,
        setter: []const u8 = "",
        getter: []const u8,
        index: i64 = -1,
    };

    pub const Constant = struct {
        name: []const u8,
        value: i64,
    };

    // The schemas are identical.
    pub const Enum = GlobalEnum;

    pub const Method = struct {
        name: []const u8,
        is_const: bool,
        is_static: bool,
        is_required: bool = false,
        is_vararg: bool,
        is_virtual: bool,
        hash: u64 = 0,
        hash_compatibility: ?[]u64 = null,
        return_value: ?ReturnValue = null,
        arguments: ?[]Argument = null,
        description: ?[]const u8 = null,

        pub fn isPrivate(self: Method) bool {
            return std.mem.startsWith(u8, self.name, "_");
        }

        pub fn isPublic(self: Method) bool {
            return !self.isPrivate();
        }

        pub const Argument = struct {
            name: []const u8,
            type: []const u8,
            meta: []const u8 = "",
            default_value: []const u8 = "",
        };

        pub const ReturnValue = struct {
            type: []const u8,
            meta: []const u8 = "",
            default_value: []const u8 = "",
        };
    };

    pub const Signal = struct {
        name: []const u8,
        arguments: ?[]Argument = null,

        pub const Argument = struct {
            name: []const u8,
            type: []const u8,
        };
    };
};

pub const GlobalConstant = struct {
    name: []const u8,
    value: []const u8,
};

pub const GlobalEnum = struct {
    name: []const u8,
    is_bitfield: bool,
    values: []Value,

    pub const Value = struct {
        name: []const u8,
        value: i64,
        description: ?[]const u8 = null,
    };
};

pub const NativeStructure = struct {
    name: []const u8,
    format: []const u8,
};

pub const Singleton = struct {
    name: []const u8,
    type: []const u8,
};

pub const UtilityFunction = struct {
    name: []const u8,
    return_type: []const u8 = "",
    category: []const u8,
    is_vararg: bool,
    hash: u64,
    arguments: ?[]Argument = null,
    description: ?[]const u8 = null,

    pub const Argument = struct {
        name: []const u8,
        type: []const u8,
    };
};

pub fn findClass(self: @This(), name: ?[]const u8) ?Class {
    if (name == null) {
        return null;
    }
    for (self.classes) |class| {
        if (std.mem.eql(u8, class.name, name.?)) {
            return class;
        }
    }

    return null;
}

pub fn findBuiltin(self: @This(), name: []const u8) ?Builtin {
    for (self.builtin_classes) |class| {
        if (std.mem.eql(u8, class.name, name)) {
            return class;
        }
    }

    return null;
}

pub const GdMethod = union(enum) {
    class: Class.Method,
    builtin: Builtin.Method,
};

pub const Type = union(enum) {
    class: Class,
    builtin: Builtin,

    pub fn getClassName(self: @This()) []const u8 {
        switch (self) {
            inline else => |class| return class.name,
        }
    }
};

// TODO: handle in Context
pub fn findParent(self: @This(), class: Class) ?Class {
    if (class.inherits == null) {
        return null;
    }
    return self.findClass(class.inherits);
}

const std = @import("std");
