# Godot version support: one current API snapshot

## Decision

Generate bindings from the single latest stable snapshot in
`vendor/extension_api.json` and `vendor/gdextension_interface.h`. Do not vendor
one snapshot per engine version or filter the API to an older release.

Default extensions discover the actual engine version during initialization.
Generated methods try the current hash and then the API's compatibility hashes.
Handwritten adapters handle measured argument or return layout changes. Changed
engine-called virtuals remain latest-only unless separately adapted. Compatibility
is assessed from actual API differences, never inferred from a hash alone.

## Optional compile-time compatibility minimum

`-Dgodot_compatibility_minimum=major.minor[.patch]` is an optimization of this
runtime-discovery policy. It does not select a different API snapshot. The name
matches Godot's `.gdextension` `compatibility_minimum` key: it is a floor, not an
exact version lock. A missing patch means zero. Accepted floors are measured
targets in the generated compatibility manifest, with no handwritten allowlist.

Bindgen emits one selected binding per generated class or builtin method.
Sparse historical overrides replace current hashes only for ABI-compatible
layouts. Incompatible and return-added layouts use generated range dispatch to
private conversion adapters and typed legacy bindings. A method absent from the
older API retains its current hash. The full API remains visible, so applications
must not call unavailable methods on older engines.

The public `gdzig.api_version` points to the API layout targeted by the bindings.
Without a minimum, its target is mutable and set to the running engine at startup.
With a minimum, its target is a constant equal to the compatibility floor, so
version gates fold at compile time. The pointer itself is always a constant.
The public `gdzig.engine_version` always records the actual running engine and
can be newer than `api_version`. There is no `version` alias.

Both extension entrypoints still query the actual engine once before startup.
An older engine is rejected before registration, callbacks or IPC startup.
Matching and newer engines are accepted through Godot's compatibility bindings.
Minimum selection also checks the current snapshot's header and raw checksum
against the measured manifest provenance, so stale metadata cannot silently
select hashes for a changed snapshot.

## Alternatives rejected

- Multiple vendored API snapshots add ongoing maintenance and split the public API.
- Filtering the current API to the floor is not this optimization and would change
  application-visible declarations.
- Hash membership without layout adapters can corrupt legacy ptrcall arguments
  or return storage.
- Calling the floor a version pin implies an exact lock and misstates acceptance
  of newer engines.

See the [compatibility minimum guide](../compatibility-minimum.md) and
[layout audit](../runtime-compatibility-hashes.md) for usage and maintenance.
Godot 4.6 runtime adapters originated in issue #265. Issue #266 adds this opt-in
compile-time optimization without changing the default version-discovery policy.
