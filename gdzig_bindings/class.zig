//!
//!
//! THESE STUBS ARE AUTOMATICALLY REMOVED DURING THE BUILD PROCESS
//!
//!

pub const Object = opaque {
    pub fn ptr(self: *@This()) c.GDExtensionObjectPtr {
        return @ptrCast(self);
    }
    pub fn constPtr(self: *const @This()) c.GDExtensionConstObjectPtr {
        return @ptrCast(self);
    }
};
pub const RefCounted = opaque {
    pub fn ptr(self: *@This()) c.GDExtensionRefPtr {
        return @ptrCast(self);
    }
    pub fn constPtr(self: *const @This()) c.GDExtensionConstRefPtr {
        return @ptrCast(self);
    }
};

const c = @import("gdextension");
