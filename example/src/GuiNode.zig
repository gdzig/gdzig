const Self = @This();

base: Control,
sprite: Sprite2D,

pub fn _enterTree(self: *Self) void {
    if (Engine.isEditorHint()) return;

    var normal_btn = Button.init();
    self.base.addChild(Node.cast(normal_btn).?, .{});
    normal_btn.setPosition(Vector2.new(100, 20), .{});
    normal_btn.setSize(Vector2.new(100, 50), .{});
    normal_btn.setText(.fromLatin1("Press Me"));

    var toggle_btn = CheckBox.init();
    self.base.addChild(Node.cast(toggle_btn).?, .{});
    toggle_btn.setPosition(.new(320, 20), .{});
    toggle_btn.setSize(.new(100, 50), .{});
    toggle_btn.setText(.fromLatin1("Toggle Me"));

    godot.connect(toggle_btn, "toggled", self, "onToggled");
    godot.connect(normal_btn, "pressed", self, "onPressed");

    const res_name = String.fromLatin1("res://textures/logo.png");
    const texture = ResourceLoader.load(res_name, .{});
    defer _ = godot.unreference(texture);
    self.sprite = Sprite2D.init();
    self.sprite.setTexture(Texture2D.cast(texture).?);
    self.sprite.setPosition(.new(400, 300));
    self.sprite.setScale(.new(0.6, 0.6));
    self.base.addChild(Node.cast(self.sprite).?, .{});
}

pub fn _exitTree(self: *Self) void {
    _ = self;
}

pub fn onPressed(self: *Self) void {
    _ = self;
    std.debug.print("onPressed \n", .{});
}

pub fn onToggled(self: *Self, toggled_on: bool) void {
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
const Texture2D = godot.core.Texture2D;
const Vector2 = godot.Vector2;
