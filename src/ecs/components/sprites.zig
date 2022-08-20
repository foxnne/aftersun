const game = @import("game");
const gfx = game.gfx;
const math = game.math;

pub const SpriteRenderer = struct {
    index: usize = 0,
    flip_x: bool = false,
    flip_y: bool = false,
    color: math.Color = math.Colors.white,
    frag_mode: gfx.Batcher.SpriteOptions.FragRenderMode = .standard,
    vert_mode: gfx.Batcher.SpriteOptions.VertRenderMode = .standard,
    order: usize = 0,
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
