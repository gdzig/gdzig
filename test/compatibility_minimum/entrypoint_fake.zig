//! Isolated fake dispatch for the real entrypoints. Never used by engine tests.
// SAFETY: The real entrypoint publishes its version and checks the floor before dispatch initialization.
pub var raw: Raw = undefined;

pub const VersionProbe = struct {
    version: Version,
    getGodotVersion: std.meta.Child(c.GDExtensionInterfaceGetGodotVersion),
};

/// Query the fixture engine version through the required 4.1 interface.
pub fn probeEngineVersion(proc: std.meta.Child(c.GDExtensionInterfaceGetProcAddress)) VersionProbe {
    const query: std.meta.Child(c.GDExtensionInterfaceGetGodotVersion) =
        @ptrCast(proc("get_godot_version").?);
    var actual: Version = undefined;
    query(@ptrCast(&actual));
    return .{ .version = actual, .getGodotVersion = query };
}

const Raw = struct {
    version: Version,

    /// Initialize isolated dispatch after the entrypoint accepts the floor.
    pub fn initWithVersion(_: c.GDExtensionInterfaceGetProcAddress, _: *anyopaque, probe: VersionProbe) Raw {
        state.dispatch_initializations += 1;
        return .{ .version = probe.version };
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
pub const c = runtime.c;
pub const Version = runtime.Version;
pub const initializeVersion = runtime.initializeVersion;
pub const testing = runtime.testing;

const state = @import("state");
