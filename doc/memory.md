# Memory

gdzig bridges two memory models: Zig's explicit allocator-passing style and Godot's internal memory management. Understanding how they interact will help you avoid leaks and crashes.

## Allocators

Godot provides its own allocator through the GDExtension API. gdzig wraps this as `gdzig.engine_allocator`, which implements the standard `std.mem.Allocator` interface. You can use it anywhere you'd use a Zig allocator.

The recommended setup is `std.heap.DebugAllocator` with `engine_allocator` as the backing allocator. This catches leaks and use-after-free in your Zig code, while still routing through Godot so its profiler can track total memory usage.

### Limitations

- Godot's allocator API does not support resizing existing allocations, so neither does `gdzig.engine_allocator`. 
- Godot's allocator API does not support alignment, so `gdzig.engine_allocator` has to add padding to aligned allocations. We store a 4 byte header in the padding to retrieve the original pointer offset.

## Godot Types

Godot has two main kinds of types:

- **Builtins**: Value types with known layout - either stack-allocated structs or reference-counted types on the heap.
- **Variant**: A special kind of builtin that can represent any builtin or class.
- **Classes**: Heap-allocated objects accessed by pointer. Engine classes are opaque; your extension classes are not.

Each category has different memory management rules, covered in the sections below.

## Builtin Types

Builtins fall into two categories:

**Value types** like `Vector2`, `Vector3`, `Color`, `Rect2`, etc. are plain structs. They live on the stack, copy by value, and need no cleanup.

**Copy-on-write types** like `String`, `Array`, or `Dictionary`. When you assign or pass them, they share the underlying buffer until one copy is modified. From your perspective, they behave like copies - you can use them independently. Call `deinit()` when done to release your reference:

```zig
var arr = Array.init();
defer arr.deinit();
```

### String

Godot `String`s are stored in UTF-32, are reference counted, and are copy-on-write: if one reference is held, it can be modified in place. If more than one is held, modifications create a new copy.

### StringName

`StringName` is a deduplicated (interned), reference counted, UTF-32 string. Initializing a `StringName` the first time will allocate, and any additional initializations of the same string will just increment the reference count.

Godot has a feature to create a `StringName` from data with a static lifetime (will exist for the entire lifetime of the application). gdzig offers a convenience function `StringName.fromComptimeLatin1` that takes a comptime string parameter. This guarantees the string literal lives in static memory, and also caches the resulting `StringName` in a static variable. The first call allocates Godot's internal `_Data` struct; subsequent calls return the cached value without even calling into Godot.

## Variant

`Variant` is a special builtin that acts as Godot's dynamic type container, used extensively in the scripting API. It can hold:

- Primitives: `nil`, `bool`, `int`, `float`
- Math types: `Vector2`, `Vector2i`, `Vector3`, `Vector3i`, `Vector4`, `Vector4i`, `Rect2`, `Rect2i`, `Plane`, `Quaternion`, `Color`
- Transforms: `Transform2d`, `Transform3d`, `Basis`, `Projection`, `Aabb`
- Strings: `String`, `StringName`, `NodePath`
- Collections: `Array`, `Dictionary`
- Packed arrays: `PackedByteArray`, `PackedInt32Array`, `PackedInt64Array`, `PackedFloat32Array`, `PackedFloat64Array`, `PackedStringArray`, `PackedVector2Array`, `PackedVector3Array`, `PackedVector4Array`, `PackedColorArray`
- References: `Rid`, `Object`, `Callable`, `Signal`

`Variant` is a stack data structure, but it can hold pointers into the heap.

Most types can be boxed into a `Variant` cheaply, with some exceptions:

- `Aabb`, `Basis`, `Projection`, `Transform2d`, and `Transform3d` are too large to fit inline in the Variant's data union, so they're stored as pointers. When created with `Variant.init`, Godot allocates space for them from a memory pool. When created with `Variant.wrap`, the pointer references your stack data directly.
- Packed array types will allocate directly from the heap when created with `Variant.init`, and cannot be created with `Variant.wrap`.
- All other types are copied on creation for both `Variant.init` and `Variant.wrap`.

`Variant.wrap` is an advanced utility for passing stack pointers into Godot without having to allocate memory on the heap. Calling `deinit()` on a `Variant` created with `wrap` is illegal behavior.

#### Always deinit `Variant`s

When you receive a `Variant` (from `Object.call()`, for example), you **must** call `deinit()` when done:

```zig
var result = object.call(method, .{arg1, arg2});
defer result.deinit();
// use result...
```

## Classes

Beyond value types and `Variant`s, Godot has **classes** - heap-allocated objects accessed by pointer. All classes inherit from `Object`, with some inheriting from `RefCounted` (itself an `Object` subclass).

**RefCounted** classes (and their descendants like `Resource`) use reference counting. You must manage this manually:

```zig
// When acquiring a reference
_ = obj.reference();

// When releasing
if (obj.unreference()) obj.destroy();
```

In gdzig, when you box a `RefCounted` object pointer into a `Variant`, ownership is not taken. Instead, the reference count is incremented. This is different than Godot's internal behavior; but we determined it was a significant source of confusion worth correcting. If you'd like to pass ownership of a `RefCounted` type to a `Variant` in gdzig, just call `obj.unreference()` after initializing the Variant:

```zig
const obj = RefCounted.init();
defer _ = obj.unreference();
return Variant.init(obj);
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

Note that `Object.init()` is will panic on failure, so no `errdefer` cleanup of `self` is necessary.

## Method Calls

gdzig generates two styles of methods for Godot's types:

- **Fixed-arity methods** have a known number of arguments. These pass arguments directly by pointer with no `Variant` boxing - the fast path with no allocations.

- **Vararg methods** like `Object.call()` accept any number of arguments by boxing them into `Variant`s. The return value is always a `Variant` that you must `deinit()`.

For vararg functions, gdzig provides two versions to help you:

- **Non-allocating** (`call`, `emit`, etc.): Compile error if you pass packed array types (`PackedByteArray`, `PackedInt32Array`, etc.). These require heap allocation when boxed into `Variant`.
- **Allocating** (`callAlloc`, `emitAlloc`, etc.): Accepts packed arrays, boxing them in a `Variant` internally and cleaning up after the call.

The non-allocating versions protect you from accidental allocations. If you need to pass a packed array, use the allocating version or box it in a `Variant` yourself and manage its lifetime.

## Common Gotchas

**Leaking Variants**: Any `Variant` returned from a vararg call must be `deinit()`ed. The compiler can't catch this.

**Packed arrays in varargs**: Using `PackedByteArray` etc. in `call()` or `emit()` is a compile error by design. Use the Alloc variants.

**Storing RefCounted references**: Storing raw pointers to RefCounted objects won't prevent collection - you must call `reference()` to prevent the object from being freed.
