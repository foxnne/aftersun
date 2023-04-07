const std = @import("std");
const game = @import("root");

pub const Time = struct {
    start_time: f32 = 6.0,
    scale: f32 = 480.0,

    /// Returns a number between 0 and 24 representing the current hour.
    pub fn hour(self: Time) f32 {
        const days = self.day() - @trunc(self.day());
        return days * 24.0;
    }

    /// Returns a number where the decimal point is progress of the current day.
    pub fn day(self: Time) f32 {
        const seconds = game.state.gctx.stats.time * @floatCast(f64, self.scale) + (self.start_time * 60.0 * 60.0);
        return @floatCast(f32, seconds / (60.0 * 60.0 * 24.0));
    }
};
