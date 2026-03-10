const SignalNode = @This();

pub fn register(r: *Registry) void {
    const class = r.createClass(SignalNode, r.allocator, .auto);
    class.addMethod("on_signal1", .auto);
    class.addMethod("on_signal2", .auto);
    class.addMethod("on_signal3", .auto);
    class.addMethod("emit_signal1", .auto);
    class.addMethod("emit_signal2", .auto);
    class.addMethod("emit_signal3", .auto);

    // Signals are defined as struct types with fields for each argument
    class.addSignal(Signal1);
    class.addSignal(Signal2);
    class.addSignal(Signal3);

    // Groups organize properties in the inspector
    const colors = class.createGroup("Colors");
    colors.addProperty("colors_signal2", .auto);
    colors.addProperty("colors_signal3", .auto);
}

allocator: Allocator,
base: *Control, //this makes @Self a valid gdextension class
color_rect: *ColorRect = undefined,

// Colors group
colors_signal2: Color = Color.initRGBA(0, 1, 0, 1),
colors_signal3: Color = Color.initRGBA(1, 0, 0, 1),

pub const Signal1 = struct {
    name: String,
    position: Vector3,
};
pub const Signal2 = struct {};
pub const Signal3 = struct {};

pub fn create(allocator: *Allocator) !*SignalNode {
    const self = try allocator.create(SignalNode);
    self.* = .{
        .allocator = allocator.*,
        .base = Control.init(),
    };
    self.base.setInstance(SignalNode, self);
    return self;
}

pub fn destroy(self: *SignalNode, allocator: *Allocator) void {
    self.base.destroy();
    allocator.destroy(self);
}

pub fn _enterTree(self: *SignalNode) void {
    if (Engine.isEditorHint()) return;

    var signal1_btn = Button.init();
    signal1_btn.setPosition(.initXY(100, 20), .{});
    signal1_btn.setSize(.initXY(100, 50), .{});
    signal1_btn.setText(.fromLatin1("Signal1"));
    self.base.addChild(.upcast(signal1_btn), .{});

    var signal2_btn = Button.init();
    signal2_btn.setPosition(.initXY(250, 20), .{});
    signal2_btn.setSize(.initXY(100, 50), .{});
    signal2_btn.setText(.fromLatin1("Signal2"));
    self.base.addChild(.upcast(signal2_btn), .{});

    var signal3_btn = Button.init();
    signal3_btn.setPosition(.initXY(400, 20), .{});
    signal3_btn.setSize(.initXY(100, 50), .{});
    signal3_btn.setText(.fromLatin1("Signal3"));
    self.base.addChild(.upcast(signal3_btn), .{});

    self.color_rect = ColorRect.init();
    self.color_rect.setPosition(.initXY(400, 400), .{});
    self.color_rect.setSize(.initXY(100, 100), .{});
    self.color_rect.setColor(.initRGBA(1, 0, 0, 1));
    self.base.addChild(.upcast(self.color_rect), .{});

    signal1_btn.connect(Button.Pressed, .fromClosure(self, &emitSignal1)) catch {};
    signal2_btn.connect(Button.Pressed, .fromClosure(self, &emitSignal2)) catch {};
    signal3_btn.connect(Button.Pressed, .fromClosure(self, &emitSignal3)) catch {};
    self.base.connect(Signal1, .fromClosure(self, &onSignal1)) catch {};
    self.base.connect(Signal2, .fromClosure(self, &onSignal2)) catch {};
    self.base.connect(Signal3, .fromClosure(self, &onSignal3)) catch {};
}

pub fn _exitTree(self: *SignalNode) void {
    _ = self;
}

pub fn onSignal1(_: *SignalNode, name: String, position: Vector3) void {
    var buf: [256]u8 = undefined;
    const n = name.toLatin1Buf(&buf);
    std.debug.print("signal1 received : name = {s} position={any}\n", .{ n, position });
}

pub fn onSignal2(self: *SignalNode) void {
    std.debug.print("{} {}\n", .{ self.color_rect, self.colors_signal2 });
    self.color_rect.setColor(self.colors_signal2);
}

pub fn onSignal3(self: *SignalNode) void {
    self.color_rect.setColor(self.colors_signal3);
}

pub fn emitSignal1(self: *SignalNode) void {
    self.base.emit(Signal1, .{
        .name = .fromLatin1("test_signal_name"),
        .position = .initXYZ(123, 321, 333),
    }) catch {};
}
pub fn emitSignal2(self: *SignalNode) void {
    self.base.emit(Signal2, .{}) catch {};
}
pub fn emitSignal3(self: *SignalNode) void {
    self.base.emit(Signal3, .{}) catch {};
}

const std = @import("std");
const Allocator = std.mem.Allocator;

const godot = @import("godot");
const Registry = godot.extension.Registry;
const Button = godot.class.Button;
const Color = godot.builtin.Color;
const ColorRect = godot.class.ColorRect;
const Control = godot.class.Control;
const Engine = godot.class.Engine;
const StringName = godot.builtin.StringName;
const String = godot.builtin.String;
const Vector3 = godot.builtin.Vector3;
