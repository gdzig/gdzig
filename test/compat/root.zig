test "isClass marshals the runtime's class-name layout" {
    const node = gdzig.class.Node.init();
    defer node.destroy();
    try testing.expect(node.isClass(.fromComptimeLatin1("Node")));
    try testing.expect(node.isClass(.fromComptimeLatin1("Object")));
    try testing.expect(!node.isClass(.fromComptimeLatin1("Sprite2D")));
    // Exercise the cached bind too.
    try testing.expect(node.isClass(.fromComptimeLatin1("Node")));
}

test "isClass preserves singleton convenience signatures" {
    try testing.expect(gdzig.class.Engine.isClass(.fromComptimeLatin1("Engine")));
    try testing.expect(gdzig.class.Engine.isClass(.fromComptimeLatin1("Object")));
    try testing.expect(!gdzig.class.Engine.isClass(.fromComptimeLatin1("Node")));
    try testing.expect(gdzig.class.Os.isClass(.fromComptimeLatin1("OS")));
}

test "RichTextLabel images support pixel and percent units on both runtimes" {
    const image = gdzig.class.Image.create(8, 8, false, .format_rgba8) orelse return error.ImageCreationFailed;
    defer if (image.unreference()) gdzig.class.Object.upcast(image).destroy();
    image.fill(.initRGBA(1, 1, 1, 1));
    const texture = gdzig.class.ImageTexture.createFromImage(image) orelse return error.TextureCreationFailed;
    defer if (texture.unreference()) gdzig.class.Object.upcast(texture).destroy();
    const style = gdzig.class.StyleBoxEmpty.init();
    defer if (style.unreference()) gdzig.class.Object.upcast(style).destroy();
    const label = RichTextLabel.init();
    defer label.destroy();
    label.addThemeStyleboxOverride(.fromComptimeLatin1("normal"), gdzig.class.StyleBox.upcast(style));
    label.setScrollActive(false);
    label.setAutowrapMode(.autowrap_off);
    const main_loop = gdzig.class.Engine.getMainLoop() orelse return error.MissingMainLoop;
    const tree = gdzig.class.SceneTree.downcast(main_loop) orelse return error.MissingSceneTree;
    const root = tree.getRoot() orelse return error.MissingRoot;
    gdzig.class.Node.upcast(root).addChild(gdzig.class.Node.upcast(label), .{});
    label.setSize(.initXY(200, 200), .{});

    const key: Variant = .init(i64, 123);
    defer key.deinit();
    const units = [_]RichTextLabel.ImageUnit{ .image_unit_pixel, .image_unit_percent };
    for (units, 0..) |unit, i| {
        label.clear();
        label.addImage(gdzig.class.Texture2d.upcast(texture), .{
            .key = key,
            .width = 40,
            .height = 20,
            .width_unit = unit,
            .height_unit = unit,
        });
        // With no theme padding and a 200px label, 40% is 80px, not 40px.
        try testing.expectEqual(@as(i32, if (i == 0) 40 else 80), label.getContentWidth());
        try testing.expectEqual(@as(i32, 1), label.getTotalCharacterCount());
        label.updateImage(key, .{ .update_size = true, .update_width_unit = true }, gdzig.class.Texture2d.upcast(texture), .{
            .width = 60,
            .height = 30,
            .width_unit = unit,
            .height_unit = unit,
        });
        // This also fails if updateImage silently leaves the original size.
        try testing.expectEqual(@as(i32, if (i == 0) 60 else 120), label.getContentWidth());
        try testing.expectEqual(@as(i32, 1), label.getTotalCharacterCount());
        try testing.expectEqual(@as(i32, 1), label.getParagraphCount());
    }
}

test "OptimizedTranslation generate preserves messages and initializes legacy return" {
    const translation = gdzig.class.Translation.init();
    defer if (translation.unreference()) gdzig.class.Object.upcast(translation).destroy();
    const optimized = gdzig.class.OptimizedTranslation.init();
    defer if (optimized.unreference()) gdzig.class.Object.upcast(optimized).destroy();
    const source: StringName = .fromComptimeLatin1("hello");
    const destination: StringName = .fromComptimeLatin1("bonjour");
    translation.addMessage(source, destination, .{});
    const generated = optimized.generate(translation);
    try testing.expectEqual(gdzig.version.gte(.@"4.7"), generated);
    var result = optimized.getMessage(source, .{});
    defer result.deinit();
    try testing.expect(result.eql(destination));
}

const std = @import("std");
const testing = std.testing;

const gdzig = @import("gdzig");
const StringName = gdzig.builtin.StringName;
const Variant = gdzig.builtin.Variant;
const RichTextLabel = gdzig.class.RichTextLabel;
