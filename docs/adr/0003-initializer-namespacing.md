# Add destination-owned initializers for misdirected Godot constructors

Provenance: `std.*` names are from the Zig standard library, `gdzig.*` names
are from this project, and unqualified class names are Godot 4.7.2 engine
classes exposed by gdzig.

Godot often exposes creation as a static method on an unrelated namespace:
`ResourceLoader.load` for `Resource`, `ClassDb.instantiate` for `Variant`,
`BitMap.convertToImage` for `Image`. Those operations stay on their Godot
owner, because the owner is the authority being invoked, not the type being
constructed.

For each type whose Godot creation path is such a misdirected initializer, add
a gdzig initializer owned by the destination type. It returns a value coercible
to the destination, so the inferred initializer form resolves:
`const resource: ?*Resource = .fromPath(path)`,
`const image: ?*Image = .fromBitMap(bitmap)`, and
`const result: Variant = try .fromCall(object, ...)`. Generate the initializer
when the mapping is mechanical; use a mixin when ownership or argument handling
needs judgement. This is how Godot creation becomes idiomatic Zig without
hiding the engine's ownership model.

This is additive. It does not move Godot's `Object.call`,
`ClassDb.instantiate`, `ResourceLoader.load`, or `PackedScene.instantiate`.
Moving every cross-type function under its return type was rejected: it
duplicates operations, hides the receiver, and misstates ownership. The Zig
standard library's `std.process.Child.init` is the positive model: it is owned
by `Child` and returns `Child`, so `const child: Child = .init(...)` resolves.
`std.fs.Dir.openFile` (returning `std.fs.File`) and gdzig's existing
`gdzig.builtin.Variant.call` (calling a method on a `Variant`) are the
counterexamples: returning a type does not make a function that type's
initializer.
