//!
//!
//! THESE STUBS ARE AUTOMATICALLY REMOVED DURING THE BUILD PROCESS
//!
//!

comptime {
    @compileError("This file is a stub and should not be getting compiled.");
}

pub const Array = extern struct {
    pub fn ptr(self: *@This()) c.GDExtensionTypePtr {
        return @ptrCast(self);
    }
    pub fn constPtr(self: *const @This()) c.GDExtensionConstTypePtr {
        return @ptrCast(self);
    }
};
pub const Callable = extern struct {
    pub fn ptr(self: *@This()) c.GDExtensionTypePtr {
        return @ptrCast(self);
    }
    pub fn constPtr(self: *const @This()) c.GDExtensionConstTypePtr {
        return @ptrCast(self);
    }
};
pub const Color = extern struct {
    pub fn ptr(self: *@This()) c.GDExtensionTypePtr {
        return @ptrCast(self);
    }
    pub fn constPtr(self: *const @This()) c.GDExtensionConstTypePtr {
        return @ptrCast(self);
    }
};
pub const Dictionary = extern struct {
    pub fn ptr(self: *@This()) c.GDExtensionTypePtr {
        return @ptrCast(self);
    }
    pub fn constPtr(self: *const @This()) c.GDExtensionConstTypePtr {
        return @ptrCast(self);
    }
};
pub const PackedByteArray = extern struct {
    pub fn ptr(self: *@This()) c.GDExtensionTypePtr {
        return @ptrCast(self);
    }
    pub fn constPtr(self: *const @This()) c.GDExtensionConstTypePtr {
        return @ptrCast(self);
    }
};
pub const PackedInt32Array = extern struct {
    pub fn ptr(self: *@This()) c.GDExtensionTypePtr {
        return @ptrCast(self);
    }
    pub fn constPtr(self: *const @This()) c.GDExtensionConstTypePtr {
        return @ptrCast(self);
    }
};
pub const PackedInt64Array = extern struct {
    pub fn ptr(self: *@This()) c.GDExtensionTypePtr {
        return @ptrCast(self);
    }
    pub fn constPtr(self: *const @This()) c.GDExtensionConstTypePtr {
        return @ptrCast(self);
    }
};
pub const PackedFloat32Array = extern struct {
    pub fn ptr(self: *@This()) c.GDExtensionTypePtr {
        return @ptrCast(self);
    }
    pub fn constPtr(self: *const @This()) c.GDExtensionConstTypePtr {
        return @ptrCast(self);
    }
};
pub const PackedFloat64Array = extern struct {
    pub fn ptr(self: *@This()) c.GDExtensionTypePtr {
        return @ptrCast(self);
    }
    pub fn constPtr(self: *const @This()) c.GDExtensionConstTypePtr {
        return @ptrCast(self);
    }
};
pub const PackedStringArray = extern struct {
    pub fn ptr(self: *@This()) c.GDExtensionTypePtr {
        return @ptrCast(self);
    }
    pub fn constPtr(self: *const @This()) c.GDExtensionConstTypePtr {
        return @ptrCast(self);
    }
};
pub const PackedVector2Array = extern struct {
    pub fn ptr(self: *@This()) c.GDExtensionTypePtr {
        return @ptrCast(self);
    }
    pub fn constPtr(self: *const @This()) c.GDExtensionConstTypePtr {
        return @ptrCast(self);
    }
};
pub const PackedVector3Array = extern struct {
    pub fn ptr(self: *@This()) c.GDExtensionTypePtr {
        return @ptrCast(self);
    }
    pub fn constPtr(self: *const @This()) c.GDExtensionConstTypePtr {
        return @ptrCast(self);
    }
};
pub const PackedColorArray = extern struct {
    pub fn ptr(self: *@This()) c.GDExtensionTypePtr {
        return @ptrCast(self);
    }
    pub fn constPtr(self: *const @This()) c.GDExtensionConstTypePtr {
        return @ptrCast(self);
    }
};
pub const PackedVector4Array = extern struct {
    pub fn ptr(self: *@This()) c.GDExtensionTypePtr {
        return @ptrCast(self);
    }
    pub fn constPtr(self: *const @This()) c.GDExtensionConstTypePtr {
        return @ptrCast(self);
    }
};
pub const RID = extern struct {};
pub const String = extern struct {
    pub fn ptr(self: *@This()) c.GDExtensionStringPtr {
        return @ptrCast(self);
    }
    pub fn constPtr(self: *const @This()) c.GDExtensionConstStringPtr {
        return @ptrCast(self);
    }
};
pub const StringName = extern struct {
    pub fn ptr(self: *@This()) c.GDExtensionStringNamePtr {
        return @ptrCast(self);
    }
    pub fn constPtr(self: *const @This()) c.GDExtensionConstStringNamePtr {
        return @ptrCast(self);
    }
};
pub const Vector2 = extern struct {
    pub fn ptr(self: *@This()) c.GDExtensionTypePtr {
        return @ptrCast(self);
    }
    pub fn constPtr(self: *const @This()) c.GDExtensionConstTypePtr {
        return @ptrCast(self);
    }
};
pub const Vector3 = extern struct {
    pub fn ptr(self: *@This()) c.GDExtensionTypePtr {
        return @ptrCast(self);
    }
    pub fn constPtr(self: *const @This()) c.GDExtensionConstTypePtr {
        return @ptrCast(self);
    }
};
pub const Vector4 = extern struct {
    pub fn ptr(self: *@This()) c.GDExtensionTypePtr {
        return @ptrCast(self);
    }
    pub fn constPtr(self: *const @This()) c.GDExtensionConstTypePtr {
        return @ptrCast(self);
    }
};

const c = @import("gdextension");

pub const Variant = @import("./builtin/variant.zig").Variant;
