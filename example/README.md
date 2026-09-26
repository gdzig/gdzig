# gdzig-examples

Examples for gdzig

## Build

1. git clone https://github.com/gdzig/gdzig
2. cd gdzig/example
3. zig build run

## Options

1. -Dgodot=<godot_cmd> #default: use `godot` from path

## Web

Build the extension for the browser:

```sh
zig build -Dtarget=wasm32-emscripten
```

Export the project with the included `Web` preset (requires Godot's export templates):

```sh
mkdir -p web
godot --headless --path project --export-release "Web"
```

The build uses threads, so serve `web/` over HTTP with cross-origin isolation headers, then open it in a browser:

```
Cross-Origin-Opener-Policy: same-origin
Cross-Origin-Embedder-Policy: require-corp
```
