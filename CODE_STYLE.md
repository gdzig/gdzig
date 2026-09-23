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
