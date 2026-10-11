# Inherited method forwarders

## Scope and preservation rules

Option 1 replaces eligible inherited method bodies with calls to the declaring class. The generator uses existing `Function.base` provenance and ancestor imports. It adds no shared method-bind helper or runtime export.

Each child keeps its public signature, receiver mutability, return type and local named options. Required arguments retain their order. A target-context-typed field literal converts nominal options without changing defaults or null sentinels. Ordinary varargs call the declaring ordinary method, so the packed-array allocation guard still applies. Alloc varargs call the corresponding Alloc method.

Full inherited documentation, Markdown targets and ordinary/Alloc warnings remain intact. They are not replaced with owner references. These paths retain local bodies:

- All methods on non-singleton descendants of singleton classes, including static and Alloc methods.
- Legacy-range and version-dispatch methods, private delegates, mixin overrides and per-Self adapters.
- Singleton ordinary-vararg wrappers, which remain guard-first.
- Targets that would substitute another singleton storage owner.

Actual Engine/Os forwarders retain their own storage, exact API lookup names and no-receiver signatures. Method-bind hash selection/order, compatibility minima, null handling and retry policy are unchanged.

## Verification on October 11, 2026

The fresh baseline is `746c4c4b7b56da7b14f26ad2d13099e539fb9e3f`. The measured production source is `41f2d77c2f78769656a2ddf38c0b827fb840a573`, including emitter commit `c522fa83`. Tests use Zig 0.17.0, Godot 4.7.2 (`ed1daf0bf`) and native aarch64 macOS. Runtime coverage uses float precision with 64-bit architecture. Double/64 coverage is generation and compilation only.

Fresh float/64 and double/64 comparisons each cover 1,098 generated Zig files, 1,036 class files and 187,112 named functions. They compare declarations, signatures, nominal options, docs, constants and imports. Private bodies and bind caches are checked separately. Non-class generated files match byte-for-byte. Six mutations of actual generated text confirm that the comparison detects contract changes. These checks establish structural preservation, not engine coverage.

Four missing-forwarder assertions failed before the implementation. The expanded suite then passed 46 generator tests and 18 real Godot tests. Runtime tests cover Node3d names, enums, typed/default options, varargs, packed payloads, Engine/Os initialization/reuse and warmed physics descendants.

Compile-only controls use the actual generated module. The negative control reports the allocation guard through Node3d to Object. Alloc packed-array and ordinary prewrapped-Variant controls compile. Undefined fixture pointers are never executed.

| Current-engine check | Result |
| --- | --- |
| Expanded generator/codegen suite | 48/48 steps, 64/64 tests |
| Focused integration matrix | 136/136 steps, 54/54 tests |
| Full project tests | 240/240 steps, 149/149 reported tests |
| Docs | 35/35 steps |
| Double/64 compile check | 34/34 steps |
| Default, 4.6 and 4.7 compatibility floors on Godot 4.7.2 | Each 105/105 steps, 32/32 tests |

Engine suites use the real loaded-extension IPC harness. Cached host entries remain labeled cached. Codegen tests start after engine initialization so physics singletons exist. Warmed-descendant tests do not establish cold-call safety.

Eight actual ZLS 0.16 hover responses preserve sampled signatures, prose, warnings and remote Markdown targets. Only local navigation paths/line numbers differ. Definitions still lead to the local wrapper. Secondary unknown types in standalone snapshots are not configured-project type validation.

## Measurements

The two source archives, tools, API/header files, package pins and generated inputs were frozen. Task-owned builds ran serially with `-j2`. Build caches used `ZIG_GLOBAL_CACHE_DIR` and separate local/global paths for each cold/warm pair. Cold means compilation-cache-cold, not filesystem-cache-cold. Immutable package sources were seeded, never compiler outputs. Source hashing ran outside timings and warmed the filesystem.

The 1,036-class corpus shrank from 205,354,801 to 127,562,549 bytes: **77,792,252 bytes less, or 37.881876%**. Newline counts fell from 3,213,750 to 2,054,573. Builtins remain byte-identical. Retaining full docs and conservative exclusions reduces savings relative to the discarded spike projection.

Structural counts are 148,426 forwarded public entrypoints, including 4,231 Alloc entrypoints, 29,302 retained local public entrypoints and 9,384 unchanged private named functions. These counts are not runtime coverage.

Each timing cell below has three successful repetitions. Values are median seconds, with minimum to maximum in parentheses. Generation includes its internal formatting. The separate formatting checks are controls, not additional generation samples. Example check is N/A because the example has no check target.

| Workflow | Baseline | Production |
| --- | --- | --- |
| Generation | 19.8360 (19.4980-20.0040) | 17.9272 (17.8089-17.9805) |
| Root build, cold | 82.9866 (81.6561-85.2993) | 81.6593 (79.0188-83.9746) |
| Root build, warm | 1.4215 (1.3462-1.8940) | 1.4049 (1.2475-1.4916) |
| Root check, cold | 83.5743 (81.5053-84.7856) | 81.1221 (78.8156-81.7662) |
| Root check, warm | 0.5311 (0.4947-0.5398) | 0.5810 (0.4834-0.6375) |
| Example build, cold | 81.1445 (80.3141-81.5332) | 78.2939 (77.9687-78.5761) |
| Example build, warm | 0.5374 (0.5265-0.5489) | 0.5439 (0.5402-0.5520) |
| Formatting control | 1.4645 (1.4598-1.4817) | 0.8257 (0.8149-0.8701) |

Generation's observed median is 9.6232% lower. Warm check and example medians are slightly higher. Several build/check ranges overlap. These chronological single-machine observations do not establish universal speedups. Other user/agent activity, thermal state and filesystem caching were uncontrolled.

Cache values are median allocated KiB **after each cold/warm pair**, not peak usage:

| Workflow | Baseline local / global / combined | Production local / global / combined |
| --- | --- | --- |
| Root build | 1,093,432 / 91,892 / 1,185,324 | 656,856 / 91,892 / 748,748 |
| Root check | 1,095,840 / 91,892 / 1,187,732 | 656,856 / 91,892 / 748,748 |
| Example build | 874,800 / 90,388 / 965,188 | 520,216 / 90,388 / 610,604 |

One matching ReleaseFast example build per row produced real arm64 Mach-O libraries. Both use float precision, 64-bit architecture and the default matching strip policy. Baseline size is 608,848 bytes, production size 591,968 bytes, a reduction of 16,880 bytes. This is binary-size evidence, not a three-repeat release-build timing claim.

The final audit covers 42 repeated performance samples, six formatting controls and two binary builds. One executor timeout at 600 seconds interrupted production root-build repetition 3. Its partial cache/log and native exit 124 remain retained as an infrastructure discard, not a compiler failure or eligible timing. The pair was rerun with genuinely new local/global paths. All completed commands passed. The audit verifies unique repetitions, exact paired inputs/commands, task-owned chronology, distinct cold caches and copied binary hashes.

## Known limitation and unmet release criteria

**Cold singleton-descendant calls remain unsafe on both baseline and production.** Four bounded real-engine witnesses reset PhysicsServer2d/3d owner storage to null. Each emits the pre-call marker, reports signal 11 in the actual descendant wrapper, then exits -6 without a post-call marker. Exact engine, library, witness and compiled-module hashes are retained.

Cold observation is complete and behavior-preservation parity is verified. The crashes are not successful calls or a new regression. Option 1 deliberately keeps this local path without adding initialization.

Older-engine runtime coverage is blocked because no supported 4.6 executable is available. Compatibility-floor tests on 4.7.2 do not replace it. Local CodeEdit.queueFree rendering was observed, but clickable destinations and rendered warning-page comparison remain blocked. The browser bridge is absent, the task window became inaccessible to AX and AppleEvents JavaScript is disabled. No browser/security setting was changed.

The older-engine and clickable-navigation criteria require Simon's supply, authorization or explicit release disposition. No overall release approval is inferred.

## Retained evidence

Host-local evidence root: `/Users/sh/.jcode/scratch/gdzig-285-production-20261011T0927`.

- `task-records/`, `integration-3.log` and `matrix-results.json`: native exits, commands, source identities and actual test summaries.
- `followthrough-results.json`, final float/double inventory reports and `inventory-parser-controls.json`: fresh archive/generation/formatting and contract checks.
- `packed-array-controls.json`, `hover-comparison.json`, `rendered-navigation-attempt.md` and `cold-witness-manifest.json`: guard, hover, partial navigation and real cold-call evidence.
- `performance/raw.json`, `aggregate.json`, `summary-metrics.json`, `metadata.json`, source/tool manifests and `acceptance-audit.json`: every measurement, input hash, cache metric and discard.
- `performance/*-ReleaseFast-libexample.dylib`: copied binaries with hashes in the raw records.

Plans, probes, benchmark drivers and generated bindings remain outside maintained source changes.
