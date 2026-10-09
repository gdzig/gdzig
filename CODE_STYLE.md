# Code style

Run `zig fmt` on Zig source files before committing them. Apply the following
rules to handwritten Zig code.

## Imports

Place imports and aliases derived from imports at the bottom of the file, after
type and function declarations.

Group them in this order, with a blank line between groups:

1. Zig standard library imports and aliases.
2. Third-party imports.
3. Project imports.

```zig
const std = @import("std");
const Writer = std.Io.Writer;

const casez = @import("casez");

const Config = @import("Config.zig");
```

## File names

A file is a struct. Name the file after what that struct is:

- If the file declares top-level fields, it is a type. Use TitleCase,
  for example `GodotApi.zig` or `Args.zig`, and import it with the same name:
  `const GodotApi = @import("GodotApi.zig");`.
- If the file has no top-level fields, it is a namespace of declarations.
  Use snake_case, for example `version_dispatch.zig`, and import it with a
  lowercase alias: `const version_dispatch = @import("version_dispatch.zig");`.

When a namespace file holds a single named type that cannot be the file struct,
such as an `extern struct`, keep the TitleCase name on the type and reach it
through the namespace:

```zig
const Version = @import("version.zig").Version;
```

## Tests

Group handwritten test declarations at file scope, after production declarations
and immediately before the final imports and aliases. Do not interleave tests
with production declarations or nest them in types. This rule applies to actual
handwritten tests, not Zig source text emitted by code generators.

## Initialization

When a variable has a named type, put the type on the left-hand side and use an
inferred initializer on the right-hand side.

```zig
var output: Writer.Allocating = .init(allocator);
var writer: CodeWriter = .init(&output.writer);
var imports: Imports = .empty;
```

Do not repeat the type on the right-hand side when inference is clear:

```zig
var output = Writer.Allocating.init(allocator);
```

## Readability and declarations

Write each struct field on its own line and retain its trailing comma. Separate
struct and other type declarations with a blank line.

Separate logical blocks with blank lines. Keep lines short enough to read without
horizontal scrolling. Name intermediate values instead of nesting many lookups
or conversions in one expression. Prefer enum parsing and `switch` over long
`if`/`else` chains that repeat string comparisons.

Use comments to explain intent, invariants or safety requirements. Do not narrate
obvious operations. Document every added or changed public function with a `///`
comment describing its purpose, inputs and significant return or error behavior.

## Type conversion initializers

When an enum, tagged union, or other type owns a conversion from another project
or API type, put the converter on the destination type and name it like an
initializer, for example `fromUtilityFunction`. This keeps the conversion close
to the type it creates and matches the idiomatic Zig pattern used throughout the
codebase.

```zig
pub const TypeSelectedScalar = enum {
    none,
    float,
    int,

    pub fn fromUtilityFunction(function: GodotApi.UtilityFunction) TypeSelectedScalar {
        // Convert external metadata into this enum.
    }
};
```

Prefer this over a free helper such as `typeSelectedScalar(function)` when the
function's purpose is to construct or select that type.
