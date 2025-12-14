# Mixin System

This document describes how the mixin system works in gdzig's code generator.

## Overview

Mixins allow extending generated Godot bindings with custom Zig code. They provide a way to add:

- Additional helper functions
- Convenience constants
- Idiomatic Zig APIs
- Type-safe wrappers around Godot's C API

Mixins are defined in `*.mixin.zig` files alongside the generated binding code.

## File Structure

Mixin files follow a specific structure:

```zig
/// Doc comment for a constant
pub const identity: Transform2D = .initXAxisYAxisOrigin(
    .initXY(1, 0),
    .initXY(0, 1),
    .initXY(0, 0),
);

/// Doc comment for a function
pub fn fromUtf8(cstr: []const u8) !String {
    var result: String = undefined;
    const err = raw.stringNewWithUtf8CharsAndLen2(result.ptr(), @ptrCast(cstr.ptr), @intCast(cstr.len));
    if (err != 0) {
        return error.Full;
    }
    return result;
}

// @mixin stop

const gdzig = @import("gdzig");
const raw = &gdzig.raw;
const Transform2D = gdzig.builtin.Transform2D;
```

### Key Components

1. **Mixin start marker** (optional) - `// @mixin start` indicates where to start copying
2. **Public declarations** - Any `pub const` or `pub fn` declarations
3. **Doc comments** - Standard Zig `///` doc comments
4. **Mixin stop marker** - `// @mixin stop` indicates where to stop copying
5. **Imports** - Required imports come after the stop marker

### Generated Constants

For class mixins, two constants are generated before the mixin content:

- `Self` - Alias for `@This()`, the class type
- `self_name` - String literal of the Godot API class name (e.g., `"Node2D"`)

## Class Mixin Inheritance

Class mixins are inherited by child classes. When generating a class, mixins from all parent classes are included in order from root to leaf. For example, `Sprite2D` includes mixins from `Object`, `Node`, `CanvasItem`, `Node2D`, then `Sprite2D`.

## Location Conventions

Mixin files are located alongside their corresponding generated files:

- **Builtin types**: `gdzig/builtin/{TypeName}.mixin.zig`
  - Example: `gdzig/builtin/Transform2D.mixin.zig`
  - Example: `gdzig/builtin/Array.mixin.zig`

- **Class types**: `gdzig/class/{ClassName}.mixin.zig`
  - Example: `gdzig/class/Image.mixin.zig`
  - Example: `gdzig/class/FileAccess.mixin.zig`

- **Global enums/flags**: `gdzig/global/{EnumName}.mixin.zig`
  - Currently not widely used

## Implementation

The mixin system uses a hybrid approach: AST parsing during Context build for metadata tracking, and verbatim file copying during code generation.

### Build Phase - AST Parsing

During the build phase (`Context.build()`), builtin types parse their mixin files to populate the Context with metadata:

**Builtin types** (gdzig_bindgen/Context/Builtin.zig:162-210):

```zig
pub fn loadMixinIfExists(self: *Builtin, allocator: Allocator) !void {
    const mixin_file_path = try std.fmt.allocPrint(allocator, "gdzig/builtin/{s}.mixin.zig", .{self.name});
    const file = std.fs.cwd().openFile(mixin_file_path, .{}) catch return;

    // Read entire file
    const contents = try allocator.allocSentinel(u8, @intCast(try file.getEndPos()), 0);
    try file_reader.interface.readSliceAll(contents);

    // Find the @mixin stop marker and only parse up to that point
    const parse_contents: [:0]const u8 = blk: {
        if (std.mem.indexOf(u8, contents, "// @mixin stop")) |stop_idx| {
            contents[stop_idx] = 0;  // Null-terminate at marker
            break :blk contents[0..stop_idx :0];
        }
        break :blk contents;
    };

    // Parse AST and extract declarations
    var ast = try Ast.parse(allocator, parse_contents, .zig);
    defer ast.deinit(allocator);

    const root_decls = ast.rootDecls();
    for (root_decls) |index| {
        const node = ast.nodes.get(@intFromEnum(index));

        switch (node.tag) {
            .fn_decl => if (try Function.fromMixin(allocator, ast, index)) |result| {
                const fn_type, const function = result;
                switch (fn_type) {
                    .constructor => try self.constructors.append(allocator, function),
                    .method => try self.methods.put(allocator, function.name, function),
                }
            },
            .simple_var_decl, .aligned_var_decl, .global_var_decl => if (try Constant.fromMixin(allocator, ast, index)) |constant| {
                try self.constants.put(allocator, constant.name_api, constant);
            },
            else => {},
        }
    }
}
```

**Constant parsing** (gdzig_bindgen/Context/Constant.zig:80-115):

```zig
pub fn fromMixin(allocator: Allocator, ast: Ast, index: NodeIndex) !?Constant {
    const var_decl = ast.fullVarDecl(index) orelse return null;
    const node = ast.nodes.get(@intFromEnum(index));

    // Check for `pub const` (not `pub var` or private)
    const is_pub = /* check for keyword_pub token */;
    const is_const = ast.tokens.get(var_decl.ast.mut_token).tag == .keyword_const;

    if (!is_pub or !is_const) return null;

    // Extract name and convert to UPPER_SNAKE_CASE
    const name_token = var_decl.ast.mut_token + 1;
    const name = ast.tokenSlice(name_token);
    const name_api = try case.allocTo(allocator, .constant, name);

    return .{
        .skip = true,        // Mark as mixin - skip during codegen
        .name = name,        // Original name (e.g., "identity")
        .name_api = name_api,// API name (e.g., "IDENTITY")
    };
}
```

**Function parsing** (gdzig_bindgen/Context/Function.zig:220-268):

```zig
pub fn fromMixin(allocator: Allocator, ast: Ast, index: NodeIndex) !?struct { MixinType, Function } {
    var buffer: [1]NodeIndex = undefined;
    const proto = ast.fullFnProto(&buffer, index) orelse return null;

    // Check for `pub fn`
    const is_pub = /* check for keyword_pub token */;
    if (!is_pub) return null;

    // Distinguish constructors from methods by first parameter name
    const fn_type: MixinType = blk: {
        if (proto.ast.params.len > 0) {
            const first_param = proto.ast.params[0];
            const param_node = ast.nodes.get(@intFromEnum(first_param));
            const param_name = ast.tokenSlice(param_node.main_token);

            if (std.mem.eql(u8, param_name, "self")) {
                break :blk .method;
            }
        }
        break :blk .constructor;
    };

    return .{ fn_type, .{ .skip = true, .name = fn_name, ... } };
}
```

**Class types** do not currently load mixins during build - this is a future enhancement.

### Code Generation Phase - Verbatim Copying

During code generation (`codegen.generate()`):

1. **Skip mixin items** when generating code:

   ```zig
   // Example from codegen.zig:97, 106, 117
   for (builtin.constants.values()) |*constant| {
       if (constant.skip) continue;  // Skip mixin constants
       try writeConstant(w, constant);
   }

   for (builtin.methods.values()) |*method| {
       if (method.skip) continue;  // Skip mixin methods
       try writeFunction(w, method);
   }
   ```

2. **Copy mixin files verbatim** using `writeMixin()` (gdzig_bindgen/codegen.zig:627-650):
   - Reads mixin file line by line
   - Stops at `// @mixin stop` marker
   - Writes each line to generated file unchanged
   - Preserves exact formatting and comments

3. **Mixin insertion points**:
   - **Builtins**: After helpers, before closing `};`
   - **Classes**: After helpers, before closing `};`
   - **Enums**: Inside enum definition
   - **Flags**: Inside packed struct definition

### The `// @mixin start` and `// @mixin stop` Markers

The `// @mixin start` marker is optional. If present, copying starts from the line after it. If absent, copying starts from the beginning of the file.

The `// @mixin stop` comment serves two purposes:

1. **During AST parsing**: Content up to this marker is parsed, content after is ignored
   - Implemented by null-terminating the buffer at the marker position
   - Prevents parsing import statements that reference not-yet-generated files

2. **During code generation**: Content up to this marker is copied to generated files
   - Implemented by stopping line-by-line copy when marker is encountered
   - Separates mixin content from imports needed only during development

### Benefits of This Approach

1. **Simple Codegen** - No need to regenerate mixin code from AST
2. **Preserves Formatting** - Mixin files are copied exactly as written
3. **Context Visibility** - Mixin items visible for validation and cross-referencing
4. **Backwards Compatible** - Existing mixin files work without changes
5. **Error Detection** - Catch mixin syntax errors during build, not during manual testing
6. **Conflict Detection** - Can detect naming conflicts between generated and mixin code

## Examples

### Example 1: Constants Only (Transform2D)

From `gdzig/builtin/Transform2D.mixin.zig`:

```zig
/// The identity Transform2D. This is a transform with no translation,
/// no rotation, and a scale of Vector2.ONE.
pub const identity: Transform2D = .initXAxisYAxisOrigin(
    .initXY(1, 0),
    .initXY(0, 1),
    .initXY(0, 0),
);

/// When any transform is multiplied by FLIP_X, it negates all
/// components of the x axis (the X column).
pub const flip_x: Transform2D = .initXAxisYAxisOrigin(
    .initXY(-1, 0),
    .initXY(0, 1),
    .initXY(0, 0),
);

pub fn initXAxisYAxisOriginComponents(xx: f32, xy: f32, yx: f32, yy: f32, ox: f32, oy: f32) Transform2D {
    return .initXAxisYAxisOrigin(
        .initXY(xx, xy),
        .initXY(yx, yy),
        .initXY(ox, oy),
    );
}

// @mixin stop

const gdzig = @import("gdzig");
const Transform2D = gdzig.builtin.Transform2D;
```

### Example 2: Functions Only (Array)

From `gdzig/builtin/Array.mixin.zig`:

```zig
/// Sets an Array to be a reference to another Array object.
///
/// - **from**: A pointer to the Array object to reference.
///
/// **Since Godot 4.1**
pub inline fn ref(self: *Array, from: *const Array) void {
    raw.arrayRef(self.ptr(), from.constPtr());
}

/// Makes an Array into a typed Array.
///
/// - **T**: The type of `Variant` the `Array` will store.
/// - **script**: An optional pointer to a `Script` object.
///
/// **Since Godot 4.1**
pub inline fn setTyped(self: *Array, comptime T: type, script: ?*const Variant) void {
    const tag = Variant.Tag.forType(T);
    const name = if (tag == .object) gdzig.typeName(T).constPtr() else null;
    raw.arraySetTyped(self.ptr(), @intFromEnum(tag), name, if (script) |s| s.constPtr() else null);
}

// @mixin stop

const gdzig = @import("gdzig");
const raw = &gdzig.raw;
const Array = gdzig.builtin.Array;
const Variant = gdzig.builtin.Variant;
```

### Example 3: Class Mixin (Image)

From `gdzig/class/Image.mixin.zig`:

```zig
/// Returns a mutable slice of the internal Image buffer.
///
/// **Since Godot 4.3**
pub inline fn slice(self: *Image) []u8 {
    const len = @as(usize, @intCast(self.getDataSize()));
    const p = @as([*]u8, @ptrCast(raw.imagePtr(self.ptr())));
    return p[0..len];
}

/// Returns a const slice of the internal Image buffer.
///
/// **Since Godot 4.3**
pub inline fn constSlice(self: *const Image) []const u8 {
    const len = @as(usize, @intCast(self.getDataSize()));
    const p = @as([*]const u8, @ptrCast(raw.imagePtr(@constCast(self.constPtr()))));
    return p[0..len];
}

// @mixin stop

const gdzig = @import("gdzig");
const raw = &gdzig.raw;
const Image = gdzig.class.Image;
```

## Overriding Generated Code

### Constants Override Constructors

Mixin constants can override generated constructors with the same name. When a mixin constant shares a name with a constructor, the constructor is automatically marked as `skip=true` and excluded from codegen.

**Example** (from `Transform2D.mixin.zig`):

```zig
/// The identity Transform2D. This is a transform with no translation,
/// no rotation, and a scale of Vector2.ONE.
pub const identity: Transform2D = .initXAxisYAxisOrigin(
    .initXY(1, 0),
    .initXY(0, 1),
    .initXY(0, 0),
);
```

This constant overrides any `identity()` constructor from the API, allowing:

```zig
const t = Transform2D.identity; // ✓ Comptime-friendly constant
// vs
const t = Transform2D.identity(); // ✗ Constructor (skipped in codegen)
```

**Benefits:**

- **Comptime compatibility**: Constants can be used at compile time, unlike function calls
- **Zero-cost abstractions**: No runtime overhead from function calls
- **Cleaner syntax**: More idiomatic Zig code

**Implementation** (gdzig_bindgen/Context/Builtin.zig:187-194):

```zig
.simple_var_decl, .aligned_var_decl, .global_var_decl => if (try Constant.fromMixin(allocator, ast, index)) |constant| {
    try self.constants.put(allocator, constant.name_api, constant);

    // If a constructor has the same name, mark it to be skipped during codegen
    if (self.constructors.getPtr(constant.name)) |constructor| {
        constructor.skip = true;
    }
},
```

## Design Principles

1. **Separation of Concerns** - Mixins are separate from generated code
2. **Idiomatic Zig** - Mixins provide Zig-style APIs over C APIs
3. **Documentation** - All public mixin items should have doc comments
4. **Type Safety** - Use Zig's type system to provide safety guarantees
5. **Convenience** - Make common operations easier and more ergonomic
6. **Override Capability** - Mixins can override generated code when appropriate

## Statistics

As of the current codebase:

- **23 builtin mixin files**
- **3 class mixin files**
- All mixin files use the `// @mixin stop` convention
