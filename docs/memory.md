# Memory

gdzig bridges two memory models: Zig's explicit allocator-passing style and Godot's internal memory management. Understanding how they interact will help you avoid leaks and crashes.

## Allocators

Godot provides its own allocator through the GDExtension API. gdzig wraps this as `gdzig.engine_allocator`, which implements the standard `std.mem.Allocator` interface. You can use it anywhere you'd use a Zig allocator.

The recommended setup is `std.heap.DebugAllocator` with `engine_allocator` as the backing allocator. This catches leaks and use-after-free in your Zig code, while still routing through Godot so its profiler can track total memory usage.

## Godot Types

Godot has two main kinds of types:

- **Builtins**: Value types with known layout - either stack-allocated structs or reference-counted types on the heap.
- **Classes**: Heap-allocated objects accessed by pointer. Engine classes are opaque; your extension classes are not.

Each category has different memory management rules, covered in the sections below.

## Builtin Types

Builtins fall into two categories:

**Value types** like `Vector2`, `Vector3`, `Color`, `Rect2`, etc. are plain structs. They live on the stack, copy by value, and need no cleanup.

**Reference-counted value types** like `String`, `Array`, `Dictionary`, `Callable`, and `Signal` use copy-on-write semantics. When you assign or pass them, they share the underlying buffer until one copy is modified. From your perspective, they behave like copies - you can use them independently. Call `deinit()` when done to release your reference:

```zig
var arr = Array.init();
defer arr.deinit();
```

### Variant

`Variant` is a builtin that acts as Godot's dynamic type container, used extensively in the scripting API. It can hold:

- Primitives: `nil`, `bool`, `int`, `float`
- Math types: `Vector2`, `Vector2i`, `Vector3`, `Vector3i`, `Vector4`, `Vector4i`, `Rect2`, `Rect2i`, `Plane`, `Quaternion`, `Color`
- Transforms: `Transform2d`, `Transform3d`, `Basis`, `Projection`, `Aabb`
- Strings: `String`, `StringName`, `NodePath`
- Collections: `Array`, `Dictionary`
- Packed arrays: `PackedByteArray`, `PackedInt32Array`, `PackedInt64Array`, `PackedFloat32Array`, `PackedFloat64Array`, `PackedStringArray`, `PackedVector2Array`, `PackedVector3Array`, `PackedVector4Array`, `PackedColorArray`
- References: `Rid`, `Object`, `Callable`, `Signal`

Most types wrap into `Variant` cheaply. However, five types allocate from Godot's pool allocators when wrapped:

- `Transform2d`
- `Aabb`
- `Basis`
- `Transform3d`
- `Projection`

#### Always deinit `Variant`s

When you receive a `Variant` (from `Object.call()`, for example), you **must** call `deinit()` when done:

```zig
var result = object.call(method, .{arg1, arg2});
defer result.deinit();
// use result...
```

## Classes

Beyond value types and Variants, Godot has **classes** - heap-allocated objects accessed by pointer. All classes inherit from `Object`, with some inheriting from `RefCounted` (itself an `Object` subclass).

**RefCounted** classes (and their descendants like `Resource`) use reference counting. You must manage this manually:

```zig
// When acquiring a reference
_ = obj.reference();

// When releasing
if (obj.unreference()) obj.destroy();
```

**Non-RefCounted** classes (like `Node`) require manual destruction. Prefer `node.queueFree()` which defers destruction until safe. Use `node.destroy()` only when immediate destruction is required (e.g., in your extension class's destroy callback).

### Extension Classes

When you define your own extension class, there are two allocations necessary:

1. **Engine class**: Allocated via Godot's allocator, holds the native Object data
2. **Extension class**: Allocated via your allocator, holds your Zig struct

Treat your extension class as owning the engine class. Create the engine class in your constructor (via `Base.init()`), link them (via `base.setInstance(self)`), and destroy it in your destructor (via `base.destroy()`). gdzig handles the coordination between the two allocators.

```zig
const Player = struct {
    base: *Node2D,

    pub fn create(allocator: *std.mem.Allocator) !*Player {
        const self = try allocator.create(Player);
        self.* = .{ .base = .init() };
        self.base.setInstance(self);
        return self;
    }

    pub fn destroy(self: *Player, allocator: *Allocator) void {
        self.base.destroy();
        allocator.destroy(self);
    }
};
```

Note that `Object.init()` is non-fallible (it will panic on failure), so no `errdefer` cleanup of `self` is necessary.

## Method Calls

gdzig generates two styles of methods for Godot's types:

- **Fixed-arity methods** have a known number of arguments. These pass arguments directly by pointer with no Variant boxing - the fast path with no allocations.

- **Vararg methods** like `Object.call()` accept any number of arguments by boxing them into Variants. The return value is always a `Variant` that you must `deinit()`.

For vararg functions, gdzig provides two versions:

- **Non-allocating** (`call`, `emit`, etc.): Compile error if you pass `Transform2d`, `Aabb`, `Basis`, `Transform3d`, or `Projection`. These would allocate when boxed into Variant, so they are not allowed.
- **Allocating** (`callAlloc`, `emitAlloc`, etc.): Accepts those types, boxing them in a Variant internally.

The non-allocating versions protect you from accidental leaks. If you need to pass one of those types, use the allocating version or wrap the value in a `Variant` and manage its lifetime yourself.

## Common Gotchas

**Leaking Variants**: Any `Variant` returned from a vararg call must be `deinit()`ed. The compiler can't catch this.

**Pool-allocating types in varargs**: Using `Transform3d` etc. in `call()` or `emit()` is a compile error by design. Use the Alloc variants.

**Storing RefCounted references**: Storing raw pointers to RefCounted objects won't prevent collection - you must call `reference()` to prevent the object from being freed.
