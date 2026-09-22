# String and StringName Default Parameters Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make generated methods with omitted non-empty `String` and `StringName` optional parameters compile while preserving Godot’s declared default semantics.

**Architecture:** Fix the default-value representation at the bindgen/code-generation boundary rather than patching the generated audio class. Materialize non-empty `String` and `StringName` defaults as owned method-body temporaries because Godot string-like values cannot be safely constructed as Zig comptime field defaults. Add a compile-time generated-binding regression for `AudioStreamPlaybackPolyphonic.playStream(stream, .{})`, plus semantic coverage for non-empty and empty string-like defaults.

**Tech Stack:** Zig 0.16.0, gdzig bindgen, Godot extension API JSON, Jujutsu, mise.

## Global Constraints

- Use `mise exec -- zig ...` for the pinned Zig 0.16.0 toolchain.
- Do not change public generated method names or shape beyond what default arguments require.
- Do not change Godot’s semantic defaults for audio buses or other APIs.
- Do not rework unrelated default handling for non-string parameter types.
- Treat generated binding output as derived code; make the durable fix in bindgen and regenerate through the existing build task.
- Do not push unless a human explicitly asks.

---

## Context

GitHub issue #86 reports that the generated `AudioStreamPlaybackPolyphonic.playStream` optional `bus` field is typed as `StringName` but initialized with `&"Master"`. A call that omits the field therefore fails during compilation. The issue requires valid generated defaults for non-empty `StringName` values, continued support for empty `String`/`StringName` defaults, and a passing compile-time call-site regression.

## Root cause

`Function.Parameter.fromNameTypeDefault` delegates non-empty defaults to `Value.parse`. Plain `String` literals become `.string`, but `Value.isNullable` and `writeValue` currently collapse them to `null`, so the method passes an empty runtime `String` instead of the API’s declared non-empty value. Godot `StringName` literals use `&"..."`; `Value.parse` does not recognize that form and stores it as `.primitive`, so `writeValue` emits `&"Master"` directly where the generated optional field requires a `StringName`.

The ptrcall path supplies every argument slot, so passing an empty or null value cannot ask Godot to apply the declared default internally. Bindgen must supply the exact non-empty value through the generated optional field. Empty defaults must remain on the existing `.null` plus `optNullMaterializer` path, which creates and conditionally deinitializes a real empty builtin.

## Approach

Represent non-empty Godot `String` and `StringName` literals as distinct `Value` cases and decode their quoted syntax to UTF-8 bytes. Generated fields use nullable omission markers, then method bodies construct the exact UTF-8 default, pass it through ptrcall, and deinitialize only bindgen-owned temporaries.

This scoped runtime path applies to both `String` and `StringName`. The attempted inline cached `StringName` default cannot compile because Zig struct field defaults must be comptime-known, while all Godot string-like constructors depend on runtime GDExtension initialization. The owned temporary is therefore the safer behavior and preserves the existing nullable public shape for omitted string-like defaults.

`String.fromStringName` does not remove that ownership requirement. It is the generated runtime constructor for Godot’s `String(StringName)` conversion and still returns a by-value `String` that must be deinitialized. Routing every `String` default through it would first intern arbitrary text (including certificate subjects, MIME types, and long keys) as process-lifetime `StringName` entries, then still create and clean up a `String` for each omitted call. Direct `String.fromNullTerminatedUtf8` avoids polluting the intern table and has the same necessary scoped lifetime.

Do not add a literal registry to bindgen `Context`: `Context` runs in the host bindgen process and cannot construct target-runtime Godot values. A target-runtime registry would require new extension initialization/deinitialization plumbing for no benefit over the scoped temporaries generated at each omitted call.

Keep the existing empty-default special cases unchanged: `String` `""` and both API spellings of empty `StringName` (`&""` and `""`) continue to become `.null` and use `.init()` plus conditional cleanup through `optNullMaterializer`.

## Files to modify

- `pkg/bindgen/Context/value.zig`: distinguish and decode parsed `String` and `StringName` literals instead of collapsing or treating them as primitive Zig text.
- `pkg/bindgen/codegen.zig`: emit scoped, conditionally cleaned-up `String` and `StringName` defaults.
- `test/codegen/root.zig`: add the concrete `playStream(stream, .{})` compile regression, a semantic non-empty `String` default regression, and an empty `StringName` omission regression.

No generated binding file is committed: generated `src/builtin/*.zig` and `src/class/*.zig` outputs are ignored and are rebuilt by the Zig build graph.

## Reuse

- `pkg/bindgen/Context/Function.zig:489-513`: existing `Parameter.fromNameTypeDefault` empty-string special cases and generic `Value.parse` handoff.
- `pkg/bindgen/Context/value.zig`: existing `Value.parse`, `isNullable`, and `needsRuntimeInit` classification seam.
- `pkg/bindgen/codegen.zig:1079-1150`: existing nullable optional-field and `actual_<name>` materialization path.
- `pkg/bindgen/codegen.zig:1235-1250`: existing `optNullMaterializer` behavior for empty by-value builtins; do not replace or broaden it.
- `src/builtin/String.mixin.zig`: existing `String.fromNullTerminatedUtf8` constructor for scoped non-empty defaults; prefer it over the generated `String.fromStringName` conversion because both produce owned `String` values, while the latter also interns arbitrary default text.
- `src/builtin/StringName.mixin.zig`: existing `StringName.fromNullTerminatedUtf8` constructor for scoped non-empty defaults.
- `std.zig.string_literal.parseAlloc` and `std.zig.fmtString`: decode API literal escapes and safely re-emit Zig string literals while preserving non-ASCII UTF-8 such as the existing `"•"` default.
- `test/codegen/root.zig`: existing generated-binding integration harness and empty `String`/`Array` omission tests.

## Steps

### Task 1: Preserve string-like API defaults through generated ptrcalls

**Files:**
- Modify: `pkg/bindgen/Context/value.zig`
- Modify: `pkg/bindgen/codegen.zig`
- Test: `test/codegen/root.zig`

**Interfaces:**
- Consumes: `Function.Parameter.fromNameTypeDefault(..., default, ctx)` and its existing call to `Value.parse`.
- Produces: `Value.string` and `Value.string_name` cases containing decoded UTF-8 bytes; both require method-body runtime materialization and cleanup.
- Produces generated shapes: `bus: ?StringName = null` plus scoped `actual_bus`, and `character: ?String = null` plus scoped `actual_character`.

- [ ] **Step 1: Describe the existing Jujutsu revision before editing source**

Run:

```bash
jj st
jj desc -m "fix(bindgen): handle string-like parameter defaults"
```

Expected: `@` is the bench revision on `master` and contains only the approved `PLAN.md`; after `jj desc`, it has the conventional commit description above. Do not create another workspace, push, or create a pull request.

- [ ] **Step 2: Add generated-binding regressions**

In `test/codegen/root.zig`, add a compile-only helper that forces Zig to instantiate the concrete omitted-`bus` call:

```zig
fn playStreamWithDefaults(playback: *AudioStreamPlaybackPolyphonic, stream: *AudioStream) i64 {
    return playback.playStream(stream, .{});
}

test "non-empty StringName optional default compiles" {
    _ = &playStreamWithDefaults;
}
```

Add a runtime regression proving an omitted non-empty `String` argument preserves `String.lpad`’s declared single-space default:

```zig
test "non-empty String optional default preserves declared value" {
    var input: String = .fromLatin1("x");
    defer input.deinit();

    var padded = input.lpad(3, .{});
    defer padded.deinit();

    var buf: [8]u8 = undefined;
    try testing.expectEqualStrings("  x", padded.toUtf8Buf(&buf));
}
```

Add a runtime regression that continues to omit an empty `StringName` default through `Object.tr`:

```zig
test "empty StringName optional default remains valid" {
    const node = Node.init();
    defer node.destroy();

    var message: StringName = .fromLatin1("untranslated", false);
    defer message.deinit();

    var translated = node.tr(message, .{});
    defer translated.deinit();

    var buf: [32]u8 = undefined;
    try testing.expectEqualStrings("untranslated", translated.toUtf8Buf(&buf));
}
```

Add these imports beside the existing generated-class aliases:

```zig
const AudioStream = gdzig.class.AudioStream;
const AudioStreamPlaybackPolyphonic = gdzig.class.AudioStreamPlaybackPolyphonic;
```

- [ ] **Step 3: Run the regressions before implementation and record the expected failure**

Run:

```bash
mise exec -- zig build test
```

Expected: FAIL while analyzing `playStreamWithDefaults`, with the generated optional `bus: StringName = &"Master"` default reporting that a string pointer is not a `StringName`. If Zig reports the new semantic assertion first, record that failure too; do not weaken either test.

- [ ] **Step 4: Model both non-empty string-like literals as concrete parsed values**

Replace `pkg/bindgen/Context/value.zig` with the complete type-aware implementation below:

```zig
const ValueType = enum {
    null,
    string,
    string_name,
    boolean,
    primitive,
    constructor,
};

pub const Value = union(ValueType) {
    null: void,
    string: []const u8,
    string_name: []const u8,
    boolean: bool,
    primitive: []const u8,
    constructor: struct {
        type: Type,
        args: []const []const u8,
    },

    pub fn isNullable(self: Value) bool {
        return self == .null;
    }

    pub fn needsRuntimeInit(self: Value, ctx: *const Context) bool {
        switch (self) {
            .string => return true,
            .constructor => |c| {
                const type_name = switch (c.type) {
                    .basic => |name| name,
                    else => return false,
                };

                const builtin = ctx.builtins.get(type_name) orelse return false;
                const constructor = builtin.findConstructorByArgumentCount(c.args.len) orelse return false;
                return !constructor.can_init_directly;
            },
            else => return false,
        }
    }

    pub fn runtimeInitNeedsDeinit(self: Value) bool {
        return self == .string;
    }

    pub fn parse(arena: Allocator, value: []const u8, ctx: *const Context) !Value {
        if (value.len == 0 or std.mem.eql(u8, value, "null")) {
            return .null;
        }

        if (std.mem.eql(u8, value, "\"\"") or std.mem.eql(u8, value, "&\"\"")) {
            return .null;
        }
        if (value[0] == '"') {
            return .{ .string = try std.zig.string_literal.parseAlloc(arena, value) };
        }
        if (std.mem.startsWith(u8, value, "&\"") and value[value.len - 1] == '"') {
            return .{ .string_name = try std.zig.string_literal.parseAlloc(arena, value[1..]) };
        }

        if (std.mem.eql(u8, value, "true")) {
            return .{ .boolean = true };
        }
        if (std.mem.eql(u8, value, "false")) {
            return .{ .boolean = false };
        }

        if (value[value.len - 1] == ')') {
            if (std.mem.indexOf(u8, value, "(")) |index| {
                const c_name = value[0..index];
                const c_type = try Type.from(arena, c_name, false, ctx);
                const args_slice = value[index + 1 .. value.len - 1];
                const args_count = std.mem.count(u8, args_slice, ",") + 1;

                var out_args: ?[]const []const u8 = null;
                if (args_slice.len > 0) {
                    const temp = try arena.alloc([]const u8, args_count);

                    var it = std.mem.splitScalar(u8, args_slice, ',');
                    var i: usize = 0;
                    while (it.next()) |raw_arg| : (i += 1) {
                        temp[i] = std.mem.trim(u8, raw_arg, " \t\r\n,");
                    }

                    out_args = temp;
                }

                return .{
                    .constructor = .{
                        .type = c_type,
                        .args = out_args orelse &.{},
                    },
                };
            }
        }

        return .{ .primitive = value };
    }
};

const std = @import("std");
const Allocator = std.mem.Allocator;

const Context = @import("../Context.zig");
const Type = Context.Type;
```

The decoded representation is intentional: it preserves UTF-8 and literal escapes, and later lets codegen emit a safe Zig string literal. Do not turn these values into `.primitive` snippets in `Function.zig`; that would bypass lifecycle handling and would not solve non-empty `String` semantics.

- [ ] **Step 5: Scope owned string-like defaults**

In `pkg/bindgen/codegen.zig`, update the existing runtime-default branch so owned `String` and `StringName` defaults are mutable and deinitialized only when bindgen created them:

```zig
if (param.needsRuntimeInit(ctx)) {
    const default_value = param.default.?;
    try w.print("{s} actual_{s} = opt.{s} orelse ", .{
        if (default_value.runtimeInitNeedsDeinit()) "var" else "const",
        param.name,
        param.name,
    });
    try writeValue(w, default_value, ctx);
    try w.writeLine(";");
    if (default_value.runtimeInitNeedsDeinit()) {
        try w.printLine("defer if (opt.{0s} == null) actual_{0s}.deinit();", .{param.name});
    }
}
```

Replace `writeValue` so `String` and `StringName` become owned scoped values when the runtime-default branch calls it:

```zig
fn writeValue(w: *CodeWriter, value: Context.Value, ctx: *const Context) !void {
    switch (value) {
        .null => try w.writeAll("null"),
        .string => |s| try w.print("String.fromNullTerminatedUtf8(\"{f}\")", .{std.zig.fmtString(s)}),
        .string_name => |s| try w.print("StringName.fromNullTerminatedUtf8(\"{f}\")", .{std.zig.fmtString(s)}),
        .boolean => |b| try w.print("{}", .{b}),
        .primitive => |p| try w.writeAll(p),
        .constructor => |c| {
            const type_name = c.type.getName().?;
            const builtin = ctx.builtins.get(type_name) orelse std.debug.panic("Unsupported constructor: {s}", .{type_name});
            if (builtin.findConstructorByArgumentCount(c.args.len)) |function| {
                try w.print("{s}.{s}(", .{ builtin.name, function.name });

                for (c.args, 0..) |arg, i| {
                    const pval = Context.Constant.replacements.get(arg) orelse arg;
                    try w.writeAll(pval);
                    if (i != c.args.len - 1) {
                        try w.writeAll(", ");
                    }
                }
                try w.writeAll(")");
            } else {
                std.debug.panic("Unsupported constructor: {s}", .{type_name});
            }
        },
    }
}
```

Leave `optNullMaterializer` unchanged. Non-empty `String` and `StringName` values use the scoped runtime path; empty values continue to use `.init()` and the existing conditional `deinit()` path.

- [ ] **Step 6: Format and run the full verification suite**

Run:

```bash
mise exec -- zig fmt pkg/bindgen/Context/value.zig pkg/bindgen/codegen.zig test/codegen/root.zig
mise exec -- zig build test
```

Expected: formatting succeeds; all unit, generated-binding, and Godot integration tests pass, including the three new regressions and the existing empty `String`/`Array` tests.

- [ ] **Step 7: Inspect generated code and the final Jujutsu diff**

Run:

```bash
mise exec -- zig build
grep -n -A18 -B4 "pub fn playStream" src/class/audio_stream_playback_polyphonic.zig
grep -n -A14 -B4 "pub fn lpad" src/builtin/string.zig
jj --no-pager diff --git
jj st
```

Expected generated shape:

```zig
bus: ?StringName = null
var actual_bus = opt.bus orelse StringName.fromNullTerminatedUtf8("Master");
defer if (opt.bus == null) actual_bus.deinit();

character: ?String = null
var actual_character = opt.character orelse String.fromNullTerminatedUtf8(" ");
defer if (opt.character == null) actual_character.deinit();
```

`String.lpad` must keep `character: ?String = null`, then materialize `String.fromNullTerminatedUtf8(" ")` into `actual_character` and conditionally deinitialize it. Empty `String`/`StringName` methods must continue to use the existing nullable `.init()` materializer. The tracked diff must contain only `pkg/bindgen/Context/value.zig`, `pkg/bindgen/codegen.zig`, and `test/codegen/root.zig` (plus `PLAN.md`, which belongs to the planning handoff); ignored generated files must not appear.

- [ ] **Step 8: Finish the working-copy commit without publishing it**

Run:

```bash
jj st
jj --no-pager diff --git
```

Expected: one described, focused working-copy commit with the tested issue #86 fix. Do not push or create a pull request. Report changed files, commands and exit codes, observed generated snippets, and any residual risk.

## Verification

- Establish red: the new helper that calls `AudioStreamPlaybackPolyphonic.playStream(stream, .{})` must fail before the fix because `&"Master"` is not a `StringName`.
- Exercise semantics: omitting `String.lpad`’s non-empty `" "` default must produce the same value as the declared single-space default; retain this assertion even if the current Godot runtime happens to normalize an empty argument.
- Run `mise exec -- zig fmt pkg/bindgen/Context/value.zig pkg/bindgen/codegen.zig test/codegen/root.zig`.
- Run `mise exec -- zig build test` and require all bindgen, generated-binding, and Godot integration tests to pass.
- Run `mise exec -- zig build`, then inspect the ignored generated `src/class/audio_stream_playback_polyphonic.zig` and `src/builtin/string.zig` output: non-empty `StringName` and `String` defaults must be scoped and cleaned up; empty defaults must retain nullable omission markers and method-body cleanup.
- Inspect `jj --no-pager diff --git`; only the three handwritten source/test files above plus this plan should differ, and no generated output should be committed.

## Work-agent handoff prompt

After approving this plan, paste the following exact prompt into the **Work** agent:

```text
The plan in PLAN.md is approved. Read /tmp/gdzig-issue-86-bench-brief.md and PLAN.md, then implement Task 1 exactly in the current Jujutsu workspace. Use the subagent-driven-development and test-driven-development skills, follow the repository instructions, and keep the implementation test-first. Start by checking jj status and describing the existing working-copy revision as specified in the plan. Do not edit PLAN.md, create another workspace, push, or create a pull request. Run every verification command in the plan, inspect the generated playStream and lpad code, and finish by reporting changed files, command exit codes, generated-code evidence, and residual risks. Stop and ask me before any scope or architecture change.
```
