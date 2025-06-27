const Self = @This();

base: Control,
rng: std.Random = undefined,
sprites: std.ArrayList(Sprite) = undefined,

const Sprite = struct {
    pos: Vector2,
    vel: Vector2,
    scale: Vector2,
    gd_sprite: Sprite2D,
};

pub fn newSpritesNode() *Self {
    var self = godot.create(Self);
    self.example_node = null;
}

pub fn randfRange(self: Self, comptime T: type, min: T, max: T) T {
    const u: T = self.rng.float(T);
    return u * (max - min) + min;
}

pub fn _ready(self: *Self) void {
    const engine = Engine.getSingleton();
    if (engine.isEditorHint()) return;

    var prng = std.Random.DefaultPrng.init(@intCast(std.time.timestamp()));
    self.rng = prng.random();
    self.sprites = std.ArrayList(Sprite).init(godot.general_allocator);

    const resource_loader = ResourceLoader.getSingleton();
    const tex = resource_loader.load("res://textures/logo.png", "", ResourceLoader.CACHE_MODE_REUSE);
    defer _ = godot.unreference(tex.?);

    const sz = self.base.getParentAreaSize();

    for (0..10000) |_| {
        const s: f32 = self.randfRange(f32, 0.1, 0.2);
        const spr = Sprite{
            .pos = Vector2.new(self.randfRange(f32, 0, sz.x), self.randfRange(f32, 0, sz.y)),
            .vel = Vector2.new(self.randfRange(f32, -1000, 1000), self.randfRange(f32, -1000, 1000)),
            .scale = Vector2.set(s),
            .gd_sprite = Sprite2D.init(),
        };
        spr.gd_sprite.setTexture(tex);
        spr.gd_sprite.setRotation(self.randfRange(f32, 0, std.math.pi));
        spr.gd_sprite.setScale(spr.scale);
        self.base.addChild(spr.gd_sprite, false, Node.INTERNAL_MODE_DISABLED);
        self.sprites.append(spr) catch unreachable;
    }
}

pub fn _exit_tree(self: *Self) void {
    self.sprites.deinit();
}

pub fn _physics_process(self: *Self, delta: f64) void {
    const sz = self.base.getParentAreaSize(); //get_size();

    for (self.sprites.items) |*spr| {
        const pos = spr.pos.add(spr.vel.scale(@floatCast(delta)));
        const spr_size = spr.gd_sprite.getRect().size.mul(spr.gd_sprite.getScale());

        if (pos.x <= spr_size.x / 2) {
            spr.vel.x = @abs(spr.vel.x);
        } else if (pos.x >= sz.x - spr_size.x / 2) {
            spr.vel.x = -@abs(spr.vel.x);
        }
        if (pos.y <= spr_size.y / 2) {
            spr.vel.y = @abs(spr.vel.y);
        } else if (pos.y >= sz.y - spr_size.y / 2) {
            spr.vel.y = -@abs(spr.vel.y);
        }
        spr.pos = pos;
        spr.gd_sprite.setPosition(spr.pos);
    }
}

const std = @import("std");
const godot = @import("gdzig");
const Control = godot.core.Control;
const Engine = godot.core.Engine;
const Node = godot.core.Node;
const ResourceLoader = godot.core.ResourceLoader;
const Sprite2D = godot.core.Sprite2D;
const Vector2 = godot.Vector2;
