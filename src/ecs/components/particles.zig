const game = @import("root");
const gfx = game.gfx;
const math = game.math;
const zm = @import("zmath");

pub const ParticleRenderer = struct {
    particles: []Particle,
    offset: zm.F32x4 = zm.f32x4s(0),

    pub const Particle = struct {
        life: f32 = 0.0,
        position: [3]f32 = .{ 0.0, 0.0, 0.0 },
        velocity: [2]f32 = .{ 0.0, 0.0 },
        index: usize = 0,
        color: math.Color = math.Colors.white,

        pub fn alive(self: Particle) bool {
            return self.life > 0.0;
        }
    };
};

pub const ParticleAnimator = struct {
    animation: []usize,
    time_since_emit: f32 = 0.0,
    rate: f32 = 1.0,
    start_life: f32 = 1.0,
    velocity_min: [2]f32,
    velocity_max: [2]f32,
    start_color: math.Color = math.Colors.white,
    end_color: math.Color = math.Colors.white,
    state: State = .play,

    pub const State = enum {
        pause,
        play,
    };
};
