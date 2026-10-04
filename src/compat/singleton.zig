/// Finds the nearest class that owns singleton storage. Descendants use that
/// owner's engine name and pointer, rather than inventing a new singleton.
pub fn owner(comptime T: type) ?type {
    @setEvalBranchQuota(10000);
    if (T == void) return null;
    inline for (oopz.selfAndAncestorsOf(T)) |Ancestor| {
        if (@hasDecl(Ancestor, "instance")) return Ancestor;
    }
    return null;
}

test "singleton descendants use the nearest storage owner" {
    const Root = opaque {
        pub const Base = void;
    };
    const Singleton = opaque {
        pub const Base = Root;
        pub var instance: ?*@This() = null;
    };
    const Child = opaque {
        pub const Base = Singleton;
    };
    const Grandchild = struct {
        base: *Child,
    };
    const NearerSingleton = struct {
        base: *Grandchild,
        pub var instance: ?*@This() = null;
    };
    try std.testing.expect(owner(void) == null);
    try std.testing.expect(owner(Root) == null);
    try std.testing.expect(owner(Singleton).? == Singleton);
    try std.testing.expect(owner(Child).? == Singleton);
    try std.testing.expect(owner(Grandchild).? == Singleton);
    try std.testing.expect(owner(NearerSingleton).? == NearerSingleton);
}

const std = @import("std");
const oopz = @import("oopz");
