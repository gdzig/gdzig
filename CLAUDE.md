# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

### Build Commands
- `zig build` - Build the gdzig library and bindgen executable
- `zig build bindgen` - Build only the gdzig_bindgen executable
- `zig build generated` - Run bindgen to generate builtin/class code from Godot API
- `zig build docs` - Generate and install documentation to zig-out/docs
- `zig build test` - Run all tests (both bindgen and module tests)

### Build Options
- `-Dgodot=<path>` - Path to Godot binary (default: "godot")
- `-Dprecision=<float|double>` - Floating point precision (default: "float")
- `-Darch=<32|64>` - Architecture bits (default: "64")
- `-Dheaders=<GENERATED|VENDORED|DEPENDENCY|path>` - Source for Godot headers (default: GENERATED)
- `-Dtarget=<target>` - Cross-compilation target
- `-Doptimize=<Debug|ReleaseSafe|ReleaseFast|ReleaseSmall>` - Optimization mode

### Example Project Commands (from example/ directory)
- `zig build run` - Build example and run with Godot
- `zig build load` - Load the example project in Godot editor

### Documentation Commands
- `zigdoc <symbol>` - Show documentation for Zig standard library symbols and imported modules
  - Examples:
    - `zigdoc std.ArrayList` - Show ArrayList documentation
    - `zigdoc std.zig.Ast` - Show AST documentation
    - `zigdoc std.zig.Ast.parse` - Show documentation for specific function
  - Can access any module imported in build.zig, including third-party dependencies
  - Use `zigdoc --dump-imports` to see available modules

## Architecture

### Core Components

**gdzig_bindgen/** - Code generator that parses Godot's extension_api.json and generates Zig bindings
- `Context.zig` - Central context that builds the codegen model from Godot API
- `GodotApi.zig` - Parser for extension_api.json
- `codegen.zig` - Main code generation logic that writes out all binding files
- `CodeWriter.zig` - Utility for writing formatted Zig code with proper indentation
- `Context/*.zig` - Type definitions for Godot concepts (Class, Function, Signal, Property, etc.)

**gdzig/** - Runtime library and generated bindings
- `gdzig.zig` - Main entry point exposing all public APIs
- `builtin/*.zig` - Generated bindings for Godot builtin types (Vector2/3, String, Array, etc.)
- `class/*.zig` - Generated bindings for Godot classes (Node, Object, RefCounted, etc.)
- `global/*.zig` - Generated global enums and constants
- Core runtime modules:
  - `interface.zig` - Static interface to GDExtension C API functions
  - `heap.zig` - Integration with Godot's memory allocator
  - `object.zig` - Object lifecycle and inheritance support
  - `register.zig` - Class, method, and signal registration
  - `string.zig` - String conversion utilities
  - `support.zig` - Method binding and constructor utilities
  - `meta.zig` - Type introspection and class hierarchy

### Code Generation Flow

1. **Parse Phase**: `GodotApi.parseFromReader()` reads extension_api.json
2. **Context Build**: `Context.build()` transforms raw API into codegen model:
   - Builds symbol lookup tables
   - Parses GDExtension headers
   - Collects class hierarchies and dependencies
   - Resolves type mappings for current architecture/precision
3. **Generation Phase**: `codegen.generate()` writes binding files:
   - `writeBuiltins()` - Core value types
   - `writeClasses()` - Class hierarchy
   - `writeGlobals()` - Enums and constants
   - `writeInterface()` - C API function pointers
   - `writeModules()` - Utility function modules
4. **Format**: Auto-formats generated code with `zig fmt`

### Type System

- Uses Zig 0.15.1 features including new Reader/Writer interfaces
- Builtin types map to Zig equivalents based on precision setting (float/double)
- Classes use oopz dependency for OOP-style inheritance
- Supports both 32-bit and 64-bit architectures
- Automatic type conversions between Zig and Godot types

### Extension Entry Point

Extensions define an entry point using `gdzig.entrypoint()` or `gdzig.entrypointWithUserdata()`:
- Specify initialization/deinitialization callbacks per level (core, servers, scene, editor)
- Register custom classes, methods, properties, and signals
- Handle object lifecycle through Godot's reference counting

## Dependencies

- **case** - Case conversion utilities
- **bbcodez** - BBCode parsing for documentation
- **temp** - Temporary file utilities
- **oopz** - OOP abstractions for Zig
- **godot_cpp** - Optional source for Godot headers

## Current Status

- Migrating to Zig 0.15.1 with updated Reader/Writer interfaces
- Active development on branch `zig-0.15.1`
- Main branch for PRs: `master`
- To see the generated code: run `zig build generated`. The generated code will be in the `gdzig/` folder.
