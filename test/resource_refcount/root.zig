pub fn register(r: *gdzig.extension.Registry) void {
    _ = r.createClass(MyMetadata, {}, .auto);
}

fn ensureRegistered() void {
    const S = struct {
        var done: bool = false;
    };
    if (!S.done) {
        S.done = true;
        gdzig.testing.loadModule(@This());
    }
}

test "engine-instantiated Resource subclass starts with one reference and releases array refs" {
    if (!gdzig.version.gte(.@"4.7")) return error.SkipZigTest;

    ensureRegistered();

    var custom_variant = ClassDb.instantiate(.fromType(MyMetadata));
    defer custom_variant.deinit();

    const custom = custom_variant.as(*MyMetadata) orelse return error.CustomResourceCastFailed;
    const custom_resource = Resource.upcast(custom);
    try expectSingleRefAndArrayRoundTrip(custom_resource);

    var builtin_variant = ClassDb.instantiate(.fromComptimeLatin1("Resource"));
    defer builtin_variant.deinit();

    const builtin_resource = builtin_variant.as(*Resource) orelse return error.BuiltinResourceCastFailed;
    try testing.expectEqual(@as(i32, 1), builtin_resource.getReferenceCount());
}

test "loaded Resource subclass starts with one reference and releases array refs" {
    if (!gdzig.version.gte(.@"4.7")) return error.SkipZigTest;

    ensureRegistered();

    var path = String.fromLatin1("user://gdzig_resource_refcount_test.tres");
    defer path.deinit();

    const file = FileAccess.open(path, .write) orelse return error.OpenResourceFileFailed;
    defer destroyRefCountedIfUnreferenced(file);

    var contents = String.fromLatin1(
        \\[gd_resource type="MyMetadata" format=3]
        \\
        \\[resource]
        \\
    );
    defer contents.deinit();
    try testing.expect(file.storeString(contents));
    file.close();

    const loaded = ResourceLoader.load(path, .{ .cache_mode = .cache_mode_ignore }) orelse return error.LoadedResourceMissing;
    defer destroyRefCountedIfUnreferenced(loaded);

    try expectSingleRefAndArrayRoundTrip(loaded);
}

fn expectSingleRefAndArrayRoundTrip(resource: *Resource) !void {
    try testing.expectEqual(@as(i32, 1), resource.getReferenceCount());

    var array: Array = .init();
    defer array.deinit();

    const boxed = Variant.init(*Resource, resource);
    array.append(boxed);
    boxed.deinit();
    try testing.expectEqual(@as(i32, 2), resource.getReferenceCount());

    array.clear();
    try testing.expectEqual(@as(i32, 1), resource.getReferenceCount());
}

const MyMetadata = struct {
    base: *Resource,

    pub fn create() !*MyMetadata {
        const self: *MyMetadata = allocator.create(MyMetadata) catch @panic("out of memory");
        self.* = .{ .base = Resource.init() };
        self.base.setInstance(MyMetadata, self);
        return self;
    }

    pub fn destroy(self: *MyMetadata) void {
        allocator.destroy(self);
    }
};

fn destroyRefCountedIfUnreferenced(object: anytype) void {
    if (object.unreference()) object.destroy();
}

const std = @import("std");
const testing = std.testing;

const gdzig = @import("gdzig");
const allocator = gdzig.testing.allocator;
const Array = gdzig.builtin.Array;
const ClassDb = gdzig.class.ClassDb;
const FileAccess = gdzig.class.FileAccess;
const Resource = gdzig.class.Resource;
const ResourceLoader = gdzig.class.ResourceLoader;
const String = gdzig.builtin.String;
const Variant = gdzig.builtin.Variant;
