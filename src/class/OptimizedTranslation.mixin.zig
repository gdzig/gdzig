// @mixin start

/// Godot 4.6 has no failure result, so the legacy adapter returns true after generation.
fn generate_4_6(self: *Self, p_from: *gdzig.class.Translation) bool {
    self.generate_4_6_legacy(p_from);
    return true;
}

// @mixin stop

const gdzig = @import("gdzig");
const Self = gdzig.class.OptimizedTranslation;
