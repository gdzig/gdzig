const Self = @This();

base: *Control, //this makes @Self a valid gdextension class
color_rect: *ColorRect = undefined,

pub const Signal1 = struct {
    name: []const u8,
    position: Vector3,
};
pub const Signal2 = struct {};
pub const Signal3 = struct {};

pub fn _bindMethods() void {
    godot.registerMethod(Self, "onSignal1");
    godot.registerMethod(Self, "onSignal2");
    godot.registerMethod(Self, "onSignal3");
    godot.registerMethod(Self, "emitSignal1");
    godot.registerMethod(Self, "emitSignal2");
    godot.registerMethod(Self, "emitSignal3");
    godot.registerSignal(Self, Signal1);
    godot.registerSignal(Self, Signal2);
    godot.registerSignal(Self, Signal3);
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

    godot.connect(signal1_btn, BaseButton.PressedSignal, .fromClosure(self, &emitSignal1));
    godot.connect(signal2_btn, BaseButton.PressedSignal, .fromClosure(self, &emitSignal2));
    godot.connect(signal3_btn, BaseButton.PressedSignal, .fromClosure(self, &emitSignal3));
    godot.connect(self.base, Signal1, .fromClosure(self, &onSignal1));
    godot.connect(self.base, Signal2, .fromClosure(self, &onSignal2));
    godot.connect(self.base, Signal3, .fromClosure(self, &onSignal3));
}

pub fn _exitTree(self: *Self) void {
    _ = self;
}

pub fn onSignal1(_: *Self, name: StringName, position: Vector3) void {
    var buf: [256]u8 = undefined;
    const n = godot.string.stringNameToAscii(name, &buf);
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
    _ = self.base.emitSignal(.fromComptimeLatin1("signal1"), .{ StringName.fromComptimeLatin1("test_signal_name"), Vector3.initXYZ(123, 321, 333) });
}
pub fn emitSignal2(self: *Self) void {
    _ = self.base.emitSignal(.fromComptimeLatin1("signal2"), .{});
}
pub fn emitSignal3(self: *Self) void {
    _ = self.base.emitSignal(.fromComptimeLatin1("signal3"), .{});
}

const std = @import("std");

const godot = @import("gdzig");
const Button = godot.class.Button;
const BaseButton = godot.class.BaseButton;
const Color = godot.builtin.Color;
const ColorRect = godot.class.ColorRect;
const Control = godot.class.Control;
const Engine = godot.class.Engine;
const StringName = godot.builtin.StringName;
const Vector3 = godot.builtin.Vector3;
