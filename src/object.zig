/// Create a Godot object.
pub fn create(comptime T: type) !*T {
    // TODO: I don't think this class can handle nested user types (MyType { base: Node } and MyTypeSubtype { base: MyType })
    debug.assertIsObject(T);

    const class_name = meta.getNamePtr(T);
    const base_name = meta.getNamePtr(meta.BaseOf(T));

    // TODO: shouldn't we use Godot's allocator? can this be done without a double allocation?
    const ptr = core.classdbConstructObject2(@ptrCast(base_name)).?;
    const self = try godot.general_allocator.create(T);

    // Store the pointer on base type
    if (T == core.Object) {
        self.ptr = ptr;
    } else {
        self.base = @bitCast(core.Object{ .ptr = ptr });
    }

    core.objectSetInstance(ptr, @ptrCast(class_name), @ptrCast(self));
    core.objectSetInstanceBinding(ptr, core.p_library, @ptrCast(self), @ptrCast(&godot.dummy_callbacks));

    // TODO: doesn't Godot call `_init`? shouldn't we let `init` call `heap.create()`?
    //       Proper hierarchy of control is not clear here
    if (@hasDecl(T, "init")) {
        self.init();
    }

    return self;
}

/// Recreate a Godot object.
pub fn recreate(comptime T: type, ptr: ?*anyopaque) !*T {
    debug.assertIsObject(T);
    _ = ptr;
    @panic("Extension reloading is not currently supported");
}

/// Destroy a Godot object.
pub fn destroy(instance: anytype) void {
    debug.assertIsObject(@TypeOf(instance));

    const ptr = meta.asObjectPtr(instance);
    core.objectFreeInstanceBinding(ptr, core.p_library);
    core.objectDestroy(ptr);
}

/// Unreference a Godot object.
pub fn unreference(instance: anytype) void {
    if (meta.asRefCounted(instance).unreference()) {
        core.objectDestroy(meta.asObjectPtr(instance));
    }
}

const godot = @import("root.zig");
const core = godot.core;
const debug = godot.debug;
const meta = godot.meta;
const Object = core.Object;
