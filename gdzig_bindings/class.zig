//!
//!
//! THESE STUBS ARE AUTOMATICALLY REMOVED DURING THE BUILD PROCESS
//!
//!

comptime {
    @compileError("This file is a stub and should not be getting compiled.");
}

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
pub const Script = opaque {
    pub fn ptr(self: *@This()) c.GDExtensionScriptInstancePtr {
        return @ptrCast(self);
    }
};
pub const ScriptExtension = opaque {
    pub fn ptr(self: *@This()) c.GDExtensionScripInstanceEx {
        return @ptrCast(self);
    }
};
pub const ScriptLanguage = opaque {
    pub fn ptr(self: *@This()) c.GDExtensionScriptLanguagePtr {
        return @ptrCast(self);
    }
};

const c = @import("gdextension");
