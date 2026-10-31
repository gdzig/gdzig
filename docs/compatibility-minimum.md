# Godot compatibility minimum

Bindings always come from the single current vendored API snapshot. By default,
`gdzig.api_version` is populated with the actual engine version at initialization,
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
patch release. Measured targets in `pkg/bindgen/generated/compatibility.zon` are
used directly without downloading historical engines or running metadata tools.
There is no separate handwritten allowlist.

An uncached minimum downloads that exact stable Godot release through the
`godot-versions` catalog, extracts its API, and appends its measured records to a
build-cache manifest. The vendored manifest is not changed. This path requires
network access. The release must exist in the catalog and cannot be newer than
the current vendored snapshot. Prerelease and malformed values are rejected.
Measuring an older release does not provide missing layout adapters: an
unshimmed method can still fail when it is called.

The build passes the normalized floor to bindgen as
`--godot-compatibility-minimum=4.6.0` and the selected manifest as
`--compatibility=/path/to/compatibility.zon`. Direct bindgen callers can supply
an external manifest with that option. Without it, bindgen uses the vendored
manifest configured when its executable was built. Long options use `=`,
alongside the other required named options.

## Version and binding behavior

`gdzig.api_version` points to the API layout targeted by the bindings. With a
minimum, its target is a constant equal to that floor, so version gates fold at
compile time. Without the option, its target is populated with the running engine
version at startup. Member access works through the pointer, such as
`gdzig.api_version.major` or `gdzig.api_version.range(...)`. Use
`gdzig.api_version.*` when copying the version value.

`gdzig.engine_version` is always populated with the actual running engine version
at initialization. In a minimum build, `api_version` can be older than
`engine_version`. Use the API version for binding layout and feature gates, and
the engine version when reporting the runtime's identity. There is no deprecated
`gdzig.version` alias.

```zig
const actual = gdzig.engine_version;
std.debug.print("Godot {d}.{d}.{d}\n", .{ actual.major, actual.minor, actual.patch });
```

Optional GDExtension interfaces are gated by measured availability, not by the
header's `@since` tag. Each measured target records the interface names its own
`gdextension_interface.h` lacks, as a per-table delta in the manifest.

In a default build, the generated dispatch table probes `get_godot_version` once
at load time and requests an optional interface only when the running engine is
at least the first measured release that provides it. The generated comparison is
a full version check, including the patch component, so a future patch release
can add an interface without widening an earlier gate.

In a build with a compatibility minimum, the floor is known at compile time, so
the interface gates fold away. An optional interface absent at the floor becomes
a null field with no `getProcAddress` call. An optional interface present at the
floor is requested unconditionally. The runtime `get_godot_version` probe remains
only for the startup floor check and `gdzig.engine_version`. A 4.6 floor build
therefore emits no lookups for the three 4.7-only interfaces, while a 4.7 floor
build loads them.

Because the measured window starts at the oldest cached target, an optional
interface that exists in the current header and in the oldest target is gated at
that oldest target. In a default build, optional interfaces introduced in 4.2
through 4.5 are therefore requested from 4.6.0 onward and not on 4.2 through 4.5
engines. Selecting an older floor adds that release as a measured target and
tightens the interfaces available at the floor.

Interfaces whose verified `@since` tag is 4.1 are present in every measured target
and remain unconditional. They are loaded through `getProcAddress(...).?`, so a
non-nullable field cannot be null on a Godot 4.1 or newer engine for the verified
header. A tag that contradicts the measured interval fails the build with
`InterfaceAvailabilityDisagreement`, and a missing or malformed tag fails with
`InvalidInterfaceSinceTag`.

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

The manifest also pins the current header's interface evidence.
`current_interfaces_sha256` is the SHA-256 of the vendored header's sorted `@name`
entries, one per line, with a trailing newline. The `interfaces` array stores one
delta per method table, listing the interface names that table's release header
lacks. Because the digest covers the header itself, a header-only change that does
not touch `extension_api.json` still invalidates the metadata.

Bindgen compares the parsed header against the manifest on every build, with or
without a compatibility minimum, and fails with `StaleCompatibilityInterfaces` and
a regeneration hint when they differ. Interface evidence that is missing,
duplicated, unsorted, dangling or non-monotonic fails with
`UnresolvedInterfaceEvidence`, `InvalidInterfaceEvidence` or
`NonMonotonicInterfaceEvidence`, and an append whose current digest does not match
the extracted header fails with `InterfaceSnapshotMismatch`.

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
