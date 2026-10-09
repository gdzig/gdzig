//! Shared compatibility data, extraction and layout classification.
pub const manifest = @import("manifest.zig");
pub const records = @import("records.zig");
pub const method_layout = @import("method_layout.zig");

test {
    std.testing.refAllDecls(@This());
}

const std = @import("std");
