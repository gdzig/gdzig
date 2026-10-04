/// Finds the nearest class that owns singleton storage. Descendants use that
/// owner's engine name and pointer, rather than inventing a new singleton.
pub fn owner(comptime T: type) ?type {
    if (T == void) return null;
    if (@hasDecl(T, "instance")) return T;
    if (@hasDecl(T, "Base")) return owner(T.Base);
    return null;
}

test "singleton descendants use the nearest storage owner" {
    const Root = struct {
        pub const Base = void;
    };
    const Singleton = struct {
        pub const Base = Root;
        pub var instance: ?*@This() = null;
    };
    const Child = struct {
        pub const Base = Singleton;
    };
    const Grandchild = struct {
        pub const Base = Child;
    };
    const NearerSingleton = struct {
        pub const Base = Grandchild;
        pub var instance: ?*@This() = null;
    };
    try std.testing.expect(owner(Root) == null);
    try std.testing.expect(owner(Singleton).? == Singleton);
    try std.testing.expect(owner(Child).? == Singleton);
    try std.testing.expect(owner(Grandchild).? == Singleton);
    try std.testing.expect(owner(NearerSingleton).? == NearerSingleton);
}

const std = @import("std");
