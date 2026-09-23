# Vendored Godot API inputs

The default build uses two checked-in files from the Godot 4.7.2 toolchain:

- `gdextension_interface.h` is generated from the `godot_cpp` dependency in
  `build.zig.zon`.
- `extension_api.json` is exported by Godot with API documentation.

These files keep normal builds independent of local Python and Godot versions.
Update them only when the corresponding pinned dependency or Godot version changes.

## GDExtension interface header

Regenerate the header with Python:

```sh
mise exec -- zig build -Dregenerate-interface -Dgodot-path="$(mise which godot)"
cp zig-out/vendor/gdextension_interface.h vendor/gdextension_interface.h
```

## Documented extension API

Confirm that `mise.toml` pins the intended Godot version. Export into a temporary
location, inspect the JSON header, and then replace the vendored file:

```sh
tmp_dir="$(mktemp -d)"
(
  cd "$tmp_dir"
  mise exec -- godot --headless --dump-extension-api-with-docs
)
cp "$tmp_dir/extension_api.json" vendor/extension_api.json
```

Run `zig build test` before committing either file.
