/// TODO: make this private once API is ready
pub var raw: Interface = undefined;

pub fn typeName(comptime T: type) *builtin.StringName {
    const Static = &struct {
        const _ = T;
        var name: builtin.StringName = undefined;
        var init: bool = false;
    };

    if (!Static.init) {
        Static.name = builtin.StringName.fromComptimeLatin1(blk: {
            const full = @typeName(T);
            const pos = std.mem.lastIndexOfScalar(u8, full, '.') orelse break :blk full;
            break :blk full[pos + 1 ..];
        });
        Static.init = true;
    }

    return &Static.name;
}

comptime {
    std.testing.refAllDeclsRecursive(@This());
}

const std = @import("std");

const c = @import("gdextension");
const oopz = @import("oopz");

pub const api = @import("api.zig");
pub const builtin = @import("builtin.zig");
pub const class = @import("class.zig");
pub const general = @import("general.zig");
pub const global = @import("global.zig");
/// TODO: make this private once API is ready
pub const Interface = @import("Interface.zig");
pub const math = @import("math.zig");
pub const random = @import("random.zig");
