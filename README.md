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

WebAssembly builds do not work with Zig 0.16.0 because of [ziglang/zig#31849](https://codeberg.org/ziglang/zig/issues/31849). Zig fixed the issue in [ziglang/zig#31850](https://codeberg.org/ziglang/zig/pulls/31850) after the 0.16.0 release.

If you need WebAssembly, use a gdzig compatibility tag for Zig 0.15.x and the matching Zig release. Compatibility tags use the format `zig-{zig-version}-{date}`. Choose the latest tag whose name starts with `zig-0.15.`.

## Usage:

See the [example](example/) folder for reference.

## Code Sample:

https://github.com/gdzig/gdzig/blob/1cdfec61d185a9440e6419b122a08e003ad3dcde/example/src/GuiNode.zig#L1-L56

# Community

Find us in the [gdzig Discord server](https://discord.gg/GEUZGRGeDj).
