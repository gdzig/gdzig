//! Compatibility shims for Zig APIs that changed shape between the pinned
//! stable release and zig master. See docs/adr/0001-zig-version-compat.md.
//!
//! Gates probe API *shape* (comptime `@hasDecl`/`@hasField`), not version
//! numbers, so they keep working across future releases until the old-shape
//! branch is deleted. Discover all gates with:
//! `git grep -E "comptime !?@has(Decl|Field)"`.
//!
//! No current shims — add gates here when stable/master skew appears.
