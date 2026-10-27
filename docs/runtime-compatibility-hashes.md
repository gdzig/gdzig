# Runtime compatibility hash audit

Use an engine API dump to inspect a method's signature and hash, then compare
it with the vendored API. The generated compatibility manifest holds measured
old signatures and hashes. Bindgen emits typed `_legacy` bindings and version
dispatch from that manifest, so mixins contain no hash constants or ptrcalls.
Mixins provide private `<method>_<major>_<minor>` value-conversion adapters.

For example, `OptimizedTranslation.generate` returns `true` on Godot 4.6 after
calling the old void-returning binding. Godot 4.6 exposes no failure result.
On newer engines, the generated modern binding returns the engine's boolean.

An unshimmed layout does not stop generation. Calling it on an engine in that
range panics in a runtime-dispatch build. An inside-range minimum build reports
a compile error when the method is analyzed. Bindgen reports missing and stale
adapters only with verbose output. Generated `refAllDecls` tests stay unchanged.

## Extract a method from an engine build

From the repository root, set `GODOT` to the executable being audited and set
`CLASS` and `METHOD` to their engine API names. Record the reported version
alongside the audit results. The dump is a development artifact only. Do not
commit it or make it a build dependency.

```sh
set -eu
repo="$PWD"
: "${GODOT:?Set GODOT to the executable being audited}"
: "${CLASS:?Set CLASS to the engine class name}"
: "${METHOD:?Set METHOD to the engine method name}"
cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}"
mkdir -p "$cache_dir"
dump_dir=$(mktemp -d "$cache_dir/gdzig-api-audit.XXXXXX")
"$GODOT" --version
(cd "$dump_dir" && "$GODOT" --headless --dump-extension-api)
jq -e --arg class "$CLASS" --arg method "$METHOD" '
  [.classes[] | select(.name == $class)
   | .methods[] | select(.name == $method)
   | {name, hash, is_static, is_vararg, return_value,
      arguments: [.arguments[]? | {name, type, meta, default_value}]}]
  | if length == 1 then .[0] else error("method not found or ambiguous") end
' "$dump_dir/extension_api.json"
```

Compare that signature with the corresponding vendored method. Inspect argument
order, types, metadata and defaults, plus return type and call mode. A matching
hash candidate does not establish that the current marshaling code supports the
selected engine's ABI.

```sh
jq -e --arg class "$CLASS" --arg method "$METHOD" '
  [.classes[] | select(.name == $class)
   | .methods[] | select(.name == $method)
   | {name, hash, is_static, is_vararg, return_value,
      arguments: [.arguments[]? | {name, type, meta, default_value}]}]
  | if length == 1 then .[0] else error("method not found or ambiguous") end
' "$repo/vendor/extension_api.json"
```

## Check hash membership

The check accepts the selected engine method's hash if it equals the vendored
primary hash or belongs to its compatibility list. Missing or ambiguous methods
and unrecognized hashes fail the check.

```sh
jq -e --arg class "$CLASS" --arg method "$METHOD" \
  --slurpfile engine "$dump_dir/extension_api.json" '
  [.classes[] | select(.name == $class)
   | .methods[] | select(.name == $method)] as $current
  | [$engine[0].classes[] | select(.name == $class)
     | .methods[] | select(.name == $method)] as $selected
  | if ($current | length) != 1 or ($selected | length) != 1
    then error("method not found or ambiguous")
    else $current[0] as $api | $selected[0].hash as $hash
    | {class: $class, method: $method, hash: $hash,
       accepted: (([$api.hash] + ($api.hash_compatibility // []))
                  | index($hash) != null)}
    | if .accepted then . else error("hash membership audit failed") end
    end
' "$repo/vendor/extension_api.json"
```

Compatibility arrays do not label candidates with engine versions. Their order
cannot establish a historical signature or its ABI. A new ABI adapter requires
measured signature evidence and runtime checks, not an inferred version-to-hash
mapping.

## Interface availability audit

The generated dispatch table treats the measured manifest, not the header's
`@since` tag, as the source of optional interface availability. Audit an engine
header against the vendored evidence:

```sh
zig build compat-audit -Dengine-header=/path/to/engine/gdextension_interface.h
```

The tool reads `pkg/bindgen/generated/compatibility.zon` and
`vendor/gdextension_interface.h` by default. It checks that the vendored header's
sorted `@name` set matches `current_interfaces_sha256` and that every measured
delta name exists in that set. It then prints:

- the manifest digest and the number of current and engine names;
- `engine-only` names, present in the audited engine header but absent from the
  vendored header;
- `vendored-only` names, absent from the audited engine header, with each name's
  measured `gate`, `last_absent` and `present_in_oldest` classification.

The tool sorts names byte-wise internally, so no shell locale setting matters.
Exit code 0 means the name sets match, 1 means they differ, and 2 means a usage,
IO, ZON or validation error occurred. The audit is diagnostic and never rewrites
the manifest.

Each manifest table carries a `missing` delta for its release. A name in an
older table's delta and in no newer table's delta was added within the measured
window, and the oldest release that provides it is its gate. A header `@since` tag
that contradicts the measured interval is a named build error
(`InterfaceAvailabilityDisagreement`, `InvalidInterfaceSinceTag`), as are stale or
malformed manifests (`StaleCompatibilityInterfaces`, `InvalidInterfaceEvidence`,
`NonMonotonicInterfaceEvidence`, `UnresolvedInterfaceEvidence`).
