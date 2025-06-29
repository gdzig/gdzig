const Self = @This();

base: Control,
sprite: Sprite2D,

pub fn _enter_tree(self: *Self) void {
    if (Engine.isEditorHint()) return;

    var normal_btn = Button.init();
    self.base.addChild(normal_btn, false, Node.INTERNAL_MODE_DISABLED);
    normal_btn.setPosition(Vector2.new(100, 20), false);
    normal_btn.setSize(Vector2.new(100, 50), false);
    normal_btn.setText("Press Me");

    var toggle_btn = CheckBox.init();
    self.base.addChild(toggle_btn, false, Node.INTERNAL_MODE_DISABLED);
    toggle_btn.setPosition(Vector2.new(320, 20), false);
    toggle_btn.setSize(Vector2.new(100, 50), false);
    toggle_btn.setText("Toggle Me");

    godot.connect(toggle_btn, "toggled", self, "on_toggled");
    godot.connect(normal_btn, "pressed", self, "on_pressed");

    const resource_loader = ResourceLoader.getSingleton();
    const res_name = String.fromLatin1("res://textures/logo.png");
    const texture = resource_loader.load(res_name, "", ResourceLoader.CACHE_MODE_REUSE);
    if (texture) |tex| {
        defer _ = godot.unreference(tex);
        self.sprite = Sprite2D.init();
        self.sprite.setTexture(tex);
        self.sprite.setPosition(Vector2.new(400, 300));
        self.sprite.setScale(Vector2.new(0.6, 0.6));
        self.base.addChild(self.sprite, false, Node.INTERNAL_MODE_DISABLED);
    }
}

pub fn _exit_tree(self: *Self) void {
    _ = self;
}

pub fn on_pressed(self: *Self) void {
    _ = self;
    std.debug.print("on_pressed \n", .{});
}

pub fn on_toggled(self: *Self, toggled_on: bool) void {
    _ = self;
    std.debug.print("on_toggled {any}\n", .{toggled_on});
}

const std = @import("std");
const godot = @import("gdzig");
const Button = godot.core.Button;
const CheckBox = godot.core.CheckBox;
const Control = godot.core.Control;
const Engine = godot.core.Engine;
const Node = godot.core.Node;
const ResourceLoader = godot.core.ResourceLoader;
const Sprite2D = godot.core.Sprite2D;
const String = godot.core.String;
const Vector2 = godot.Vector2;
