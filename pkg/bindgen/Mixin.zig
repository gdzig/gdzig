const Mixin = @This();

/// Owns the source and AST. Declaration names borrow source until deinit.
source: [:0]u8,
ast: Ast,
declarations: std.ArrayList(Declaration) = .empty,
/// All root declaration names, including private helpers, for collision checks.
names: std.ArrayList([]const u8) = .empty,

pub const Declaration = struct {
    kind: enum { function, constant },
    name: []const u8,
    node: Ast.Node.Index,
};

pub fn load(allocator: Allocator, io: std.Io, dir: std.Io.Dir, path: []const u8) !?Mixin {
    const file = dir.openFile(io, path, .{}) catch |err| {
        if (err == error.FileNotFound) return null;
        return err;
    };
    defer file.close(io);
    var buffer: [4096]u8 = undefined;
    var reader = file.readerStreaming(io, &buffer);
    const contents = try reader.interface.allocRemaining(allocator, .unlimited);
    defer allocator.free(contents);
    return try parse(allocator, contents);
}

pub fn parse(allocator: Allocator, contents: []const u8) !Mixin {
    const contents_slice = util.mixinContents(contents);
    const source = try allocator.allocSentinel(u8, contents_slice.len, 0);
    @memcpy(source, contents_slice);
    errdefer allocator.free(source);
    var ast: Ast = try .parse(allocator, source, .{});
    errdefer ast.deinit(allocator);
    if (ast.errors.len != 0) return error.ParseError;
    var declarations: std.ArrayList(Declaration) = .empty;
    errdefer declarations.deinit(allocator);
    var names: std.ArrayList([]const u8) = .empty;
    errdefer names.deinit(allocator);
    for (ast.rootDecls()) |index| {
        var buffer: [1]Ast.Node.Index = undefined;
        if (ast.fullFnProto(&buffer, index)) |proto| {
            const name_token = proto.name_token orelse continue;
            try names.append(allocator, ast.tokenSlice(name_token));
            if (proto.visib_token == null) continue;
            try declarations.append(allocator, .{ .kind = .function, .name = ast.tokenSlice(name_token), .node = index });
        } else if (ast.fullVarDecl(index)) |decl| {
            try names.append(allocator, ast.tokenSlice(decl.ast.mut_token + 1));
            if (decl.visib_token == null) continue;
            if (ast.tokens.get(decl.ast.mut_token).tag != .keyword_const) continue;
            try declarations.append(allocator, .{ .kind = .constant, .name = ast.tokenSlice(decl.ast.mut_token + 1), .node = index });
        }
    }
    return .{ .source = source, .ast = ast, .declarations = declarations, .names = names };
}

pub fn deinit(self: *Mixin, allocator: Allocator) void {
    self.declarations.deinit(allocator);
    self.names.deinit(allocator);
    self.ast.deinit(allocator);
    allocator.free(self.source);
    self.* = undefined;
}
test "only each declaration's own public fn and const participate" {
    var mixin: Mixin = try .parse(std.testing.allocator,
        \\const outside = 0;
        \\// @mixin start
        \\pub fn replace(self: *Self) void { _ = self; }
        \\fn privateAfterPublic(self: *Self) void { _ = self; }
        \\pub const alias = replace;
        \\const privateAlias = replace;
        \\pub var mutable = 0;
        \\pub const UnrelatedOptions = struct {};
        \\// @mixin stop
        \\pub fn outsideAfter() void {}
    );
    defer mixin.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 3), mixin.declarations.items.len);
    try std.testing.expectEqualStrings("replace", mixin.declarations.items[0].name);
    try std.testing.expectEqualStrings("alias", mixin.declarations.items[1].name);
    try std.testing.expectEqualStrings("UnrelatedOptions", mixin.declarations.items[2].name);
    var found_private = false;
    for (mixin.names.items) |name| {
        if (std.mem.eql(u8, name, "privateAfterPublic")) found_private = true;
    }
    try std.testing.expect(found_private);
}

test "declaration names remain valid after input source is freed" {
    const source = try std.testing.allocator.dupe(u8, "pub const methodAlias = helper;");
    var mixin: Mixin = try .parse(std.testing.allocator, source);
    std.testing.allocator.free(source);
    defer mixin.deinit(std.testing.allocator);
    try std.testing.expectEqualStrings("methodAlias", mixin.declarations.items[0].name);
}

test "class fn and const overrides preserve metadata and private or unmatched names" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var class: Context.Class = .{};
    for ([_][]const u8{ "replace", "alias", "privateAfterPublic", "untouched", "alreadySkipped" }) |name| {
        var function: Context.Function = .{ .name = name, .name_api = name, .hash = 123, .base = "Parent", .skip = std.mem.eql(u8, name, "alreadySkipped") };
        try function.hash_compatibility.append(allocator, 456);
        try class.functions.put(allocator, name, function);
    }
    var mixin: Mixin = try .parse(std.testing.allocator,
        \\pub fn replace(self: *Self) void { _ = self; }
        \\pub const alias = implementation;
        \\fn privateAfterPublic(self: *Self) void { _ = self; }
        \\pub fn newHelper() void {}
    );
    defer mixin.deinit(std.testing.allocator);
    class.applyMixin(&mixin);
    try std.testing.expect(class.functions.get("replace").?.skip);
    try std.testing.expect(class.functions.get("alias").?.skip);
    try std.testing.expect(!class.functions.get("privateAfterPublic").?.skip);
    try std.testing.expect(!class.functions.get("untouched").?.skip);
    try std.testing.expect(class.functions.get("alreadySkipped").?.skip);
    try std.testing.expectEqual(@as(usize, 5), class.functions.count());
    const function = class.functions.get("alias").?;
    try std.testing.expectEqualStrings("alias", function.name);
    try std.testing.expectEqualStrings("Parent", function.base.?);
    try std.testing.expectEqual(@as(?u64, 123), function.hash);
    try std.testing.expectEqual(@as(u64, 456), function.hash_compatibility.items[0]);
}

test "builtin constructors comptime markers and const aliases survive scanner ownership" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var builtin: Context.Builtin = .{};
    try builtin.constructors.put(allocator, "init", .{ .name = "init" });
    var mixin: Mixin = try .parse(std.testing.allocator,
        \\/// @comptime
        \\pub fn initValue(value: u32) Self { _ = value; return undefined; }
        \\pub const init = initValue;
        \\pub const sentinel = 7;
        \\fn privateAfterPublic(value: u32) Self { _ = value; return undefined; }
        \\const privateConstant = 9;
    );
    try builtin.applyMixin(allocator, &mixin);
    mixin.deinit(std.testing.allocator);
    try std.testing.expect(builtin.constructors.get("init").?.skip);
    try std.testing.expect(builtin.constructors.get("initValue").?.can_init_directly);
    try std.testing.expectEqualStrings("initValue", builtin.constructors.get("initValue").?.name);
    try std.testing.expectEqualStrings("sentinel", builtin.constants.get("SENTINEL").?.name);
    try std.testing.expect(!builtin.constructors.contains("privateAfterPublic"));
    try std.testing.expect(!builtin.constants.contains("PRIVATE_CONSTANT"));
}

test "class inheritance retains skipped API metadata" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    var api_classes = [_]GodotApi.Class{.{ .name = "Parent", .is_refcounted = false, .is_instantiable = true, .api_type = null }};
    var ctx: Context = .{
        .arena = &arena,
        .api = .{ .header = undefined, .builtin_class_sizes = &.{}, .builtin_class_member_offsets = &.{}, .global_constants = &.{}, .global_enums = &.{}, .utility_functions = &.{}, .builtin_classes = &.{}, .classes = &api_classes, .singletons = &.{}, .native_structures = &.{} },
        .config = .{ .arch = .float, .precision = .@"64", .extension_api = undefined, .gdextension_interface = undefined, .input = tmp.dir, .output = tmp.dir, .verbosity = .quiet, .io = std.testing.io },
    };
    var parent: Context.Class = .{ .name = "Parent", .name_api = "Parent" };
    var function: Context.Function = .{ .name = "isClass", .name_api = "is_class", .base = "Parent", .hash = 123, .self = .{ .constant = "Parent" }, .skip = true, .mixin_override = true };
    try function.hash_compatibility.append(allocator, 456);
    try parent.functions.put(allocator, "is_class", function);
    try parent.mixin_names.put(allocator, "privateHelper", {});
    try ctx.classes.put(allocator, "Parent", parent);
    const child = try Context.Class.fromApi(allocator, .{ .name = "Child", .inherits = "Parent", .is_refcounted = false, .is_instantiable = true, .api_type = null }, &ctx);
    const inherited = child.functions.get("is_class").?;
    try std.testing.expect(inherited.skip);
    try std.testing.expect(inherited.mixin_override);
    try std.testing.expect(child.mixin_names.contains("privateHelper"));
    try std.testing.expectEqualStrings("Child", inherited.self.constant);
    try std.testing.expectEqualStrings("Parent", inherited.base.?);
    try std.testing.expectEqual(@as(?u64, 123), inherited.hash);
    try std.testing.expectEqual(@as(u64, 456), inherited.hash_compatibility.items[0]);
}

test "constant mixin allocation failures release owned names" {
    var mixin: Mixin = try .parse(std.testing.allocator, "pub const sentinel = 7;");
    defer mixin.deinit(std.testing.allocator);
    var probe: std.testing.FailingAllocator = .init(std.testing.allocator, .{});
    const constant = (try Context.Constant.fromMixin(probe.allocator(), mixin.ast, mixin.declarations.items[0].node)).?;
    probe.allocator().free(constant.name);
    probe.allocator().free(constant.name_api);
    // Exercise the final name copy, not casez's separate writer OOM behavior.
    var failing: std.testing.FailingAllocator = .init(std.testing.allocator, .{ .fail_index = probe.allocations - 1 });
    try std.testing.expectError(error.OutOfMemory, Context.Constant.fromMixin(failing.allocator(), mixin.ast, mixin.declarations.items[0].node));
    try std.testing.expectEqual(failing.allocated_bytes, failing.freed_bytes);
}

const std = @import("std");
const Allocator = std.mem.Allocator;
const Ast = std.zig.Ast;

const Context = @import("Context.zig");
const GodotApi = @import("GodotApi.zig");
const util = @import("util.zig");
