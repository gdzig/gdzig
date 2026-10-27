//! Audit one engine's gdextension_interface.h against the measured evidence.

const Arguments = struct {
    manifest: []const u8,
    current_header: []const u8,
    engine_header: []const u8,
};

const usage =
    "Usage: gdzig-compat-audit [--manifest=<zon>] [--current-header=<h>] --engine-header=<h>\n";

fn fromArgs(args: *Args) !Arguments {
    const result: Arguments = .{
        .manifest = (try args.optional([]const u8, "manifest")) orelse
            "pkg/bindgen/generated/compatibility.zon",
        .current_header = (try args.optional([]const u8, "current-header")) orelse
            "vendor/gdextension_interface.h",
        .engine_header = try args.required([]const u8, "engine-header"),
    };
    try args.reject(.strict);
    return result;
}

/// Audit one engine header and return 0 when it matches the vendored evidence.
fn audit(io: std.Io, allocator: Allocator, arguments: Arguments) !u8 {
    const metadata = try loadManifest(allocator, io, arguments.manifest);
    try metadata.validateInterfaceShape();

    const current_bytes = try std.Io.Dir.cwd().readFileAlloc(
        io,
        arguments.current_header,
        allocator,
        .limited(16 * 1024 * 1024),
    );
    const engine_bytes = try std.Io.Dir.cwd().readFileAlloc(
        io,
        arguments.engine_header,
        allocator,
        .limited(16 * 1024 * 1024),
    );
    const current = try interfaces.Names.parse(allocator, current_bytes);
    const engine = try interfaces.Names.parse(allocator, engine_bytes);
    try metadata.validateInterfaces(allocator, current.items);

    var output: std.Io.Writer.Allocating = .init(allocator);
    const status = try report(allocator, metadata, current, engine, &output.writer);
    try std.Io.File.stdout().writeStreamingAll(io, output.written());
    return status;
}

/// Write the audit report and return 0 when the name sets match.
fn report(
    allocator: Allocator,
    metadata: manifest.Manifest,
    current: interfaces.Names,
    engine: interfaces.Names,
    writer: *std.Io.Writer,
) !u8 {
    var engine_only: std.ArrayList([]const u8) = .empty;
    var vendored_only: std.ArrayList([]const u8) = .empty;
    try difference(allocator, engine, current, &engine_only, &vendored_only);

    try writer.print("manifest digest: {s}\n", .{metadata.current_interfaces_sha256});
    try writer.print("current names: {d}\n", .{current.items.len});
    try writer.print("engine names: {d}\n", .{engine.items.len});
    try writer.print("engine-only: {d}\n", .{engine_only.items.len});
    for (engine_only.items) |name| try writer.print("  {s}\n", .{name});
    try writer.print("vendored-only: {d}\n", .{vendored_only.items.len});
    for (vendored_only.items) |name| {
        const availability = try metadata.interfaceAvailability(name);
        try writer.print("  {s} (gate {d}.{d}.{d}", .{
            name,
            availability.gate.major,
            availability.gate.minor,
            availability.gate.patch,
        });
        if (availability.last_absent) |absent| {
            try writer.print(", last_absent {d}.{d}.{d}", .{
                absent.major,
                absent.minor,
                absent.patch,
            });
        } else {
            try writer.writeAll(", last_absent none");
        }
        try writer.print(", present_in_oldest {s})\n", .{
            if (availability.present_in_oldest) "true" else "false",
        });
    }

    return if (engine_only.items.len == 0 and vendored_only.items.len == 0) 0 else 1;
}

/// Compare two canonical sets in byte-wise order.
fn difference(
    allocator: Allocator,
    engine: interfaces.Names,
    current: interfaces.Names,
    engine_only: *std.ArrayList([]const u8),
    vendored_only: *std.ArrayList([]const u8),
) !void {
    var engine_index: usize = 0;
    var current_index: usize = 0;
    while (engine_index < engine.items.len or current_index < current.items.len) {
        if (current_index == current.items.len) {
            try engine_only.append(allocator, engine.items[engine_index]);
            engine_index += 1;
            continue;
        }
        if (engine_index == engine.items.len) {
            try vendored_only.append(allocator, current.items[current_index]);
            current_index += 1;
            continue;
        }
        switch (std.mem.order(u8, engine.items[engine_index], current.items[current_index])) {
            .lt => {
                try engine_only.append(allocator, engine.items[engine_index]);
                engine_index += 1;
            },
            .gt => {
                try vendored_only.append(allocator, current.items[current_index]);
                current_index += 1;
            },
            .eq => {
                engine_index += 1;
                current_index += 1;
            },
        }
    }
}

fn loadManifest(allocator: Allocator, io: std.Io, path: []const u8) !manifest.Manifest {
    const bytes = try std.Io.Dir.cwd().readFileAlloc(
        io,
        path,
        allocator,
        .limited(128 * 1024 * 1024),
    );
    var diagnostics: std.zon.parse.Diagnostics = undefined;
    return std.zon.parse.fromSlice(manifest.Manifest, .{
        .gpa = allocator,
        .arena = allocator,
        .source = try allocator.dupeSentinel(u8, bytes, 0),
        .diagnostics = &diagnostics,
    });
}

fn fail(err: anyerror) u8 {
    std.debug.print("compat-audit: {t}\n{s}", .{ err, usage });
    return 2;
}

fn runResult(init: std.process.Init) !u8 {
    var args: Args = try .init(init.gpa, init.minimal.args);
    defer args.deinit(init.gpa);
    const arguments = try fromArgs(&args);

    var arena: std.heap.ArenaAllocator = .init(init.gpa);
    defer arena.deinit();
    return audit(init.io, arena.allocator(), arguments);
}

fn run(init: std.process.Init) u8 {
    return runResult(init) catch |err| fail(err);
}

/// Audit an engine header against the measured compatibility evidence.
pub fn main(init: std.process.Init) void {
    std.process.exit(run(init));
}

const testing = struct {
    const header =
        \\ * @name get_godot_version
        \\ * @name mem_alloc
        \\ * @name variant_get_type_by_name
    ;

    const engine_with_changes =
        \\ * @name get_godot_version
        \\ * @name audit_probe
        \\ * @name variant_get_type_by_name
    ;

    fn manifestFor(allocator: Allocator, names: interfaces.Names) !manifest.Manifest {
        return .{
            .current = .{
                .version = "4.7.2",
                .sha256 = "raw",
                .checksum_kind = .raw_sha256,
                .status = "stable",
                .build = "official",
                .precision = "single",
            },
            .current_interfaces_sha256 = try names.digest(allocator),
            .targets = &.{},
            .interfaces = &.{},
            .tables = &.{},
        };
    }
};

test "audit arguments reject unknown arguments and a missing engine header" {
    for ([_][]const []const u8{
        &.{"audit"},
        &.{ "audit", "--engine-header=h.h", "--unknown=x" },
        &.{ "audit", "--engine-header=h.h", "path" },
    }, [_]anyerror{
        error.MissingArgument,
        error.UnusedArgument,
        error.UnusedPositional,
    }) |argv, expected| {
        var args: Args = try .initSlice(std.testing.allocator, argv);
        defer args.deinit(std.testing.allocator);
        try std.testing.expectError(expected, fromArgs(&args));
    }
}

test "identical headers report no differences and exit zero" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const names = try interfaces.Names.parse(a, testing.header);
    const metadata = try testing.manifestFor(a, names);
    var output: std.Io.Writer.Allocating = .init(a);
    try std.testing.expectEqual(@as(u8, 0), try report(a, metadata, names, names, &output.writer));
    try std.testing.expect(std.mem.indexOf(u8, output.written(), "engine-only: 0") != null);
    try std.testing.expect(std.mem.indexOf(u8, output.written(), "vendored-only: 0") != null);
}

test "different headers list both directions and exit one" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const current = try interfaces.Names.parse(a, testing.header);
    const engine = try interfaces.Names.parse(a, testing.engine_with_changes);
    const metadata = try testing.manifestFor(a, current);
    var output: std.Io.Writer.Allocating = .init(a);
    try std.testing.expectEqual(@as(u8, 1), try report(a, metadata, current, engine, &output.writer));
    const text = output.written();
    try std.testing.expect(std.mem.indexOf(u8, text, "engine-only: 1") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "  audit_probe\n") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "vendored-only: 1") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "  mem_alloc (gate 4.7.2") != null);
}

test "invalid engine header evidence is rejected" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    try std.testing.expectError(
        error.InvalidInterfaceEvidence,
        interfaces.Names.parse(arena.allocator(), " * @name bad-name\n"),
    );
}

const std = @import("std");
const Allocator = std.mem.Allocator;

const Args = @import("common").Args;

const interfaces = @import("compat").interfaces;
const manifest = @import("compat").manifest;
