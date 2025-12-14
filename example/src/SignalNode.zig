const Self = @This();

allocator: Allocator,
base: *Control, //this makes @Self a valid gdextension class
color_rect: *ColorRect = undefined,

pub const Signal1 = struct {
    name: String,
    position: Vector3,
};
pub const Signal2 = struct {};
pub const Signal3 = struct {};

pub fn create(allocator: *Allocator) !*Self {
    const self = try allocator.create(Self);
    self.* = .{
        .allocator = allocator.*,
        .base = Control.init(),
    };
    self.base.setInstance(Self, self);
    return self;
}

pub fn destroy(self: *Self, allocator: *Allocator) void {
    self.base.destroy();
    allocator.destroy(self);
}

pub fn _enterTree(self: *Self) void {
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

    signal1_btn.connect(Button.PressedSignal, .fromClosure(self, &emitSignal1)) catch {};
    signal2_btn.connect(Button.PressedSignal, .fromClosure(self, &emitSignal2)) catch {};
    signal3_btn.connect(Button.PressedSignal, .fromClosure(self, &emitSignal3)) catch {};
    self.base.connect(Signal1, .fromClosure(self, &onSignal1)) catch {};
    self.base.connect(Signal2, .fromClosure(self, &onSignal2)) catch {};
    self.base.connect(Signal3, .fromClosure(self, &onSignal3)) catch {};
}

pub fn _exitTree(self: *Self) void {
    _ = self;
}

pub fn onSignal1(_: *Self, name: String, position: Vector3) void {
    var buf: [256]u8 = undefined;
    const n = godot.string.stringToAscii(name, &buf);
    std.debug.print("signal1 received : name = {s} position={any}\n", .{ n, position });
}

pub fn onSignal2(self: *Self) void {
    std.debug.print("{} {}\n", .{ self.color_rect, Color.initRGBA(0, 1, 0, 1) });
    self.color_rect.setColor(Color.initRGBA(0, 1, 0, 1));
}

pub fn onSignal3(self: *Self) void {
    self.color_rect.setColor(Color.initRGBA(1, 0, 0, 1));
}

pub fn emitSignal1(self: *Self) void {
    self.base.emit(Signal1{
        .name = .fromLatin1("test_signal_name"),
        .position = .initXYZ(123, 321, 333),
    }) catch {};
}
pub fn emitSignal2(self: *Self) void {
    self.base.emit(Signal2{}) catch {};
}
pub fn emitSignal3(self: *Self) void {
    self.base.emit(Signal3{}) catch {};
}

const std = @import("std");
const Allocator = std.mem.Allocator;

const godot = @import("gdzig");
const Button = godot.class.Button;
const Color = godot.builtin.Color;
const ColorRect = godot.class.ColorRect;
const Control = godot.class.Control;
const Engine = godot.class.Engine;
const StringName = godot.builtin.StringName;
const String = godot.builtin.String;
const Vector3 = godot.builtin.Vector3;
