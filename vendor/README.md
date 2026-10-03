# Vendored Godot API inputs

The build uses checked-in GDExtension inputs so normal builds do not depend on
local Python or Godot versions:

- `gdextension_interface.h` is generated from the `godot_cpp` dependency pinned
  in `build.zig.zon`.
- `extension_api-4-6.json` and `extension_api-4-7.json` are the symmetric,
  version-selected binding API inputs.

## Provenance

- `extension_api-4-6.json` is copied without reformatting from
  `gdextension/extension_api-4-6.json` in
  [godot-cpp `10.0.0-stable`](https://github.com/godotengine/godot-cpp/blob/10.0.0-stable/gdextension/extension_api-4-6.json),
  the archive pinned in `build.zig.zon` as
  `N-V-__8AAPiBDgI4ZFSc7fNDjGwiILwckhuE6UrxqNraBX0S`. Its header identifies
  `Godot Engine v4.6.stable.official` (4.6.0), and its SHA256 is
  `00a3ad6df2361ed3df6ef9bc8717fe0f49112012ee6e87a7b4cfb34465c9beed`.
- `extension_api-4-7.json` is the existing documented API exported by the Godot
  tool pinned in `mise.toml` as `4.7.2-stable`, renamed byte-for-byte from
  `extension_api.json`. Its header identifies
  `Godot Engine v4.7.2.stable.official`, and its SHA256 is
  `4bea5bc77f39f1091f804dab656a355c63f3dd0284b37803dcbc840d808868a7`.

Godot Engine and godot-cpp distribute these upstream API artifacts under the
MIT license; see the [Godot license](https://github.com/godotengine/godot/blob/4.7.2-stable/LICENSE.txt)
and the [godot-cpp license](https://github.com/godotengine/godot-cpp/blob/10.0.0-stable/LICENSE.md).

Update an input only when its corresponding pinned dependency or Godot version
changes, and preserve upstream JSON bytes.

## GDExtension interface header

Regenerate the header with Python:

```sh
mise exec -- zig build -Dregenerate-interface -Dgodot-path="$(mise which godot)"
cp zig-out/vendor/gdextension_interface.h vendor/gdextension_interface.h
```

## Documented 4.7 extension API

Confirm that `mise.toml` pins the intended Godot version. Export into a temporary
location, inspect the JSON header, and then replace the vendored file:

```sh
tmp_dir="$(mktemp -d)"
(
  cd "$tmp_dir"
  mise exec -- godot --headless --dump-extension-api-with-docs
)
cp "$tmp_dir/extension_api.json" vendor/extension_api-4-7.json
```

Run `zig build test` before committing any vendored input change.
