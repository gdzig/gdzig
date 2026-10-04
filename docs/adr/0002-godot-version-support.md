# Godot version support: single latest API snapshot, backwards compatibility via runtime discovery

gdzig generates bindings from a single API snapshot of the latest stable Godot release (`vendor/extension_api.json` / `vendor/gdextension_interface.h`). Backwards compatibility with older engines within the same major version is supported at runtime, by discovery rather than build-time variation: by default the same compiled extension binds against whatever engine version loads it.

Two properties of Godot's release model drive this. First, GDExtension is forward-compatible by design within a major version, and Godot maintains `hash_compatibility` metadata in the API description for exactly this reason: `classdbGetMethodBind` accepts compatibility hashes, so a method bind that fails under the latest hash can fall back to the hash the running engine actually serves. Second, Godot has no minor-version LTS: a stable branch is guaranteed support only until the next minor's first patch release (best-effort beyond that), with long-term support existing only at major boundaries (the 3.x branch after 4.0 shipped). Build-time version targeting would mean snapshotting engine branches whose upstream maintenance is on a countdown to end-of-life; runtime discovery covers them from the one latest snapshot instead.

Whether an older minor is supportable this way is assessed per release from the API diff, not assumed. Methods whose signatures changed get their binds routed through the `hash_compatibility` entries emitted by bindgen; changes that alter the argument *layout* get runtime-version-gated marshaling keyed off the runtime engine version; engine-called virtuals with changed signatures are documented as latest-only rather than shimmed. If a minor's delta proves not absorbable by these mechanisms, that minor is not supported and this ADR is revisited; incompatibilities are never absorbed silently. The shipped default always performs this discovery at runtime. An opt-in build option may pin a minimum engine version and fold the gates and bind-hash selection away at comptime as a pure optimization, but it never changes which API snapshot the bindings come from, and a pinned build still verifies the running engine at init.

Considered and rejected:

- **Dual API snapshots with a versioned build option**: checking in one API description per supported engine and generating bindings from the selected one. Rejected: an ongoing cost (another snapshot to vendor, paired CI runs per engine, another engine version to keep in mind for every change) for a problem runtime discovery solves from the single latest snapshot.
- **Compile-time floor** (filter or down-level the API snapshot at build time via a `-Dgodot-version`-style option): rejected; bindings always come from the single latest snapshot, and this splits the build and test matrix per engine version for a problem runtime discovery solves without any build-time switching. (Distinct from the accepted opt-in version *pin*, which leaves the snapshot untouched and only folds discovery at comptime.)
- **Treating latest-generated bindings as implicitly back-compatible without shims**: rejected; signature changes that alter argument layout would misread memory on older engines without gates. The runtime gates exist precisely for those cases.

References:

- [gdzig#265](https://github.com/gdzig/gdzig/issues/265) — Godot 4.6 runtime compatibility, the first application of this policy.
- [gdzig#266](https://github.com/gdzig/gdzig/issues/266) — the opt-in compile-time version pin accepted above.
- [gdzig#262](https://github.com/gdzig/gdzig/pull/262) — the dual-snapshot back-compat PR and its discussion; its test-runner fixes and `@since` loader check remain salvageable on their own merits.
