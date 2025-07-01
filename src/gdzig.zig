//! These modules are generated directly from the Godot Engine's API documentation:
//!
//! - `builtin` - Core Godot value types: String, Vector2/3/4, Array, Dictionary, Color
//! - `class` - Godot class hierarchy: Object, Node, RefCounted, and all the related engine classes
//! - `global` - Global scope enumerations, flag structs, and constants
//!
//! Godot also exposes a suite of utility functions that we generate bindings for:
//!
//! - `general` - General-purpose utility functions like logging and more
//! - `math` - Mathematical utilities and constants from Godot's Math class
//! - `random` - Random number generation utilities
//!
//! For lower level access to the GDExtension APIs:
//!
//! - `interface` - A static instance of an `Interface`, populated at startup with pointers to the GDExtension header functions
//! - `c` - Raw C bindings to gdextension headers and types
//!
//! We also provide a framework around the generated code that helps you write your extension:
//!
//! - `debug` - Debug assertions and validation
//! - `heap` - Work with Godot's allocator
//! - `meta` - Type introspection and class hierarchy
//! - `object` - Object creation, destruction, and lifecycle management
//! - `register` - Class, method, plugin and signal registration
//! - `string` - String handling utilities and conversions
//! - `support` - Method binding and constructor utilities
//!

const std = @import("std");

// Bindgen modules
pub const Interface = @import("Interface.zig");
pub const builtin = @import("builtin.zig");
pub const class = @import("class.zig");
pub const general = @import("general.zig");
pub const global = @import("global.zig");
pub const math = @import("math.zig");
pub const random = @import("random.zig");

// Local modules
pub const c = @import("gdextension");
pub const debug = @import("debug.zig");
pub const heap = @import("heap.zig");
pub const meta = @import("meta.zig");
pub const object = @import("object.zig");
pub const register = @import("register.zig");
pub const string = @import("string.zig");
pub const support = @import("support.zig");

pub var interface: Interface = undefined;

// Re-exports
pub const connect = object.connect;
pub const registerClass = register.registerClass;
pub const registerMethod = register.registerMethod;
pub const registerPlugin = register.registerPlugin;
pub const registerSignal = register.registerSignal;
