# gdzig

Idiomatic Zig bindings for Godot 4.

## DISCLAIMER

This library is currently undergoing rapid development and refactoring as we figure out the best API to expose. Bugs and missing features are
expected until a stable version is released. Issue reports, feature requests, and pull requests are all very welcome.

## Prerequisites

1. Zig 0.16.0
2. Godot 4.7.2

**Note:** gdzig currently targets these exact Zig and Godot releases.

### WebAssembly

WebAssembly is supported on Zig 0.16.0 through a built-in workaround for [ziglang/zig#31849](https://codeberg.org/ziglang/zig/issues/31849), a standard library bug in that release. The workaround applies only to wasm32-emscripten builds on Zig 0.16.x and turns itself off on Zig releases with the upstream fix ([ziglang/zig#31850](https://codeberg.org/ziglang/zig/pulls/31850)).

Build an extension for the web with the `wasm32-emscripten` target:

```sh
zig build -Dtarget=wasm32-emscripten
```

See the [example](example/) for a browser export preset and instructions.

## Usage:

See the [example](example/) folder for reference.

## Code Sample:

https://github.com/gdzig/gdzig/blob/1cdfec61d185a9440e6419b122a08e003ad3dcde/example/src/GuiNode.zig#L1-L56

# Community

Find us in the [gdzig Discord server](https://discord.gg/GEUZGRGeDj).
