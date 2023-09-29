const zm = @import("zmath");
const game = @import("root");

const AnimationSet = game.animation_sets.AnimationSet;

pub const CharacterAnimator = struct {
    head_set: AnimationSet,
    body_set: AnimationSet,
    top_set: AnimationSet,
    bottom_set: AnimationSet,
    hair_set: AnimationSet,
    frame: usize = 0,
    elapsed: f32 = 0,
    fps: usize = 10,
    state: State = State.idle,

    pub const State = enum { idle, walk };
};

pub const CharacterRenderer = struct {
    head_index: usize,
    body_index: usize,
    hair_index: usize,
    top_index: usize,
    bottom_index: usize,
    head_color: [4]f32 = game.math.Color.initBytes(0, 0, 0, 255).toSlice(),
    body_color: [4]f32 = game.math.Color.initBytes(0, 0, 0, 255).toSlice(),
    hair_color: [4]f32 = game.math.Color.initBytes(0, 0, 0, 255).toSlice(),
    top_color: [4]f32 = game.math.Color.initBytes(0, 0, 0, 255).toSlice(),
    bottom_color: [4]f32 = game.math.Color.initBytes(0, 0, 0, 255).toSlice(),
    flip_body: bool = false,
    flip_head: bool = false,
};
