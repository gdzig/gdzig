//! Method-bind hashes for runtime ABI adaptation.
//! Godot 4.6 signatures were verified against a development-time 4.6.3 API dump.
//! Modern signatures and hashes are emitted from the vendored API into private
//! delegates. Only measured legacy anchors belong here. See
//! docs/runtime-compatibility-hashes.md for reproducible dump and membership audits.

pub const godot_4_6 = struct {
    /// is_class(String) -> bool, const.
    pub const object_is_class: i64 = 3927539163;
    /// Integer dimensions and bool percent flags, with alt_text as argument 12.
    pub const rich_text_label_add_image: i64 = 1390915033;
    /// Integer dimensions and bool percent flags.
    pub const rich_text_label_update_image: i64 = 6389170;
};
