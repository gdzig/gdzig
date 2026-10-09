# Godot compatibility minimum

Bindings always come from the single current vendored API snapshot. By default,
`gdzig.version` is populated with the actual engine version at initialization,
and generated methods try the current hash before compatibility hashes.

## Select a compile-time floor

```sh
zig build -Dgodot_compatibility_minimum=4.6
zig build test -Dgodot_compatibility_minimum=4.6 -Dgodot-path=/absolute/path/to/godot
```

The example accepts the same build option and forwards it to its gdzig dependency.
Downstream builds pass `.godot_compatibility_minimum = "4.6"` in the options to
`b.dependency("gdzig", ...)`.

The grammar is `major.minor[.patch]`. A missing patch means zero, not the latest
patch release. Supported values are the measured targets in
`pkg/bindgen/generated/compatibility.zon`. There is no separate handwritten
allowlist. Malformed or unmeasured values fail before bindings are generated.
This seam does not download or generate metadata for an unmeasured minimum.

The build passes the normalized floor to bindgen as
`--godot-compatibility-minimum=4.6.0`. Direct bindgen callers use that long option
with `=`, alongside its other required named options.

## Version and binding behavior

With a minimum, `gdzig.version` is a constant equal to that floor. It is the
**effective compatibility version**, not the identity of the running engine.
The constant lets version gates fold at compile time. There is no second public
minimum declaration. Without the option, `gdzig.version` remains the actual
runtime version.

In a minimum build, `gdzig.version` is the compile-time floor, not the running
engine version. After initialization, callers who need the actual engine version
call `gdzig.raw.getGodotVersion` directly:

```zig
var actual: gdzig.Version = undefined;
gdzig.raw.getGodotVersion(@ptrCast(&actual));
std.debug.print("Godot {d}.{d}.{d}\n", .{ actual.major, actual.minor, actual.patch });
```

Generated class and builtin methods use one selected binding, with no compatibility
probe loop. ABI-compatible legacy hashes come from the measured target's table.
Methods with no override retain the current API hash, including APIs that did
not exist in the older engine. The option does not filter the API or fabricate
older implementations. Calling a newer-only method on an older engine remains
unsupported.

Incompatible and return-added layouts are handled by generated version dispatch,
not by replacing the modern method's hash. The compile-time floor selects a
private conversion adapter that calls a typed legacy binding. Above the legacy
range, the generated branch and binding are omitted. This preserves the Object,
RichTextLabel and OptimizedTranslation marshaling contracts.

Both the normal extension entrypoint and the IPC test entrypoint query the
actual engine once. If it is older than the floor, initialization returns failure
before registration, initialization callbacks or IPC startup. A diagnostic names
the required and actual numeric versions. Matching and newer engines are accepted.
For example, a 4.6 floor accepts Godot 4.7, while a 4.7 floor rejects Godot 4.6.
Godot may exit successfully despite rejecting an extension, so an exit code alone
is not proof of successful initialization.

## Audited snapshot and maintenance

Minimum selection requires the current API header and raw checksum to match the
manifest's current provenance. A changed snapshot fails with
`StaleCompatibilitySnapshot` and a regeneration diagnostic. Default runtime
selection keeps its existing streaming parse path.

Use the optional maintenance steps to extract and compare historical APIs:

```sh
zig build compat-metadata -Dold=all
zig build check-compat-metadata -Dold=all
zig build update-compat-metadata -Dold=all
```

The preview and per-release reports are installed under `zig-out/compat/`.
Maintenance is separate from ordinary builds and uses the lazy historical-header
dependency only when requested. Review the reports and ABI declarations before
adopting changed metadata. See [the layout audit](runtime-compatibility-hashes.md)
for missing and stale shim diagnostics.
