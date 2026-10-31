/// Supply a no-op registration callback for isolated extension entrypoint tests.
pub fn register(_: *gdzig.extension.Registry) void {}

const gdzig = @import("gdzig");
