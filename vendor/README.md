# Vendored Godot interface

`gdextension_interface.h` is generated from the `godot_cpp` dependency in
`build.zig.zon`. The default build uses this copy and does not require Python.

When the `godot_cpp` version changes, regenerate the header with Python and
replace the vendored copy:

```sh
mise exec -- zig build -Dregenerate-interface -Dgodot-path="$(mise which godot)"
cp zig-out/vendor/gdextension_interface.h vendor/gdextension_interface.h
```

Review and commit the header diff with the dependency update.
