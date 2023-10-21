const game = @import("../../aftersun.zig");
const gfx = game.gfx;
const math = game.math;

pub const SpriteRenderer = struct {
    index: usize = 0,
    flip_x: bool = false,
    flip_y: bool = false,
    color: [4]f32 = math.Colors.white.toSlice(),
    frag_mode: gfx.Batcher.SpriteOptions.FragRenderMode = .standard,
    vert_mode: gfx.Batcher.SpriteOptions.VertRenderMode = .standard,
    order: usize = 0,
    reflect: bool = false,
};

pub const SpriteAnimator = struct {
    animation: []usize,
    frame: usize = 0,
    elapsed: f32 = 0,
    fps: usize = 8,
    state: State = State.pause,

    pub const State = enum {
        pause,
        play,
    };
};
