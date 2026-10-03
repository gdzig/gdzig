# gdzig

Idiomatic Zig bindings for Godot 4.

## DISCLAIMER

This library is currently undergoing rapid development and refactoring as we figure out the best API to expose. Bugs and missing features are
expected until a stable version is released. Issue reports, feature requests, and pull requests are all very welcome.

## Prerequisites

1. Zig 0.16.0
2. Godot 4.7.2, or Godot 4.6.3 for native builds targeting the 4.6 API

**Note:** gdzig currently targets Zig 0.16.0. Generated bindings use the vendored Godot 4.7.2 API by default.

### WebAssembly

WebAssembly is supported on Zig 0.16.0 through a built-in workaround for [ziglang/zig#31849](https://codeberg.org/ziglang/zig/issues/31849), a standard library bug in that release. The workaround applies only to wasm32-emscripten builds on Zig 0.16.x and turns itself off on Zig releases with the upstream fix ([ziglang/zig#31850](https://codeberg.org/ziglang/zig/pulls/31850)).

Build an extension for the web with the `wasm32-emscripten` target:

```sh
zig build -Dtarget=wasm32-emscripten
```

See the [example](example/) for a browser export preset and instructions.

## Usage:

See the [example](example/) folder for reference.

### Select the Godot API version

`-Dgodot-version=4.6|4.7` selects the generated binding API; the default is `4.7`. `-Dgodot-path` independently selects the Godot executable used by tests and examples. It does not select the binding API.

To test this repository with Godot 4.6 bindings and an explicit 4.6.3 runtime:

```sh
zig build test -Dgodot-version=4.6 -Dgodot-path="/path/to/godot-4.6.3"
```

Downstream extensions must pass the version to the gdzig dependency; a root-project CLI option is not forwarded automatically:

```zig
const gdzig_dep = b.dependency("gdzig", .{
    .target = target,
    .optimize = optimize,
    .@"godot-version" = "4.6",
});
```

Set `compatibility_minimum` in the extension's `.gdextension` manifest to the matching minimum version. The 4.6 target currently has native-only coverage. It tests bindings generated for 4.6 on Godot 4.6.3; it does not guarantee that binaries built for 4.7 run on 4.6. The two 4.7-specific Resource ownership tests are skipped on 4.6.

## Code Sample:

https://github.com/gdzig/gdzig/blob/1cdfec61d185a9440e6419b122a08e003ad3dcde/example/src/GuiNode.zig#L1-L56

# Community

Find us in the [gdzig Discord server](https://discord.gg/GEUZGRGeDj).
