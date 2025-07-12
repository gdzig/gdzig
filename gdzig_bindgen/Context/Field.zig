const Field = @This();

doc: ?[]const u8 = null,
name: []const u8 = "_",
name_api: []const u8 = "_",
type: Type = .void,
offset: ?usize = null,

pub fn init(allocator: Allocator, doc: ?[]const u8, name: []const u8, @"type": []const u8, meta: ?[]const u8, offset: ?usize, ctx: *const Context) !Field {
    var self: Field = .{};
    errdefer self.deinit(allocator);

    var field_type = meta orelse @"type";
    if (std.mem.eql(u8, field_type, "float") or std.mem.eql(u8, field_type, "real")) {
        field_type = "f32";
    }

    self.doc = if (doc) |d| try docs.convertDocsToMarkdown(allocator, d, ctx, .{}) else null;
    self.name = try allocator.dupe(u8, name);
    self.name_api = try allocator.dupe(u8, name);
    self.type = try Type.from(allocator, field_type, meta != null, ctx);
    self.offset = offset;

    return self;
}

pub fn deinit(self: *Field, allocator: Allocator) void {
    if (self.doc) |doc| allocator.free(doc);
    allocator.free(self.name);
    self.type.deinit(allocator);

    self.* = .{};
}

const std = @import("std");
const Allocator = std.mem.Allocator;

const Context = @import("../Context.zig");
const Type = Context.Type;
const docs = @import("docs.zig");
