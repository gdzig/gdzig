pub const godot_case = struct {
    pub const constant: Config = .with(.constant, .{ .dictionary = dictionary });
    pub const func: Config = .with(.snake, .{ .dictionary = dictionary });
    pub const method: Config = .with(.snake, .{ .dictionary = dictionary });
    pub const property: Config = .with(.snake, .{ .dictionary = dictionary });
    pub const signal: Config = .with(.snake, .{ .dictionary = dictionary });
    pub const @"type": Config = .with(.pascal, .{
        .dictionary = dictionary,
        .acronym = .upper,
        .digit_boundary = true,
    });
    pub const virtual_method: Config = .with(.snake, .{
        .dictionary = dictionary,
        .prefix = "_",
    });
};

pub const gdzig_case = struct {
    pub const constant: Config = .with(.constant, .{ .dictionary = dictionary });
    pub const file: Config = .with(.snake, .{ .dictionary = dictionary });
    pub const func: Config = .with(.camel, .{ .dictionary = dictionary });
    pub const method: Config = .with(.camel, .{ .dictionary = dictionary });
    pub const signal: Config = .with(.pascal, .{ .dictionary = dictionary });
    pub const @"type": Config = .with(.pascal, .{ .dictionary = dictionary });
    pub const virtual_method: Config = .with(.camel, .{
        .dictionary = dictionary,
        .prefix = "_",
    });
};

const dictionary: Config.Dictionary = .{
    .acronyms = &.{
        "1d",
        "2d",
        "3d",
        "enet",
        "vrs",
        "xr",
    },
    .splits = &.{
        .{ "2d", "rd" },
        .{ "3d", "rd" },
        .{ "e", "net" },
        .{ "xr", "ip" },
    },
};

/// Format helper for use with std.fmt
pub fn Fmt(comptime config: Config) type {
    return struct {
        pub fn format(str: []const u8, writer: *std.Io.Writer) std.Io.Writer.Error!void {
            var buf: [256]u8 = undefined;
            const result = casez.bufConvert(&buf, config, str) catch return error.WriteFailed;
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
        // .{ godot, gdzig }
        .{ "Node", "Node" },
        .{ "Node2D", "Node2d" },
        .{ "RefCounted", "RefCounted" },
        .{ "Vector2", "Vector2" },
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
        // .{ godot, gdzig }
        .{ "get_node", "getNode" },
        .{ "add_child", "addChild" },
    }) |case| {
        try testing.expectEqualStrings(case[0], comptimeConvert(godot_case.method, case[1]));
        try testing.expectEqualStrings(case[1], comptimeConvert(gdzig_case.method, case[0]));
    }
}

test "virtual method conversion" {
    inline for (&.{
        // .{ godot, gdzig }
        .{ "_enter_tree", "_enterTree" },
        .{ "_ready", "_ready" },
        .{ "_process", "_process" },
        .{ "_physics_process", "_physicsProcess" },
        .{ "_get_http_response", "_getHttpResponse" },
        .{ "_parse_url_string", "_parseUrlString" },
        .{ "_get_id", "_getId" },
    }) |case| {
        try testing.expectEqualStrings(case[0], comptimeConvert(godot_case.virtual_method, case[1]));
        try testing.expectEqualStrings(case[1], comptimeConvert(gdzig_case.virtual_method, case[0]));
    }
}

test "signal name conversion" {
    inline for (&.{
        // .{ godot, gdzig }
        .{ "tree_entered", "TreeEntered" },
        .{ "child_exited_tree", "ChildExitedTree" },
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
