# Runtime compatibility hash audit

`src/compat/method_hashes.zig` contains frozen Godot 4.6 ABI anchors, not a
reimplementation of Godot's signature-hash algorithm. The values were extracted
from the official **Godot 4.6.3 stable** API dump and checked against the vendored
API's compatibility candidates. Modern shims call private generated delegates,
so their hashes and named option types come directly from `vendor/extension_api.json`.

| Class | Method | Godot 4.6.3 hash |
| --- | --- | ---: |
| Object | is_class | 3927539163 |
| RichTextLabel | add_image | 1390915033 |
| RichTextLabel | update_image | 6389170 |

## Reproduce the extraction

From the repository root, set `GODOT_46` to an official Godot 4.6.3 executable.
The version command must report `4.6.3.stable`. The dump is a development audit
artifact only. Do not commit it or make it a build dependency.

```sh
repo="$PWD"
dump_dir="${XDG_CACHE_HOME:-$HOME/.cache}/gdzig-4.6.3-audit"
mkdir -p "$dump_dir"
"$GODOT_46" --version
(cd "$dump_dir" && "$GODOT_46" --headless --dump-extension-api)
jq '.classes[]
    | select(.name == "Object" or .name == "RichTextLabel")
    | .name as $class
    | .methods[]
    | select(.name == "is_class" or .name == "add_image" or .name == "update_image")
    | {class: $class, name, hash,
       arguments: [.arguments[] | {name, type, meta, default_value}]}' \
    "$dump_dir/extension_api.json"
```

Besides the three hashes above, inspect the signature evidence: `is_class`
accepts String on 4.6, image width/height are integers, and the two percent
arguments are booleans. Both image methods have twelve arguments. In `add_image`,
`alt_text` is the twelfth argument on both 4.6.3 and the vendored modern API.

## Audit membership against the vendored API

This check exits unsuccessfully if any extracted anchor is absent from the
corresponding vendored compatibility candidate list.

```sh
jq -e --slurpfile legacy "$dump_dir/extension_api.json" '
  [.classes[]
   | select(.name == "Object" or .name == "RichTextLabel")
   | .name as $class
   | .methods[]
   | select(.name == "is_class" or .name == "add_image" or .name == "update_image")
   | . as $modern
   | ($legacy[0].classes[] | select(.name == $class)
      | .methods[] | select(.name == $modern.name) | .hash) as $hash
   | {class: $class, method: .name, hash: $hash,
      accepted: ((.hash_compatibility // []) | index($hash) != null)}]
  | if length == 3 and all(.[]; .accepted) then . else error("anchor audit failed") end
' "$repo/vendor/extension_api.json"
```

Compatibility arrays do not label candidate hashes with engine versions. Their
order alone cannot establish a historical signature or its ABI. The 4.6 branch
uses these audited version-specific anchors, while the modern branch delegates
to generated bindings. A future ABI change requires a new measured signature
and marshaling adapter, not an inferred version-to-hash database. Pre-4.6 runtime
support remains best-effort.
