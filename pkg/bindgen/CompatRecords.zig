pub const Kind = enum {
    class,
    builtin,
};

pub const Argument = struct {
    type: []const u8,
    meta: []const u8,
    has_default: bool,
};

pub const Return = struct {
    type: []const u8,
    meta: []const u8,
};

pub const Record = struct {
    kind: Kind,
    owner: []const u8,
    method: []const u8,
    hash: u64,
    compatibility: []const u64,
    virtual: bool,
    is_const: bool,
    is_static: bool,
    is_vararg: bool,
    arguments: []const Argument,
    @"return": ?Return,
};

pub const EnumValue = struct {
    name: []const u8,
    value: i64,
};

pub const Enum = struct {
    name: []const u8,
    is_bitfield: bool,
    values: []const EnumValue,
};

pub const Snapshot = struct {
    version: []const u8,
    status: []const u8,
    build: []const u8,
    precision: []const u8,
    raw_sha256: []const u8,
    classes_sha256: []const u8,
    records: []const Record,
    enums: []const Enum,
};

/// Parse a canonical exact stable release, rejecting abbreviated and tagged forms.
pub fn exactVersion(text: []const u8) !std.SemanticVersion {
    const version = std.SemanticVersion.parse(text) catch return error.InvalidExactVersion;
    if (version.pre != null or version.build != null) return error.InvalidExactVersion;
    var buffer: [96]u8 = undefined;
    const canonical = std.fmt.bufPrint(
        &buffer,
        "{d}.{d}.{d}",
        .{ version.major, version.minor, version.patch },
    ) catch return error.InvalidExactVersion;
    if (!std.mem.eql(u8, text, canonical)) return error.InvalidExactVersion;
    return version;
}

/// Extract validated provenance and sorted original method and enum identities.
/// Returned allocations are owned by the caller's allocator; callers use an arena.
pub fn extract(allocator: Allocator, bytes: []const u8, version_text: []const u8) !Snapshot {
    // Validate the exact release and the raw dump's stable official header.
    const version = try exactVersion(version_text);
    const parsed = try std.json.parseFromSlice(
        GodotApi,
        allocator,
        bytes,
        .{ .ignore_unknown_fields = true },
    );
    const api = parsed.value;
    const header = api.header;
    if (header.version_major != version.major or header.version_minor != version.minor or
        header.version_patch != version.patch) return error.VersionHeaderMismatch;
    if (!std.mem.eql(u8, header.version_status, "stable") or
        !std.mem.eql(u8, header.version_build, "official")) return error.UnauditedBuild;
    const precision = header.precision orelse return error.MissingPrecision;
    if (!std.mem.eql(u8, precision, "single")) return error.UnsupportedPrecision;

    // Collect original identities and retain each signature and enum's raw values.
    var records: std.ArrayList(Record) = .empty;
    var enums: std.ArrayList(Enum) = .empty;
    for (api.global_enums) |item| {
        try appendEnum(allocator, &enums, item.name, item);
    }
    for (api.classes) |owner| {
        for (owner.methods orelse &.{}) |method| {
            try appendMethod(allocator, &records, .class, owner.name, method);
        }
        for (owner.enums orelse &.{}) |item| {
            const name = try std.fmt.allocPrint(allocator, "{s}.{s}", .{ owner.name, item.name });
            try appendEnum(allocator, &enums, name, item);
        }
    }
    for (api.builtin_classes) |owner| {
        for (owner.methods orelse &.{}) |method| {
            try appendMethod(allocator, &records, .builtin, owner.name, method);
        }
        for (owner.enums orelse &.{}) |item| {
            const name = try std.fmt.allocPrint(allocator, "{s}.{s}", .{ owner.name, item.name });
            try appendEnum(allocator, &enums, name, item);
        }
    }

    // Sort method identities and reject duplicate owner/method records.
    std.mem.sort(Record, records.items, {}, lessRecord);
    for (records.items, 0..) |record, i| {
        if (i > 0 and sameIdentity(records.items[i - 1], record)) return error.DuplicateIdentity;
    }

    // Sort fully qualified enum identities and reject duplicate names.
    std.mem.sort(Enum, enums.items, {}, lessEnum);
    for (enums.items, 0..) |item, i| {
        if (i > 0 and std.mem.eql(u8, enums.items[i - 1].name, item.name)) {
            return error.DuplicateEnum;
        }
    }

    // Record both raw and historical-normalized checksums in the extracted snapshot.
    return .{
        .version = version_text,
        .status = header.version_status,
        .build = header.version_build,
        .precision = precision,
        .raw_sha256 = try digest(allocator, bytes),
        .classes_sha256 = try digest(allocator, try normalizeHistorical(allocator, bytes)),
        .records = try records.toOwnedSlice(allocator),
        .enums = try enums.toOwnedSlice(allocator),
    };
}

fn appendMethod(
    allocator: Allocator,
    output: *std.ArrayList(Record),
    kind: Kind,
    owner: []const u8,
    method: anytype,
) !void {
    var arguments: std.ArrayList(Argument) = .empty;
    for (method.arguments orelse &.{}) |arg| {
        try arguments.append(allocator, .{
            .type = arg.type,
            .meta = if (@hasField(@TypeOf(arg), "meta")) arg.meta else "",
            .has_default = arg.default_value.len != 0,
        });
    }
    const result: ?Return = if (@hasField(@TypeOf(method), "return_value"))
        if (method.return_value) |value| .{ .type = value.type, .meta = value.meta } else null
    else if (std.mem.eql(u8, method.return_type, "void"))
        null
    else
        .{ .type = method.return_type, .meta = "" };
    try output.append(allocator, .{
        .kind = kind,
        .owner = owner,
        .method = method.name,
        .hash = method.hash,
        .compatibility = method.hash_compatibility orelse &.{},
        .virtual = if (@hasField(@TypeOf(method), "is_virtual")) method.is_virtual else false,
        .is_const = method.is_const,
        .is_static = method.is_static,
        .is_vararg = method.is_vararg,
        .arguments = try arguments.toOwnedSlice(allocator),
        .@"return" = result,
    });
}

fn appendEnum(allocator: Allocator, output: *std.ArrayList(Enum), name: []const u8, item: anytype) !void {
    const values = try allocator.alloc(EnumValue, item.values.len);
    for (values, item.values) |*value, original| {
        value.* = .{
            .name = original.name,
            .value = original.value,
        };
    }
    std.mem.sort(EnumValue, values, {}, lessEnumValue);
    for (values, 0..) |value, i| {
        if (i > 0 and std.mem.eql(u8, values[i - 1].name, value.name)) return error.DuplicateEnum;
    }
    try output.append(allocator, .{
        .name = name,
        .is_bitfield = if (@hasField(@TypeOf(item), "is_bitfield")) item.is_bitfield else false,
        .values = values,
    });
}

fn lessEnum(_: void, a: Enum, b: Enum) bool {
    return std.mem.lessThan(u8, a.name, b.name);
}

fn lessEnumValue(_: void, a: EnumValue, b: EnumValue) bool {
    return std.mem.lessThan(u8, a.name, b.name);
}

fn digest(allocator: Allocator, bytes: []const u8) ![]const u8 {
    var hash: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &hash, .{});
    return std.fmt.allocPrint(allocator, "{x}", .{hash});
}

/// Canonicalize only top-level class ordering; preserve all other JSON content.
pub fn normalizeHistorical(allocator: Allocator, bytes: []const u8) ![]const u8 {
    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, bytes, .{ .parse_numbers = false });
    defer parsed.deinit();
    if (parsed.value != .object) return error.InvalidClassIdentity;
    const classes = parsed.value.object.getPtr("classes") orelse return error.InvalidClassIdentity;
    if (classes.* != .array) return error.InvalidClassIdentity;
    for (classes.array.items) |class| {
        if (class != .object) return error.InvalidClassIdentity;
        const name = class.object.get("name") orelse return error.InvalidClassIdentity;
        if (name != .string or name.string.len == 0) return error.InvalidClassIdentity;
    }
    std.mem.sort(std.json.Value, classes.array.items, {}, lessClass);
    for (classes.array.items, 0..) |class, i| {
        if (i > 0 and std.mem.eql(
            u8,
            class.object.get("name").?.string,
            classes.array.items[i - 1].object.get("name").?.string,
        )) {
            return error.DuplicateClassIdentity;
        }
    }
    return std.json.Stringify.valueAlloc(allocator, parsed.value, .{});
}

fn lessClass(_: void, a: std.json.Value, b: std.json.Value) bool {
    return std.mem.lessThan(u8, a.object.get("name").?.string, b.object.get("name").?.string);
}

/// Compare original identities in kind/owner/method order.
pub fn lessRecord(_: void, a: Record, b: Record) bool {
    if (a.kind != b.kind) return @backingInt(a.kind) < @backingInt(b.kind);
    const owner = std.mem.order(u8, a.owner, b.owner);
    if (owner != .eq) return owner == .lt;
    return std.mem.lessThan(u8, a.method, b.method);
}

/// Return whether two records refer to the same original method identity.
pub fn sameIdentity(a: Record, b: Record) bool {
    return a.kind == b.kind and std.mem.eql(u8, a.owner, b.owner) and std.mem.eql(u8, a.method, b.method);
}

const fixture =
    \\{"header":{"version_major":4,"version_minor":6,"version_patch":3,"version_status":"stable","version_build":"official","version_full_name":"fixture","precision":"single"},
    \\"builtin_class_sizes":[],"builtin_class_member_offsets":[],"global_constants":[],"global_enums":[{"name":"Error","is_bitfield":false,"values":[{"name":"Z","value":2},{"name":"A","value":1}]}],
    \\"utility_functions":[],"builtin_classes":[],"classes":[{"name":"Owner","is_refcounted":false,"is_instantiable":true,"api_type":"core","enums":[{"name":"Mode","is_bitfield":false,"values":[{"name":"ON","value":1}]}],
    \\"methods":[{"name":"method","is_const":true,"is_static":false,"is_vararg":false,"is_virtual":false,"hash":101,"arguments":[{"name":"arg","type":"enum::Owner.Mode","meta":"int32","default_value":"0"}],"return_value":{"type":"bool","meta":""}}]}],"singletons":[],"native_structures":[]}
;

test "extract validates header and retains signatures and sorted qualified enums" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const snapshot = try extract(a, fixture, "4.6.3");
    try std.testing.expectEqualStrings("Error", snapshot.enums[0].name);
    try std.testing.expectEqualStrings("Owner.Mode", snapshot.enums[1].name);
    try std.testing.expectEqualStrings("A", snapshot.enums[0].values[0].name);
    try std.testing.expectEqualStrings("enum::Owner.Mode", snapshot.records[0].arguments[0].type);
    try std.testing.expect(snapshot.records[0].arguments[0].has_default);
    try std.testing.expectEqualStrings("int32", snapshot.records[0].arguments[0].meta);
    try std.testing.expectEqualStrings("bool", snapshot.records[0].@"return".?.type);
    try std.testing.expect(snapshot.records[0].is_const);
    try std.testing.expectEqual(@as(usize, 64), snapshot.raw_sha256.len);
    try std.testing.expectEqual(@as(usize, 64), snapshot.classes_sha256.len);
    try std.testing.expectError(error.VersionHeaderMismatch, extract(a, fixture, "4.6.2"));
}

test "extract rejects unstable builds and duplicate method and enum identities" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const parsed = try std.json.parseFromSlice(std.json.Value, a, fixture, .{});
    const header = parsed.value.object.getPtr("header").?;
    header.object.getPtr("version_status").?.* = .{ .string = "beta" };
    const unstable = try std.json.Stringify.valueAlloc(a, parsed.value, .{});
    try std.testing.expectError(error.UnauditedBuild, extract(a, unstable, "4.6.3"));
    header.object.getPtr("version_status").?.* = .{ .string = "stable" };
    const enums = parsed.value.object.getPtr("global_enums").?;
    try enums.array.append(enums.array.items[0]);
    const duplicate = try std.json.Stringify.valueAlloc(a, parsed.value, .{});
    try std.testing.expectError(error.DuplicateEnum, extract(a, duplicate, "4.6.3"));
    _ = enums.array.pop();
    const methods = parsed.value.object.getPtr("classes").?.array.items[0].object.getPtr("methods").?;
    try methods.array.append(methods.array.items[0]);
    const duplicate_method = try std.json.Stringify.valueAlloc(a, parsed.value, .{});
    try std.testing.expectError(error.DuplicateIdentity, extract(a, duplicate_method, "4.6.3"));
}

test "extract sorts owners and methods without changing signatures" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const first = try std.json.parseFromSlice(std.json.Value, a, fixture, .{});
    const second = try std.json.parseFromSlice(std.json.Value, a, fixture, .{});
    const classes = first.value.object.getPtr("classes").?;
    const z = classes.array.items[0];
    const alpha = second.value.object.getPtr("classes").?.array.items[0];
    z.object.getPtr("name").?.* = .{ .string = "Z" };
    alpha.object.getPtr("name").?.* = .{ .string = "A" };
    const methods = z.object.getPtr("methods").?;
    methods.array.items[0].object.getPtr("name").?.* = .{ .string = "z" };
    const another = alpha.object.getPtr("methods").?.array.items[0];
    another.object.getPtr("name").?.* = .{ .string = "a" };
    try methods.array.append(another);
    try classes.array.append(alpha);
    const result = try extract(a, try std.json.Stringify.valueAlloc(a, first.value, .{}), "4.6.3");
    try std.testing.expectEqual(@as(usize, 3), result.records.len);
    try std.testing.expectEqualStrings("A", result.records[0].owner);
    try std.testing.expectEqualStrings("a", result.records[1].method);
    try std.testing.expectEqualStrings("z", result.records[2].method);
    for (result.records) |record| {
        try std.testing.expect(record.is_const);
        try std.testing.expect(record.arguments[0].has_default);
        try std.testing.expectEqualStrings("bool", record.@"return".?.type);
    }
}

test "historical normalization ignores only class order and preserves nested content" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const first = "{\"classes\":[{\"name\":\"Z\",\"methods\":[{\"name\":\"m\",\"hash\":1,\"arguments\":[{\"default_value\":\"0\"}]}]},{\"name\":\"A\"}],\"future\":1}";
    const reordered = "{\"classes\":[{\"name\":\"A\"},{\"name\":\"Z\",\"methods\":[{\"name\":\"m\",\"hash\":1,\"arguments\":[{\"default_value\":\"0\"}]}]}],\"future\":1}";
    const expected = try normalizeHistorical(a, first);
    try std.testing.expectEqualStrings(expected, try normalizeHistorical(a, reordered));
    const parsed = try std.json.parseFromSlice(std.json.Value, a, first, .{});
    const method = parsed.value.object.getPtr("classes").?.array.items[0].object.getPtr("methods").?.array.items[0];
    method.object.getPtr("name").?.* = .{ .string = "changed" };
    try std.testing.expect(!std.mem.eql(u8, expected, try normalizeHistorical(a, try std.json.Stringify.valueAlloc(a, parsed.value, .{}))));
    method.object.getPtr("name").?.* = .{ .string = "m" };
    method.object.getPtr("hash").?.* = .{ .integer = 2 };
    try std.testing.expect(!std.mem.eql(u8, expected, try normalizeHistorical(a, try std.json.Stringify.valueAlloc(a, parsed.value, .{}))));
    method.object.getPtr("hash").?.* = .{ .integer = 1 };
    method.object.getPtr("arguments").?.array.items[0].object.getPtr("default_value").?.* = .{ .string = "1" };
    try std.testing.expect(!std.mem.eql(u8, expected, try normalizeHistorical(a, try std.json.Stringify.valueAlloc(a, parsed.value, .{}))));
    method.object.getPtr("arguments").?.array.items[0].object.getPtr("default_value").?.* = .{ .string = "0" };
    parsed.value.object.getPtr("future").?.* = .{ .integer = 2 };
    try std.testing.expect(!std.mem.eql(u8, expected, try normalizeHistorical(a, try std.json.Stringify.valueAlloc(a, parsed.value, .{}))));
    try std.testing.expectError(error.DuplicateClassIdentity, normalizeHistorical(a, "{\"classes\":[{\"name\":\"A\"},{\"name\":\"A\"}]}"));
}

const std = @import("std");
const Allocator = std.mem.Allocator;

const GodotApi = @import("GodotApi.zig");
