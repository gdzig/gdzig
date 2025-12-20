const GuiNode = @This();

pub fn register(r: *Registry) void {
    const class = r.createClass(GuiNode, r.allocator, .auto);
    class.addMethod("on_pressed", .auto);
    class.addMethod("on_toggled", .auto);
}

allocator: Allocator,
base: *Control,
sprite: *Sprite2D = undefined,

pub fn create(allocator: *Allocator) !*GuiNode {
    const self = try allocator.create(GuiNode);
    self.* = .{
        .allocator = allocator.*,
        .base = Control.init(),
    };
    self.base.setInstance(GuiNode, self);
    return self;
}

pub fn destroy(self: *GuiNode, allocator: *Allocator) void {
    self.base.destroy();
    allocator.destroy(self);
}

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

    toggle_btn.connect(Button.Toggled, .fromClosure(self, &onToggled)) catch {};
    normal_btn.connect(Button.Pressed, .fromClosure(self, &onPressed)) catch {};

    var res_name: String = .fromLatin1("res://textures/logo.png");
    defer res_name.deinit();

    const texture = ResourceLoader.load(res_name, .{}).?;
    defer if (texture.unreference()) texture.destroy();
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

const std = @import("std");
const Allocator = std.mem.Allocator;

const godot = @import("godot");
const Registry = godot.extension.Registry;
const Button = godot.class.Button;
const CheckBox = godot.class.CheckBox;
const Control = godot.class.Control;
const Engine = godot.class.Engine;
const ResourceLoader = godot.class.ResourceLoader;
const Sprite2D = godot.class.Sprite2d;
const String = godot.builtin.String;
const StringName = godot.builtin.StringName;
const Texture2D = godot.class.Texture2d;
const Vector2 = godot.builtin.Vector2;
