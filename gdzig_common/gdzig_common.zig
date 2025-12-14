pub const godot_case = struct {
    pub const constant: Config = .constant;
    pub const func: Config = .snake;
    pub const method: Config = .snake;
    pub const property: Config = .snake;
    pub const signal: Config = .snake;
    pub const @"type": Config = .pascal;
    pub const virtual_method: Config = .withPrefix(.snake, "_");
};

pub const gdzig_case = struct {
    pub const constant: Config = .constant;
    pub const file: Config = .snake;
    pub const func: Config = .camel;
    pub const method: Config = .camel;
    pub const signal: Config = .withSuffix(.snake, "Signal");
    pub const @"type": Config = .withDictionary(.pascal, type_dictionary);
    pub const virtual_method: Config = .withPrefix(.camel, "_");
};

const type_dictionary: Config.Dictionary = .{
    .acronyms = .initComptime(&.{
        .{ "enet", {} },
        .{ "vrs", {} },
        .{ "xr", {} },
    }),
    .splits = .initComptime(&.{
        .{ "2drd", &.{ "2d", "rd" } },
        .{ "3drd", &.{ "3d", "rd" } },
        .{ "enet", &.{ "e", "net" } },
        .{ "xrip", &.{ "xr", "ip" } },
        .{ "uint", &.{"uint"} },
    }),
};

/// Format helper for use with std.fmt
pub fn Fmt(comptime config: Config) type {
    return struct {
        pub fn format(str: []const u8, writer: *std.io.Writer) std.io.Writer.Error!void {
            var buf: [256]u8 = undefined;
            const result = casez.bufConvert(config, &buf, str) orelse return error.WriteFailed;
            try writer.writeAll(result);
        }
    };
}

/// Returns a formatter for use with std.fmt.allocPrint and friends
pub fn fmt(comptime config: Config, str: []const u8) std.fmt.Alt([]const u8, Fmt(config).format) {
    return .{ .data = str };
}

test "type name conversion" {
    inline for (&.{
        .{ "Node", "node" },
        .{ "RefCounted", "ref_counted" },
        .{ "Vector2", "vector2" },
    }) |case| {
        try testing.expectEqualStrings(case[0], comptimeConvert(godot_case.type, case[1]));
        try testing.expectEqualStrings(case[1], comptimeConvert(gdzig_case.type, case[0]));
    }
}

test "type name acronyms" {
    // Verify acronym dictionary produces correct type names
    try testing.expectEqualStrings("XrVrs", comptimeConvert(gdzig_case.type, "XRVRS"));
    try testing.expectEqualStrings("GdScript", comptimeConvert(gdzig_case.type, "GDScript"));
    try testing.expectEqualStrings("ENetConnection", comptimeConvert(gdzig_case.type, "ENetConnection"));
    try testing.expectEqualStrings("XrCamera3d", comptimeConvert(gdzig_case.type, "XRCamera3D"));
    try testing.expectEqualStrings("OpenXrInterface", comptimeConvert(gdzig_case.type, "OpenXRInterface"));
}

test "method name conversion" {
    inline for (&.{
        .{ "get_node", "getNode" },
        .{ "add_child", "addChild" },
    }) |case| {
        try testing.expectEqualStrings(case[0], comptimeConvert(godot_case.method, case[1]));
        try testing.expectEqualStrings(case[1], comptimeConvert(gdzig_case.method, case[0]));
    }
}

test "virtual method conversion" {
    inline for (&.{
        .{ "_enter_tree", "_enterTree" },
        .{ "_ready", "_ready" },
        .{ "_process", "_process" },
        .{ "_physics_process", "_physicsProcess" },
        .{ "_get_http_response", "_getHTTPResponse" },
        .{ "_parse_url_string", "_parseURLString" },
        .{ "_get_id", "_getID" },
    }) |case| {
        try testing.expectEqualStrings(case[0], comptimeConvert(godot_case.virtual_method, case[1]));
        try testing.expectEqualStrings(case[1], comptimeConvert(gdzig_case.virtual_method, case[0]));
    }
}

test "signal name conversion" {
    inline for (&.{
        .{ "tree_entered", "treeEntered" },
        .{ "child_exited_tree", "childExitedTree" },
    }) |case| {
        try testing.expectEqualStrings(case[0], comptimeConvert(godot_case.signal, case[1]));
        try testing.expectEqualStrings(case[1], comptimeConvert(gdzig_case.signal, case[0]));
    }
}

const std = @import("std");
const testing = std.testing;

const casez = @import("casez");
const Config = casez.Config;
const comptimeConvert = casez.comptimeConvert;
