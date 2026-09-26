//! The engine's scalar slot-width convention: every integer, enum, or packed
//! flag struct narrower than 64 bits travels as a full `int64_t` slot
//! (`uint64_t` for `u64`-backed values); `f32` travels as `double`. Everything
//! else uses its declared layout.
//!
//! Marshalling code must read and write scalars at this width: writing a
//! narrow value at its declared width leaks uninitialized bytes into what the
//! engine reads, and the engine's slot-width writes overflow a narrow local.
const std = @import("std");

/// The slot-width box for `T` (see module doc): an extern struct wrapping the
/// raw slot value, so a pointer to it can be handed to the engine directly.
pub fn Type(comptime T: type) type {
    return extern struct {
        const Self = @This();

        raw: Raw,

        /// The raw type the engine reads/writes for `T`.
        pub const Raw = switch (@typeInfo(T)) {
            .int => if (isU64Like(T)) T else i64,
            .@"enum" => |info| if (isU64Like(info.tag_type)) info.tag_type else i64,
            .@"struct" => |info| if (info.backing_integer) |backing|
                (if (isU64Like(backing)) backing else i64)
            else
                T,
            .float => f64,
            else => T,
        };

        /// Widens `value` to its slot width.
        pub fn widen(value: T) Self {
            return .{ .raw = switch (@typeInfo(T)) {
                .int => @intCast(value),
                .@"enum" => @intCast(@intFromEnum(value)),
                .@"struct" => |info| blk: {
                    const Backing = info.backing_integer orelse break :blk value;
                    break :blk @as(Raw, @intCast(@as(Backing, @bitCast(value))));
                },
                .float => @floatCast(value),
                else => value,
            } };
        }

        /// Narrows the slot-width value back to `T`.
        pub fn narrow(self: Self) T {
            return switch (@typeInfo(T)) {
                .int => @intCast(self.raw),
                .@"enum" => |info| @enumFromInt(@as(info.tag_type, @intCast(self.raw))),
                .@"struct" => |info| blk: {
                    const Backing = info.backing_integer orelse break :blk self.raw;
                    break :blk @bitCast(@as(Backing, @intCast(self.raw)));
                },
                .float => @floatCast(self.raw),
                else => self.raw,
            };
        }
    };
}

/// `u64` is the only integer width that gets its own native slot; every
/// other integer (regardless of signedness or width, up to 64 bits) travels
/// as `int64_t`.
pub fn isU64Like(comptime Int: type) bool {
    const info = @typeInfo(Int).int;
    return info.bits == 64 and info.signedness == .unsigned;
}
