const GuiNode = @This();

base: *Control,
sprite: *Sprite2D = undefined,

pub fn _enterTree(self: *GuiNode) void {
    if (Engine.isEditorHint()) return;

    var normal_btn = Button.init();
    self.base.addChild(.upcast(normal_btn), .{});
    normal_btn.setPosition(Vector2.initXY(100, 20), .{});
    normal_btn.setSize(Vector2.initXY(100, 50), .{});
    normal_btn.setText(.fromLatin1("Press Me"));

    var toggle_btn = CheckBox.init();
    self.base.addChild(.upcast(toggle_btn), .{});
    toggle_btn.setPosition(.initXY(320, 20), .{});
    toggle_btn.setSize(.initXY(100, 50), .{});
    toggle_btn.setText(.fromLatin1("Toggle Me"));

    godot.connect(toggle_btn, Button.ToggledSignal, .fromClosure(self, &onToggled));
    godot.connect(normal_btn, Button.PressedSignal, .fromClosure(self, &onPressed));

    var res_name: String = .fromLatin1("res://textures/logo.png");
    defer res_name.deinit();

    const texture = ResourceLoader.load(res_name, .{}).?;
    defer _ = texture.unreference();
    self.sprite = Sprite2D.init();
    self.sprite.setTexture(Texture2D.downcast(texture).?);
    self.sprite.setPosition(.initXY(400, 300));
    self.sprite.setScale(.initXY(0.6, 0.6));
    self.base.addChild(.upcast(self.sprite), .{});
}

pub fn _exitTree(self: *GuiNode) void {
    _ = self;
}

pub fn onPressed(self: *GuiNode) void {
    _ = self;
    std.debug.print("onPressed \n", .{});
}

pub fn onToggled(self: *GuiNode, toggled_on: bool) void {
    _ = self;
    std.debug.print("on_toggled {any}\n", .{toggled_on});
}

pub fn _bindMethods() void {
    godot.registerMethod(GuiNode, .onPressed);
    godot.registerMethod(GuiNode, .onToggled);
}

const std = @import("std");
const godot = @import("gdzig");
const Button = godot.class.Button;
const CheckBox = godot.class.CheckBox;
const Control = godot.class.Control;
const Engine = godot.class.Engine;
const ResourceLoader = godot.class.ResourceLoader;
const Sprite2D = godot.class.Sprite2D;
const String = godot.builtin.String;
const StringName = godot.builtin.StringName;
const Texture2D = godot.class.Texture2D;
const Vector2 = godot.builtin.Vector2;
