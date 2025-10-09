pub const BuiltinOverrides = struct {
    pub const empty: @This() = .{};

    constants_blacklist: StaticStringMap(void) = .initComptime(.{}),
};

pub const builtins: StaticStringMap(BuiltinOverrides) = .initComptime(.{
    .{
        "Transform2D",
        BuiltinOverrides{
            .constants_blacklist = .initComptime(.{
                .{"IDENTITY"},
                .{"FLIP_X"},
                .{"FLIP_Y"},
            }),
        },
    },
    .{
        "Transform3D",
        BuiltinOverrides{
            .constants_blacklist = .initComptime(.{
                .{"IDENTITY"},
                .{"FLIP_X"},
                .{"FLIP_Y"},
                .{"FLIP_Z"},
            }),
        },
    },
    .{
        "Basis",
        BuiltinOverrides{
            .constants_blacklist = .initComptime(.{
                .{"IDENTITY"},
                .{"FLIP_X"},
                .{"FLIP_Y"},
                .{"FLIP_Z"},
            }),
        },
    },
    .{
        "Projection",
        BuiltinOverrides{
            .constants_blacklist = .initComptime(.{
                .{"IDENTITY"},
                .{"ZERO"},
            }),
        },
    },
});

const std = @import("std");
const StaticStringMap = std.StaticStringMap;
