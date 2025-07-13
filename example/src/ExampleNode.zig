const ExampleNode = @This();

const Examples = [_]struct { name: [:0]const u8, T: type }{
    .{ .name = "Sprites", .T = SpritesNode },
    .{ .name = "GUI", .T = GuiNode },
    .{ .name = "Signals", .T = SignalNode },
};

base: *Node,
panel: *PanelContainer = undefined,
example_node: ?*Node = null,

property1: Vector3 = .zero,
property2: Vector3 = .zero,

fps_counter: *Label,

const property1_name: [:0]const u8 = "Property1";
const property2_name: [:0]const u8 = "Property2";

pub fn init(base: *Node) ExampleNode {
    std.log.info("init {s}", .{@typeName(ExampleNode)});

    var fps_counter = Label.init();
    fps_counter.setPosition(.{ .x = 50, .y = 50 }, .{});
    base.addChild(.upcast(fps_counter), .{});

    return .{
        .base = base,
        .fps_counter = fps_counter,
    };
}

pub fn deinit(self: *ExampleNode) void {
    std.log.info("deinit {s}", .{@typeName(@TypeOf(self))});
}

pub fn _process(self: *ExampleNode, _: f64) void {
    const window = self.base.getTree().?.getRoot().?;
    const sz = window.getSize();

    const label_size = self.fps_counter.getSize();
    self.fps_counter.setPosition(.{ .x = @floatFromInt(25), .y = @as(f32, @floatFromInt(sz.y - 25)) - label_size.y }, .{});

    var fps_buf: [64]u8 = undefined;
    const fps = std.fmt.bufPrint(&fps_buf, "FPS: {d}", .{Engine.getFramesPerSecond()}) catch @panic("Failed to format FPS");
    const fps_string = String.fromLatin1(fps);
    self.fps_counter.setText(fps_string);
}

fn clearScene(self: *ExampleNode) void {
    if (self.example_node) |n| {
        godot.object.destroy(n);
        //n.queue_free(); //ok
    }
}

pub fn onTimeout(_: *ExampleNode) void {
    std.debug.print("onTimeout\n", .{});
}

pub fn onResized(_: *ExampleNode) void {
    std.debug.print("onResized\n", .{});
}

pub fn onItemFocused(self: *ExampleNode, idx: i64) void {
    self.clearScene();
    switch (idx) {
        inline 0...Examples.len - 1 => |i| {
            const n = godot.object.create(Examples[i].T) catch unreachable;
            self.example_node = .upcast(n);
            self.panel.addChild(self.example_node.?, .{});
            self.panel.grabFocus();
        },
        else => {},
    }
}

pub fn _enterTree(self: *ExampleNode) void {
    inline for (Examples) |E| {
        godot.registerClass(E.T);
    }

    // test T -> variant -> T
    const obj: *ExampleNode = godot.object.create(ExampleNode) catch unreachable;
    const variant: Variant = Variant.init(obj);
    const result = variant.as(*ExampleNode).?;
    std.debug.print("Result: {?}\n", .{result.fps_counter.getPosition()});

    //initialize fields
    self.example_node = null;
    self.property1 = Vector3.initXYZ(111, 111, 111);
    self.property2 = Vector3.initXYZ(222, 222, 222);

    if (Engine.isEditorHint()) return;

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
    defer _ = timer.unreference();

    godot.connect(timer, SceneTreeTimer.TimeoutSignal, .fromClosure(self, &onTimeout));
    godot.connect(sp, Control.ResizedSignal, .fromClosure(self, &onResized));
    godot.connect(itemList, ItemList.ItemSelectedSignal, .fromClosure(self, &onItemFocused));

    self.panel = PanelContainer.init();
    self.panel.setHSizeFlags(.{ .size_fill = true });
    self.panel.setVSizeFlags(.{ .size_fill = true });
    self.panel.setFocusMode(.focus_all);
    sp.addChild(.upcast(itemList), .{});
    sp.addChild(.upcast(self.panel), .{});
    self.base.addChild(.upcast(sp), .{});

    const vprt = self.base.getViewport().?;
    const tex = vprt.getTexture().?;
    const img = tex.getImage().?;
    std.debug.print("IMG Available {any} \n", .{img});
    const data = img.getData();
    std.debug.print("Size {d} \n", .{data.size()});
}

pub fn _exitTree(self: *ExampleNode) void {
    _ = self;
}

pub fn _notification(self: *ExampleNode, what: i32) void {
    if (what == Node.NOTIFICATION_WM_CLOSE_REQUEST) {
        if (!Engine.isEditorHint()) {
            self.base.getTree().?.quit(.{});
        }
    }
}

pub fn _getPropertyList(_: *ExampleNode, p: *godot.object.PropertyBuilder) !void {
    try p.append(ExampleNode, "property1", .{});
    try p.append(ExampleNode, "property2", .{});
}

pub fn _propertyCanRevert(_: *ExampleNode, name: StringName) bool {
    var prop1 = String.fromLatin1(property1_name);
    defer prop1.deinit();

    var prop2 = String.fromLatin1(property2_name);
    defer prop2.deinit();

    if (name.casecmpTo(prop1) == 0) {
        return true;
    } else if (name.casecmpTo(prop2) == 0) {
        return true;
    }

    return false;
}

pub fn _propertyGetRevert(_: *ExampleNode, name: StringName, value: *Variant) bool {
    var prop1 = String.fromLatin1(property1_name);
    defer prop1.deinit();

    var prop2 = String.fromLatin1(property2_name);
    defer prop2.deinit();

    if (name.casecmpTo(prop1) == 0) {
        value.* = Variant.init(Vector3.initXYZ(42, 42, 42));
        return true;
    } else if (name.casecmpTo(prop2) == 0) {
        value.* = Variant.init(Vector3.initXYZ(24, 24, 24));
        return true;
    }

    return false;
}

pub fn _set(self: *ExampleNode, name: StringName, value: Variant) bool {
    var prop1 = String.fromLatin1(property1_name);
    defer prop1.deinit();

    var prop2 = String.fromLatin1(property2_name);
    defer prop2.deinit();

    if (name.casecmpTo(prop1) == 0) {
        self.property1 = value.as(Vector3).?;
        return true;
    } else if (name.casecmpTo(prop2) == 0) {
        self.property2 = value.as(Vector3).?;
        return true;
    }

    return false;
}

pub fn _get(self: *ExampleNode, name: StringName, value: *Variant) bool {
    var prop1 = String.fromLatin1(property1_name);
    defer prop1.deinit();

    var prop2 = String.fromLatin1(property2_name);
    defer prop2.deinit();

    if (name.casecmpTo(prop1) == 0) {
        value.* = Variant.init(self.property1);
        return true;
    } else if (name.casecmpTo(prop2) == 0) {
        value.* = Variant.init(self.property2);
        return true;
    }

    return false;
}

pub fn _toString(_: *ExampleNode) ?String {
    return String.fromLatin1("ExampleNode");
}

const std = @import("std");

const godot = @import("gdzig");
const Control = godot.class.Control;
const Engine = godot.class.Engine;
const HSplitContainer = godot.class.HSplitContainer;
const ItemList = godot.class.ItemList;
const Label = godot.class.Label;
const Node = godot.class.Node;
const PanelContainer = godot.class.PanelContainer;
const String = godot.builtin.String;
const StringName = godot.builtin.StringName;
const Variant = godot.builtin.Variant;
const Vector3 = godot.builtin.Vector3;
const SceneTreeTimer = godot.class.SceneTreeTimer;

const GuiNode = @import("GuiNode.zig");
const SignalNode = @import("SignalNode.zig");
const SpritesNode = @import("SpriteNode.zig");
