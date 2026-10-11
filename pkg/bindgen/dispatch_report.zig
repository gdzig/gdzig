//! Optional human-readable adapter diagnostics. Generation never depends on this report.

/// Describe missing and stale range adapters only when verbose output is requested.
pub fn write(writer: *std.Io.Writer, classes: []const Context.Class, verbose: bool) !void {
    if (!verbose) return;
    for (classes) |class| {
        // Inherited dispatch is reported once, at its original API owner.
        for (class.functions.values()) |function| {
            if (function.legacy_range != null) continue;
            const owner = function.base orelse continue;
            if (!std.mem.eql(u8, owner, class.name_api)) continue;
            for (function.dispatch_ranges) |group| {
                if (group.available) continue;
                try writer.print(
                    "{s}.{s}: Godot {d}.{d}.{d} layout {t} ({s}) needs {s}; " ++
                        "calls panic at runtime or fail in an inside-range minimum build\n",
                    .{ owner, function.name_api, group.lower.major, group.lower.minor, group.lower.patch, group.layout, group.signature.difference, group.adapter },
                );
            }
        }

        // A conventional adapter with no measured range is stale, not a build error.
        for (class.mixin_names.keys()) |name| {
            if (!adapterName(name) or inheritedName(classes, class, name)) continue;
            var matched = false;
            for (class.functions.values()) |function| {
                for (function.dispatch_ranges) |group| {
                    if (std.mem.eql(u8, name, group.adapter)) matched = true;
                }
            }
            if (!matched) {
                try writer.print("{s}.{s}: stale legacy adapter, no measured layout range\n", .{
                    class.name_api, name,
                });
            }
        }
    }
}

fn inheritedName(classes: []const Context.Class, class: Context.Class, name: []const u8) bool {
    const parent = class.base_api orelse return false;
    for (classes) |base| {
        if (std.mem.eql(u8, base.name_api, parent)) return base.mixin_names.contains(name);
    }
    return false;
}

fn adapterName(name: []const u8) bool {
    const last = std.mem.lastIndexOfScalar(u8, name, '_') orelse return false;
    _ = std.fmt.parseInt(u32, name[last + 1 ..], 10) catch return false;
    const previous = std.mem.lastIndexOfScalar(u8, name[0..last], '_') orelse return false;
    _ = std.fmt.parseInt(u32, name[previous + 1 .. last], 10) catch return false;
    return previous != 0;
}

test "missing private adapters and stale names are verbose-only diagnostics" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const group: version_dispatch.Group = .{
        .lower = .@"4.6",
        .upper = .@"4.7",
        .old_hash = 111,
        .layout = .return_added,
        .adapter = "probe_4_6",
        .available = false,
        .signature = .fromRecord(.{
            .kind = .class,
            .owner = "Probe",
            .method = "probe",
            .hash = 111,
            .compatibility = &.{},
            .virtual = false,
            .is_const = false,
            .is_static = false,
            .is_vararg = false,
            .arguments = &.{},
            .@"return" = null,
        }, "void -> bool"),
    };
    var class: Context.Class = .{ .name_api = "Probe" };
    try class.functions.put(allocator, "probe", .{
        .name = "probe",
        .name_api = "probe",
        .base = "Probe",
        .dispatch_ranges = &.{group},
    });
    try class.mixin_names.put(allocator, "obsolete_4_6", {});
    try class.mixin_names.put(allocator, "ordinary_helper", {});
    var output: std.Io.Writer.Allocating = .init(std.testing.allocator);
    defer output.deinit();
    try write(&output.writer, &.{class}, false);
    try std.testing.expectEqual(@as(usize, 0), output.written().len);
    try write(&output.writer, &.{class}, true);
    try std.testing.expect(std.mem.indexOf(u8, output.written(), "needs probe_4_6") != null);
    try std.testing.expect(std.mem.indexOf(u8, output.written(), "obsolete_4_6: stale") != null);
    try std.testing.expect(std.mem.indexOf(u8, output.written(), "ordinary_helper") == null);
}

const std = @import("std");

const Context = @import("Context.zig");
const version_dispatch = @import("version_dispatch.zig");
