// @mixin start

/// Adds an inline image using the selected size units.
/// On Godot 4.6, fractional sizes truncate to integers and em units behave as percent.
pub fn addImage(self: *Self, p_image: *gdzig.class.Texture2d, opt: AddImageOptions) void {
    if (gdzig.version.gte(.@"4.7")) return self.addImageRaw(p_image, opt);
    // Legacy binds need i64 dimensions and bool percent flags. Named options
    // and the modern delegate are generated from the vendored API metadata.
    var actual_key: Variant = opt.key orelse .nil;
    defer if (opt.key == null) actual_key.deinit();
    var actual_tooltip: gdzig.builtin.String = opt.tooltip orelse .init();
    defer if (opt.tooltip == null) actual_tooltip.deinit();
    var actual_alt_text: gdzig.builtin.String = opt.alt_text orelse .init();
    defer if (opt.alt_text == null) actual_alt_text.deinit();
    const alignment: i64 = @backingInt(opt.inline_align);
    const width: i64 = @intFromFloat(opt.width);
    const height: i64 = @intFromFloat(opt.height);
    const width_percent = opt.width_unit != .image_unit_pixel;
    const height_percent = opt.height_unit != .image_unit_pixel;
    const args = [_]c.GDExtensionConstTypePtr{
        @ptrCast(&p_image),        @ptrCast(&width),         @ptrCast(&height),         @ptrCast(&opt.color),
        @ptrCast(&alignment),      @ptrCast(&opt.region),    @ptrCast(&actual_key),     @ptrCast(&opt.pad),
        @ptrCast(&actual_tooltip), @ptrCast(&width_percent), @ptrCast(&height_percent), @ptrCast(&actual_alt_text),
    };
    if (addImage_legacy_ptr == null) {
        addImage_legacy_ptr = raw.classdbGetMethodBind(@ptrCast(&StringName.fromComptimeLatin1("RichTextLabel")), @ptrCast(&StringName.fromComptimeLatin1("add_image")), rich_text_image_compat.godot_4_6.rich_text_label_add_image);
    }
    raw.objectMethodBindPtrcall(addImage_legacy_ptr, @ptrCast(self), @ptrCast(&args), null);
}
var addImage_legacy_ptr: c.GDExtensionMethodBindPtr = null;

/// Updates images matching key, changing only fields selected by mask.
/// On Godot 4.6, fractional sizes truncate to integers and em units behave as percent.
pub fn updateImage(self: *Self, p_key: Variant, p_mask: Self.ImageUpdateMask, p_image: *gdzig.class.Texture2d, opt: UpdateImageOptions) void {
    if (gdzig.version.gte(.@"4.7")) return self.updateImageRaw(p_key, p_mask, p_image, opt);
    var actual_tooltip: gdzig.builtin.String = opt.tooltip orelse .init();
    defer if (opt.tooltip == null) actual_tooltip.deinit();
    const mask: i64 = @as(u32, @bitCast(p_mask));
    const alignment: i64 = @backingInt(opt.inline_align);
    const width: i64 = @intFromFloat(opt.width);
    const height: i64 = @intFromFloat(opt.height);
    const width_percent = opt.width_unit != .image_unit_pixel;
    const height_percent = opt.height_unit != .image_unit_pixel;
    const args = [_]c.GDExtensionConstTypePtr{
        @ptrCast(&p_key),   @ptrCast(&mask),           @ptrCast(&p_image),       @ptrCast(&width),
        @ptrCast(&height),  @ptrCast(&opt.color),      @ptrCast(&alignment),     @ptrCast(&opt.region),
        @ptrCast(&opt.pad), @ptrCast(&actual_tooltip), @ptrCast(&width_percent), @ptrCast(&height_percent),
    };
    if (updateImage_legacy_ptr == null) {
        updateImage_legacy_ptr = raw.classdbGetMethodBind(@ptrCast(&StringName.fromComptimeLatin1("RichTextLabel")), @ptrCast(&StringName.fromComptimeLatin1("update_image")), rich_text_image_compat.godot_4_6.rich_text_label_update_image);
    }
    raw.objectMethodBindPtrcall(updateImage_legacy_ptr, @ptrCast(self), @ptrCast(&args), null);
}
var updateImage_legacy_ptr: c.GDExtensionMethodBindPtr = null;

const rich_text_image_compat = @import("../compat/method_hashes.zig");

// @mixin stop

const gdzig = @import("gdzig");
const c = gdzig.c;
const raw = &gdzig.raw;
const Self = gdzig.class.RichTextLabel;
const AddImageOptions = Self.AddImageOptions;
const UpdateImageOptions = Self.UpdateImageOptions;
const StringName = gdzig.builtin.StringName;
const Variant = gdzig.builtin.Variant;
