# gdzig

Idiomatic Zig bindings for Godot 4.

## DISCLAIMER

This library is currently undergoing rapid development and refactoring as we figure out the best API to expose. Bugs and missing features are
expected until a stable version is released. Issue reports, feature requests, and pull requests are all very welcome.

## Prerequisites

1. zig 0.14.1
2. godot 4.4

## Usage:

See the [example](example/) folder for reference.

## Code Sample:

```zig
const Self = @This();

base: Base,
sprite: Sprite2D,

pub fn _enter_tree(self: *Self) void {
    if (Engine.getSingleton().isEditorHint()) return;

    var normal_btn = Button.init();
    self.base.add_child(normal_btn, false, Node.INTERNAL_MODE_DISABLED);
    normal_btn.setPosition(Vec2.new(100, 20), false);
    normal_btn.setSize(Vec2.new(100, 50), false);
    normal_btn.setText("Press Me");

    var toggle_btn = CheckBox.init();
    self.base.add_child(toggle_btn, false, Node.INTERNAL_MODE_DISABLED);
    toggle_btn.setPosition(Vec2.new(320, 20), false);
    toggle_btn.setSize(Vec2.new(100, 50), false);
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
        self.sprite.setPosition(Vec2.new(400, 300));
        self.sprite.setScale(Vec2.new(0.6, 0.6));
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
const Base = godot.core.Control;
const Button = godot.core.Button;
const CheckBox = godot.core.CheckBox;
const Engine = godot.core.Engine;
const ResourceLoader = godot.core.ResourceLoader;
const Node = godot.core.Node
const Sprite2D = godot.core.Sprite2D;
const String = godot.core.String;
const Vec2 = godot.core.Vector2;
```
