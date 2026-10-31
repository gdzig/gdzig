# Add destination-owned initializers for misdirected Godot factories

Provenance: `std.*` names are from the Zig standard library, `gdzig.*` names
are from this project, and unqualified class names are Godot 4.7.2 engine
classes exposed by gdzig.

A receiver-bound operation requires an instance of its owner. It stays on that
owner even when it returns another type: Godot's `Object.call` returns
`Variant`, `BitMap.convertToImage` returns `Image`, and
`PackedScene.instantiate` returns `Node`. These are not initializers of their
results.

A misdirected initializer is the opposite: it constructs a value of type `T`
but Godot declares it on an unrelated namespace or singleton, with no instance
of `T` involved. `ResourceLoader.load` for `Resource` is the model case. For
each such type, add a gdzig initializer owned by `T` and returning a value
coercible to `T`, so Zig's inferred initializer form resolves:
`const resource: ?*Resource = .fromPath(path)`. Generate the initializer when
the mapping is mechanical; use a mixin when ownership or argument handling
needs judgement. This is how Godot creation becomes idiomatic Zig without
hiding the engine's ownership model.

When the destination type is chosen at runtime, as with
`ClassDb.instantiate`, keep the factory on its namespace and add a typed helper
such as `ClassDb.instantiateAs(T, class_name)` instead of inventing a
destination-owned initializer on `Variant`.

This is additive. It does not move `Object.call`, `ClassDb.instantiate`,
`ResourceLoader.load`, or `PackedScene.instantiate`. The Zig standard library's
`std.process.Child.init` is the positive model: it is owned by `Child` and
returns `Child`, so `const child: Child = .init(...)` resolves.
`std.fs.Dir.openFile` (returning `std.fs.File`) and gdzig's existing
`gdzig.builtin.Variant.call` (calling a method on a `Variant`) are the
receiver-bound operations that show returning a type does not make a function
that type's initializer.
