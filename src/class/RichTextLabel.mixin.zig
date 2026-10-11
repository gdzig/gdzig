// @mixin start

// Old dimensions are integers, and the old unit flags distinguish only pixels
// from percentages. The generated dispatcher owns range and bind selection.
fn addImage_4_6(self: *Self, p_image: *gdzig.class.Texture2d, opt: AddImageOptions) void {
    var key: Variant = opt.key orelse .nil;
    defer if (opt.key == null) key.deinit();
    var tooltip: gdzig.builtin.String = opt.tooltip orelse .init();
    defer if (opt.tooltip == null) tooltip.deinit();
    var alt_text: gdzig.builtin.String = opt.alt_text orelse .init();
    defer if (opt.alt_text == null) alt_text.deinit();

    self.addImage_4_6_legacy(
        p_image,
        @intFromFloat(opt.width),
        @intFromFloat(opt.height),
        opt.color,
        opt.inline_align,
        opt.region,
        key,
        opt.pad,
        tooltip,
        opt.width_unit != .image_unit_pixel,
        opt.height_unit != .image_unit_pixel,
        alt_text,
    );
}

fn updateImage_4_6(
    self: *Self,
    p_key: Variant,
    p_mask: Self.ImageUpdateMask,
    p_image: *gdzig.class.Texture2d,
    opt: UpdateImageOptions,
) void {
    var tooltip: gdzig.builtin.String = opt.tooltip orelse .init();
    defer if (opt.tooltip == null) tooltip.deinit();

    self.updateImage_4_6_legacy(
        p_key,
        p_mask,
        p_image,
        @intFromFloat(opt.width),
        @intFromFloat(opt.height),
        opt.color,
        opt.inline_align,
        opt.region,
        opt.pad,
        tooltip,
        opt.width_unit != .image_unit_pixel,
        opt.height_unit != .image_unit_pixel,
    );
}

// @mixin stop

const gdzig = @import("gdzig");
const Self = gdzig.class.RichTextLabel;
const AddImageOptions = Self.AddImageOptions;
const UpdateImageOptions = Self.UpdateImageOptions;
const Variant = gdzig.builtin.Variant;
