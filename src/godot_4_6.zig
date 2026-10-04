//! Godot 4.6 method-bind hashes for signatures that need marshaling shims.
//! Verified against a development-time Godot 4.6.3 extension_api.json dump.
//! These are also members of the vendored 4.7 hash_compatibility lists.
//! JSON omits some default Variant backing types, so full hash recomputation
//! cannot reliably replace these named constants.

/// is_class(String) -> bool, const.
pub const object_is_class: i64 = 3927539163;
/// add_image uses integer dimensions and bool size_in_percent flags.
/// alt_text remains the twelfth argument, including on Godot 4.6.
pub const rich_text_label_add_image: i64 = 1390915033;
/// update_image uses integer dimensions and bool size_in_percent flags.
pub const rich_text_label_update_image: i64 = 6389170;
