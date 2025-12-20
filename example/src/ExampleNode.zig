const ExampleNode = @This();

const Examples = [_]struct { name: [:0]const u8, T: type }{
    .{ .name = "Sprites", .T = SpritesNode },
    .{ .name = "GUI", .T = GuiNode },
    .{ .name = "Signals", .T = SignalNode },
};

pub fn register(r: *Registry) void {
    // createClass returns a builder for adding methods, properties, signals
    // .auto uses defaults; override with .{ .level = .editor } etc.
    const class = r.createClass(ExampleNode, r.allocator, .auto);

    // Methods auto-detect decl from snake_case name (on_timeout -> onTimeout)
    class.addMethod("on_timeout", .auto);
    class.addMethod("on_resized", .auto);
    class.addMethod("on_item_focused", .auto);

    // Properties auto-detect getter/setter from getX/setX methods or field
    class.addProperty("property1", .auto);
    // Override to make read-only (no setter)
    class.addProperty("property2", .{ .setter = .none });

    // Reuse a method as a property getter
    const get_speed = class.createMethod("get_speed", .auto);
    class.addProperty("speed", .{ .getter = .{ .method = get_speed }, .setter = .none });
}

allocator: Allocator,
base: *Node,
panel: *PanelContainer = undefined,
example_node: ?*Node = null,

property1: Vector3 = .zero,
property2: Vector3 = .zero,
speed: f64 = 1.0,

fps_counter: *Label,

pub fn create(allocator: *Allocator) !*ExampleNode {
    const self = try allocator.create(ExampleNode);
    self.* = .{
        .allocator = allocator.*,
        .base = .init(),
        .fps_counter = .init(),
    };
    self.base.setInstance(ExampleNode, self);

    self.base.addChild(.upcast(self.fps_counter), .{});
    self.fps_counter.setPosition(.{ .x = 50, .y = 50 }, .{});

    return self;
}

pub fn destroy(self: *ExampleNode, allocator: *Allocator) void {
    std.log.info("destroy {s}", .{@typeName(ExampleNode)});
    self.base.destroy();
    allocator.destroy(self);
}

pub fn _process(self: *ExampleNode, _: f64) void {
    const window = self.base.getTree().?.getRoot().?;
    const sz = window.getSize();

    const label_size = self.fps_counter.getSize();
    self.fps_counter.setPosition(.{ .x = @floatFromInt(25), .y = @as(f32, @floatFromInt(sz.y - 25)) - label_size.y }, .{});

    var fps_buf: [64]u8 = undefined;
    const fps = std.fmt.bufPrint(&fps_buf, "FPS: {d}", .{Engine.getFramesPerSecond()}) catch @panic("Failed to format FPS");
    var fps_string = String.fromLatin1(fps);
    defer fps_string.deinit();

    self.fps_counter.setText(fps_string);
}

fn clearScene(self: *ExampleNode) void {
    if (self.example_node) |n| {
        n.destroy();
        self.example_node = null;
    }
}

pub fn onTimeout(_: *ExampleNode) void {}

pub fn onResized(_: *ExampleNode) void {}

pub fn getSpeed(self: *ExampleNode) f64 {
    return self.speed;
}

pub fn onItemFocused(self: *ExampleNode, idx: i64) void {
    self.clearScene();
    switch (idx) {
        inline 0...Examples.len - 1 => |i| {
            const n = Examples[i].T.create(&self.allocator) catch unreachable;
            self.example_node = .upcast(n);
            self.panel.addChild(self.example_node.?, .{});
            self.panel.grabFocus();
        },
        else => {},
    }
}

pub fn _enterTree(self: *ExampleNode) void {
    // test T -> variant -> T
    const obj = ExampleNode.create(&self.allocator) catch unreachable;
    defer obj.destroy(&self.allocator);

    const variant: Variant = .init(*ExampleNode, obj);
    const result = variant.as(*ExampleNode).?;
    _ = result;

    //initialize fields
    self.example_node = null;
    self.property1 = Vector3.initXYZ(111, 111, 111);
    self.property2 = Vector3.initXYZ(222, 222, 222);

    if (Engine.isEditorHint()) {
        return;
    }

    const window_size = self.base.getTree().?.getRoot().?.getSize();

    var sp = HSplitContainer.init();
    sp.setHSizeFlags(.size_expand_fill);
    sp.setVSizeFlags(.size_expand_fill);
    sp.setSplitOffset(@intFromFloat(@as(f32, @floatFromInt(window_size.x)) * 0.2));
    sp.setAnchorsPreset(.preset_full_rect, .{});

    var itemList = ItemList.init();
    inline for (0..Examples.len) |i| {
        const name = String.fromLatin1(Examples[i].name);
        _ = itemList.addItem(name, .{});
    }

    var timer = self.base.getTree().?.createTimer(1.0, .{}).?;
    defer if (timer.unreference()) timer.destroy();

    timer.connect(SceneTreeTimer.Timeout, .fromClosure(self, &onTimeout)) catch {};
    sp.connect(HSplitContainer.Resized, .fromClosure(self, &onResized)) catch {};
    itemList.connect(ItemList.ItemSelected, .fromClosure(self, &onItemFocused)) catch {};

    self.panel = PanelContainer.init();
    self.panel.setHSizeFlags(.{ .size_fill = true });
    self.panel.setVSizeFlags(.{ .size_fill = true });
    self.panel.setFocusMode(.focus_all);

    sp.addChild(.upcast(itemList), .{});
    sp.addChild(.upcast(self.panel), .{});
    self.base.addChild(.upcast(sp), .{});

    const vprt = self.base.getViewport().?;

    const tex = vprt.getTexture().?;
    defer if (tex.unreference()) tex.destroy();

    const img = tex.getImage().?;
    defer if (img.unreference()) img.destroy();

    const data = img.getData();
    _ = data;
}

pub fn _exitTree(self: *ExampleNode) void {
    self.clearScene();
}

pub fn _notification(self: *ExampleNode, what: i32, _: bool) void {
    if (what == Node.NOTIFICATION_WM_CLOSE_REQUEST) {
        if (!Engine.isEditorHint()) {
            self.base.getTree().?.quit(.{});
        }
    }
}

pub fn _toString(_: *ExampleNode) ?String {
    return String.fromLatin1("ExampleNode");
}

const std = @import("std");
const Allocator = std.mem.Allocator;

const godot = @import("godot");
const Registry = godot.extension.Registry;
const Engine = godot.class.Engine;
const HSplitContainer = godot.class.HSplitContainer;
const ItemList = godot.class.ItemList;
const Label = godot.class.Label;
const Node = godot.class.Node;
const PanelContainer = godot.class.PanelContainer;
const String = godot.builtin.String;
const Variant = godot.builtin.Variant;
const Vector3 = godot.builtin.Vector3;
const SceneTreeTimer = godot.class.SceneTreeTimer;

const GuiNode = @import("GuiNode.zig");
const SignalNode = @import("SignalNode.zig");
const SpritesNode = @import("SpriteNode.zig");
