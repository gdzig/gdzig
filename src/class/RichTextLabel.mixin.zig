// @mixin start

/// Adds an inline image. Godot 4.6 truncates dimensions to integers and maps
/// image_unit_em to percent, since it only supports pixel and percent units.
pub fn addImage(self: *Self, p_image: *gdzig.class.Texture2d, opt: struct {
    width: f64 = 0,
    height: f64 = 0,
    color: gdzig.builtin.Color = .initRGBA(1, 1, 1, 1),
    inline_align: gdzig.global.InlineAlignment = @fromBackingInt(@intCast(5)),
    region: gdzig.builtin.Rect2 = .initXYWidthHeight(0, 0, 0, 0),
    key: ?Variant = null,
    pad: bool = false,
    tooltip: ?gdzig.builtin.String = null,
    width_unit: Self.ImageUnit = @fromBackingInt(@intCast(0)),
    height_unit: Self.ImageUnit = @fromBackingInt(@intCast(0)),
    alt_text: ?gdzig.builtin.String = null,
}) void {
    var actual_key: Variant = opt.key orelse .nil;
    defer if (opt.key == null) actual_key.deinit();
    var actual_tooltip: gdzig.builtin.String = opt.tooltip orelse .init();
    defer if (opt.tooltip == null) actual_tooltip.deinit();
    var actual_alt_text: gdzig.builtin.String = opt.alt_text orelse .init();
    defer if (opt.alt_text == null) actual_alt_text.deinit();
    const modern = gdzig.version.gte(.@"4.7");
    const alignment: i64 = @backingInt(opt.inline_align);
    const width_unit: i64 = @backingInt(opt.width_unit);
    const height_unit: i64 = @backingInt(opt.height_unit);
    // Do not convert dimensions on the modern path, which accepts all f64 values.
    const legacy_width: i64 = if (modern) 0 else @intFromFloat(opt.width);
    const legacy_height: i64 = if (modern) 0 else @intFromFloat(opt.height);
    const legacy_width_percent = opt.width_unit != .image_unit_pixel;
    const legacy_height_percent = opt.height_unit != .image_unit_pixel;
    const args = [_]c.GDExtensionConstTypePtr{
        @ptrCast(&p_image),
        if (modern) @ptrCast(&opt.width) else @ptrCast(&legacy_width),
        if (modern) @ptrCast(&opt.height) else @ptrCast(&legacy_height),
        @ptrCast(&opt.color),
        @ptrCast(&alignment),
        @ptrCast(&opt.region),
        @ptrCast(&actual_key),
        @ptrCast(&opt.pad),
        @ptrCast(&actual_tooltip),
        if (modern) @ptrCast(&width_unit) else @ptrCast(&legacy_width_percent),
        if (modern) @ptrCast(&height_unit) else @ptrCast(&legacy_height_percent),
        @ptrCast(&actual_alt_text),
    };
    if (addImage_ptr == null) {
        const hash: i64 = if (modern) 1980227702 else rich_text_image_compat.rich_text_label_add_image;
        addImage_ptr = raw.classdbGetMethodBind(@ptrCast(&StringName.fromComptimeLatin1("RichTextLabel")), @ptrCast(&StringName.fromComptimeLatin1("add_image")), hash);
    }
    raw.objectMethodBindPtrcall(addImage_ptr, @ptrCast(self), @ptrCast(&args), null);
}
var addImage_ptr: c.GDExtensionMethodBindPtr = null;

/// Updates images matching key, changing only fields selected by mask.
/// Godot 4.6 truncates dimensions and maps image_unit_em to percent.
pub fn updateImage(self: *Self, p_key: Variant, p_mask: Self.ImageUpdateMask, p_image: *gdzig.class.Texture2d, opt: struct {
    width: f64 = 0,
    height: f64 = 0,
    color: gdzig.builtin.Color = .initRGBA(1, 1, 1, 1),
    inline_align: gdzig.global.InlineAlignment = @fromBackingInt(@intCast(5)),
    region: gdzig.builtin.Rect2 = .initXYWidthHeight(0, 0, 0, 0),
    pad: bool = false,
    tooltip: ?gdzig.builtin.String = null,
    width_unit: Self.ImageUnit = @fromBackingInt(@intCast(0)),
    height_unit: Self.ImageUnit = @fromBackingInt(@intCast(0)),
}) void {
    var actual_tooltip: gdzig.builtin.String = opt.tooltip orelse .init();
    defer if (opt.tooltip == null) actual_tooltip.deinit();
    const modern = gdzig.version.gte(.@"4.7");
    const mask: i64 = @as(u32, @bitCast(p_mask));
    const alignment: i64 = @backingInt(opt.inline_align);
    const width_unit: i64 = @backingInt(opt.width_unit);
    const height_unit: i64 = @backingInt(opt.height_unit);
    const legacy_width: i64 = if (modern) 0 else @intFromFloat(opt.width);
    const legacy_height: i64 = if (modern) 0 else @intFromFloat(opt.height);
    const legacy_width_percent = opt.width_unit != .image_unit_pixel;
    const legacy_height_percent = opt.height_unit != .image_unit_pixel;
    const args = [_]c.GDExtensionConstTypePtr{
        @ptrCast(&p_key),                                              @ptrCast(&mask),                                                        @ptrCast(&p_image),
        if (modern) @ptrCast(&opt.width) else @ptrCast(&legacy_width), if (modern) @ptrCast(&opt.height) else @ptrCast(&legacy_height),        @ptrCast(&opt.color),
        @ptrCast(&alignment),                                          @ptrCast(&opt.region),                                                  @ptrCast(&opt.pad),
        @ptrCast(&actual_tooltip),                                     if (modern) @ptrCast(&width_unit) else @ptrCast(&legacy_width_percent), if (modern) @ptrCast(&height_unit) else @ptrCast(&legacy_height_percent),
    };
    if (updateImage_ptr == null) {
        const hash: i64 = if (modern) 202998225 else rich_text_image_compat.rich_text_label_update_image;
        updateImage_ptr = raw.classdbGetMethodBind(@ptrCast(&StringName.fromComptimeLatin1("RichTextLabel")), @ptrCast(&StringName.fromComptimeLatin1("update_image")), hash);
    }
    raw.objectMethodBindPtrcall(updateImage_ptr, @ptrCast(self), @ptrCast(&args), null);
}
var updateImage_ptr: c.GDExtensionMethodBindPtr = null;

const rich_text_image_compat = @import("../godot_4_6.zig");

// @mixin stop

const gdzig = @import("gdzig");
const c = gdzig.c;
const raw = &gdzig.raw;
const Self = gdzig.class.RichTextLabel;
const StringName = gdzig.builtin.StringName;
const Variant = gdzig.builtin.Variant;
