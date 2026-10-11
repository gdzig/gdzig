//! Representative public shim exports keep optimized ABI inspection nonvacuous.
/// Install observable runtime dispatch so the optimizer cannot discard ptrcalls.
pub export fn gdzig_compatibility_minimum_install_dispatch(
    table: *const @TypeOf(gdzig.raw),
) callconv(.c) void {
    gdzig.raw = table.*;
}

/// Inspect Object's public legacy-layout shim on an ordinary instance.
pub export fn gdzig_compatibility_minimum_is_class(
    node: *gdzig.class.Node,
    name: *const gdzig.builtin.StringName,
) callconv(.c) bool {
    return node.isClass(name.*);
}

/// Inspect the inherited singleton delegate without changing its original owner.
pub export fn gdzig_compatibility_minimum_singleton_is_class(
    name: *const gdzig.builtin.StringName,
) callconv(.c) bool {
    return gdzig.class.Engine.isClass(name.*);
}

/// Inspect the selected RichTextLabel add-image argument layout.
pub export fn gdzig_compatibility_minimum_add_image(
    label: *gdzig.class.RichTextLabel,
    image: *gdzig.class.Texture2d,
    options: *const gdzig.class.RichTextLabel.AddImageOptions,
) callconv(.c) void {
    label.addImage(image, options.*);
}

/// Inspect update-image's selected flags and historical argument layout.
pub export fn gdzig_compatibility_minimum_update_image(
    label: *gdzig.class.RichTextLabel,
    image: *gdzig.class.Texture2d,
    options: *const gdzig.class.RichTextLabel.UpdateImageOptions,
) callconv(.c) void {
    var key: gdzig.builtin.Variant = .init(i64, 123);
    defer key.deinit();
    label.updateImage(key, .{ .update_size = true, .update_width_unit = true }, image, options.*);
}

/// Inspect the selected legacy-void versus modern-bool return layout.
pub export fn gdzig_compatibility_minimum_generate(
    translation: *gdzig.class.OptimizedTranslation,
    source: *gdzig.class.Translation,
) callconv(.c) bool {
    return translation.generate(source);
}

const gdzig = @import("gdzig");
