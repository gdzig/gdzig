//! Compatibility shims for Zig APIs that change shape between the pinned
//! stable release and zig master. Build-script shims live in
//! build/compat.zig. See docs/adr/0001-zig-version-compat.md.
//!
//! Gates probe API *shape* (comptime `@hasDecl`/`@hasField`), not version
//! numbers, so they keep working across future releases until the old-shape
//! branch is deleted. When no skew exists this file is empty; add gated
//! helpers here when the next divergence appears. Discover live gates
//! with: git grep -E "comptime !?@has(Decl|Field)"
