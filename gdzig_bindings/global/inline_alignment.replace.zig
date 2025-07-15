pub const InlineAlignment = packed struct(u4) {
    image: Position,
    text: Position,

    pub const Position = enum(u2) {
        top = 0,
        center = 1,
        bottom = 2,
        baseline = 3,
    };
};
