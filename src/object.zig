/// Create a Godot object.
pub fn create(comptime T: type) !*T {
    // TODO: I don't think this class can handle nested user types (MyType { base: Node } and MyTypeSubtype { base: MyType })
    debug.assertIsObject(T);

    const class_name = meta.getNamePtr(T);
    const base_name = meta.getNamePtr(meta.BaseOf(T));

    // TODO: shouldn't we use Godot's allocator? can this be done without a double allocation?
    const ptr = godot.interface.classdbConstructObject2(@ptrCast(base_name)).?;
    const self = try godot.heap.general_allocator.create(T);

    // Store the pointer on base type
    if (T == godot.class.Object) {
        self.ptr = ptr;
    } else {
        self.base = @bitCast(godot.class.Object{ .ptr = ptr });
    }

    godot.interface.objectSetInstance(ptr, @ptrCast(class_name), @ptrCast(self));
    godot.interface.objectSetInstanceBinding(ptr, godot.interface.library, @ptrCast(self), @ptrCast(&godot.dummy_callbacks));

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
    godot.interface.objectFreeInstanceBinding(ptr, godot.interface.library);
    godot.interface.objectDestroy(ptr);
}

/// Unreference a Godot object.
pub fn unreference(instance: anytype) void {
    if (meta.asRefCounted(instance).unreference()) {
        godot.interface.objectDestroy(meta.asObjectPtr(instance));
    }
}

const godot = @import("gdzig.zig");
const debug = godot.debug;
const meta = godot.meta;
const Object = godot.class.Object;
