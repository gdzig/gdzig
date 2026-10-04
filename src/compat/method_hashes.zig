//! Method-bind hashes for runtime ABI adaptation.
//! Godot 4.6 signatures were verified against a development-time 4.6.3 API dump
//! and the vendored 4.7 compatibility lists. Modern signatures come from the
//! vendored API. Hash lookup alone cannot convert the changed argument types.

pub const godot_4_6 = struct {
    /// is_class(String) -> bool, const.
    pub const object_is_class: i64 = 3927539163;
    /// Integer dimensions and bool percent flags, with alt_text as argument 12.
    pub const rich_text_label_add_image: i64 = 1390915033;
    /// Integer dimensions and bool percent flags.
    pub const rich_text_label_update_image: i64 = 6389170;
};

pub const godot_4_7 = struct {
    /// is_class(StringName) -> bool, const.
    pub const object_is_class: i64 = 2619796661;
    /// Floating-point dimensions and ImageUnit enums.
    pub const rich_text_label_add_image: i64 = 1980227702;
    /// Floating-point dimensions and ImageUnit enums.
    pub const rich_text_label_update_image: i64 = 202998225;
};
