# Zig version compatibility: shape-check gates in disposable compat modules

gdzig pins one stable Zig release (0.17.0, via `build.zig.zon` / `mise.toml`) but keeps the build green on zig master so version upgrades are incremental instead of big-bang (#245). Compat code is written to be deleted: the support window is the latest stable release plus master, and nothing else.

Where an API differs between toolchains, gate on comptime API *shape* (`@hasDecl` / `@hasField` / return-type probes), not on `builtin.zig_version`. Shape checks keep working when master drifts again (e.g. a future 0.18 renames the same API), and they document intent: the code asks "does this API exist in this form?" rather than "which compiler is this?". A version gate (`compat.zig_016`) is reserved for changes with no API shape to probe — language-rule changes such as the empty-exhaustive-enum rule.

All shims live in exactly two modules: `src/compat.zig` for runtime code and `build/compat.zig` for build scripts. Call sites import and call helpers directly; per-site markers are unnecessary because removing a helper surfaces a build error at every site. Gates are discoverable with `git grep -E "comptime !?@has(Decl|Field)"` (inline shape gates and the compat modules) plus `git grep "TODO(zig 0.16.0)"` for the module-level markers and the inherently version-scoped wasm workaround.

When a new Zig releases: drop the old toolchain from CI, repin, then sweep — delete every old-shape branch in the two compat modules and any remaining version-gated branches. The modules should stay thin; if a shim survives two release cycles, that is a smell.

Considered and rejected:

- **Version gates everywhere** (`if (zig_version.minor == 16)` at every site): less self-describing, silently wrong when master changes the API a second time, and scatters the convention instead of centralizing it.
- **Long-term support for multiple stable Zig versions**: rejected unless multiple stable releases become common in the wild. The compat modules exist to make *upgrades* cheap, not to accumulate permanent backwards compatibility.
- **Per-site `TODO(zig 0.16.0)` markers**: replaced by the helper-module design; a deleted helper fails the build at every call site, which is a stronger signal than a greppable comment.
