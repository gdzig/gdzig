# Runtime compatibility hash audit

Use an engine API dump to inspect a method's signature and hash, then compare
it with the vendored API. Keep runtime hash constants in
`src/compat/method_hashes.zig`, not duplicated in this document. Generated
bindings derive their hashes and option types from `vendor/extension_api.json`.

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
