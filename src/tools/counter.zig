const std = @import("std");
const game = @import("../aftersun.zig");

pub const Counter = struct {
    value: u64 = 0,

    pub fn count(self: *Counter) u64 {
        if (self.value == std.math.maxInt(u64)) {
            self.value = 0;
            std.log.debug("[{s}] Counter rolled over to 0, errors to be expected.", .{game.name});
        }
        self.value += 1;
        return self.value;
    }
};
