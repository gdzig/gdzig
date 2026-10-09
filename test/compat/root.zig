test "isClass marshals the runtime's class-name layout" {
    const node = gdzig.class.Node.init();
    defer node.destroy();
    try testing.expect(node.isClass(.fromComptimeLatin1("Node")));
    try testing.expect(node.isClass(.fromComptimeLatin1("Object")));
    try testing.expect(!node.isClass(.fromComptimeLatin1("Sprite2D")));
    // Exercise the cached bind too.
    try testing.expect(node.isClass(.fromComptimeLatin1("Node")));
    if (comptime @hasDecl(gdzig.class.Object, "isClass_4_6_legacy")) {
        if (gdzig.version.range(.@"4.6", .@"4.7")) {
            var old_name: gdzig.builtin.String = .fromLatin1("Node");
            defer old_name.deinit();
            const object = gdzig.class.Object.upcast(node);
            try testing.expect(object.isClass_4_6_legacy(old_name));
            try testing.expect(object.isClass_4_6_legacy(old_name));
        }
    }
}

test "isClass preserves singleton convenience signatures" {
    try testing.expect(gdzig.class.Engine.isClass(.fromComptimeLatin1("Engine")));
    try testing.expect(gdzig.class.Engine.isClass(.fromComptimeLatin1("Object")));
    try testing.expect(!gdzig.class.Engine.isClass(.fromComptimeLatin1("Node")));
    try testing.expect(gdzig.class.Os.isClass(.fromComptimeLatin1("OS")));
    if (comptime @hasDecl(gdzig.class.Engine, "isClass_4_6_legacy")) {
        if (gdzig.version.range(.@"4.6", .@"4.7")) {
            var engine_name: gdzig.builtin.String = .fromLatin1("Engine");
            defer engine_name.deinit();
            var os_name: gdzig.builtin.String = .fromLatin1("OS");
            defer os_name.deinit();
            try testing.expect(gdzig.class.Engine.isClass_4_6_legacy(engine_name));
            try testing.expect(gdzig.class.Os.isClass_4_6_legacy(os_name));
        }
    }
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

    // The public old layout takes positional pixel/percentage flags, not modern units.
    if (comptime @hasDecl(RichTextLabel, "addImage_4_6_legacy")) {
        if (gdzig.version.range(.@"4.6", .@"4.7")) {
            var empty: gdzig.builtin.String = .fromLatin1("");
            defer empty.deinit();
            label.clear();
            label.addImage_4_6_legacy(
                gdzig.class.Texture2d.upcast(texture),
                40,
                20,
                .initRGBA(1, 1, 1, 1),
                .inline_alignment_center,
                .initPositionSize(.initXY(0, 0), .initXY(0, 0)),
                key,
                false,
                empty,
                false,
                false,
                empty,
            );
            try testing.expectEqual(@as(i32, 40), label.getContentWidth());
            label.updateImage_4_6_legacy(
                key,
                .{ .update_size = true, .update_width_unit = true },
                gdzig.class.Texture2d.upcast(texture),
                60,
                30,
                .initRGBA(1, 1, 1, 1),
                .inline_alignment_center,
                .initPositionSize(.initXY(0, 0), .initXY(0, 0)),
                false,
                empty,
                true,
                false,
            );
            try testing.expectEqual(@as(i32, 120), label.getContentWidth());
            try testing.expectEqual(@as(i32, 1), label.getTotalCharacterCount());
        }
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
    try testing.expect(generated);
    if (comptime @hasDecl(gdzig.class.OptimizedTranslation, "generate_4_6_legacy")) {
        if (gdzig.version.range(.@"4.6", .@"4.7")) {
            optimized.generate_4_6_legacy(translation);
        }
    }
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
