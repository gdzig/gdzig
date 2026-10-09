//! Isolated fake dispatch for the real entrypoints. Never used by engine tests.
// SAFETY: The real entrypoint initializes isolated dispatch before its first query.
pub var raw: Raw = undefined;

const Raw = struct {
    getGodotVersion: std.meta.Child(c.GDExtensionInterfaceGetGodotVersion),

    /// Initialize isolated dispatch while retaining the real version initializer.
    pub fn init(proc: c.GDExtensionInterfaceGetProcAddress, _: *anyopaque) Raw {
        const query: std.meta.Child(c.GDExtensionInterfaceGetGodotVersion) =
            @ptrCast(proc.?("get_godot_version").?);
        // Only this field is read by the real initializeVersion implementation.
        runtime.raw.getGodotVersion = query;
        return .{ .getGodotVersion = query };
    }
};

pub const class = struct {
    pub const Os = struct {
        /// Count startup without touching a real operating-system process.
        pub fn getProcessId() i64 {
            state.startups += 1;
            return 0;
        }
        /// Keep the actual harness quit path harmless in this isolated fixture.
        pub fn kill(_: i64) bool {
            return true;
        }
    };
};
pub const testing = runtime.testing;

pub const extension = struct {
    pub const Registry = struct {
        /// Construct an empty registry for the real normal entrypoint.
        pub fn init(_: std.mem.Allocator) @This() {
            return .{};
        }
        /// Ignore initialization levels in the isolated registry.
        pub fn enter(_: *@This(), _: Level) void {}
        /// Ignore deinitialization levels in the isolated registry.
        pub fn exit(_: *@This(), _: Level) void {}
        /// No registry allocations exist to free.
        pub fn deinit(_: *@This()) void {}

        const Level = enum {
            core,
            servers,
            scene,
            editor,
        };
    };
    pub const PropertyListInstanceBinding = Cleanup;
    pub const DestroyInstanceBinding = Cleanup;
    const Cleanup = struct {
        /// No instance bindings exist in this fixture.
        pub fn cleanup() void {}
    };
};

const std = @import("std");
pub const engine_allocator = std.testing.allocator;

const runtime = @import("runtime");
const state = @import("state");
pub const c = runtime.c;
pub const Version = runtime.Version;
pub const initializeVersion = runtime.initializeVersion;
