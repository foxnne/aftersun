const game = @import("../../aftersun.zig");
const gfx = game.gfx;
const math = game.math;

pub const LightRenderer = struct {
    index: usize = 0,
    scale: [2]f32 = .{ 1.0, 1.0 },
    offset: [2]f32 = .{ 0.0, 0.0 },
    color: [4]f32 = math.Colors.white.toSlice(),
};
