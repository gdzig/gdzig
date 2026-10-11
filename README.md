# gdzig

Idiomatic Zig bindings for Godot 4.

## DISCLAIMER

This library is currently undergoing rapid development and refactoring as we figure out the best API to expose. Bugs and missing features are
expected until a stable version is released. Issue reports, feature requests, and pull requests are all very welcome.

## Prerequisites

1. Zig 0.17.0
2. Godot 4.7.2

**Note:** gdzig currently targets these exact Zig and Godot releases.

### WebAssembly

WebAssembly is supported on the above Zig release via the `wasm32-emscripten` target:

```sh
zig build -Dtarget=wasm32-emscripten
```

See the [example](example/) for a browser export preset and instructions.

## Usage:

See the [example](example/) folder for reference.

### Compile-time Godot compatibility minimum

Default builds discover the running engine version. To fold version gates and
method-bind selection at compile time, select a measured minimum:

```sh
zig build -Dgodot_compatibility_minimum=4.6
```

This is a floor, not an exact engine lock. Matching and newer engines are
accepted, and older engines are rejected during initialization. Bindings still
come from the current vendored API. With the option, `gdzig.version` is the
constant effective floor rather than the actual runtime version. See the
[compatibility minimum guide](docs/compatibility-minimum.md) for supported
manifest targets, downstream build usage and limitations.

## Code Sample:

https://github.com/gdzig/gdzig/blob/1cdfec61d185a9440e6419b122a08e003ad3dcde/example/src/GuiNode.zig#L1-L56

# Community

Find us in the [gdzig Discord server](https://discord.gg/GEUZGRGeDj).
