const std = @import("std");
const zm = @import("zmath");
const game = @import("game");

pub const Environment = struct {
    transition: f32 = 2.0,
    phases: [4]Phase = [_]Phase{
        .{
            .name = "Sunrise",
            .xy_angle = 295.0,
            .z_angle = 80.0,
            .start = 6.0,
            .end = 8.0,
            .ambient_color = game.math.Color.initBytes(130, 140, 150, 255),
            .shadow_color = game.math.Color.initFloats(0.8, 0.8, 1.0, 1.0),
        },
        .{
            .name = "Day",
            .xy_angle = 0.0,
            .z_angle = 82.0,
            .start = 8.0,
            .end = 19.0,
            .ambient_color = game.math.Color.initBytes(245, 245, 255, 255),
            .shadow_color = game.math.Color.initFloats(0.7, 0.7, 1.0, 1.0),
        },
        .{
            .name = "Sunset",
            .xy_angle = 195.0,
            .z_angle = 76.0,
            .start = 19.0,
            .end = 21.0,
            .ambient_color = game.math.Color.initBytes(130, 140, 150, 255),
            .shadow_color = game.math.Color.initFloats(0.8, 0.8, 1.0, 1.0),
        },
        .{
            .name = "Night",
            .xy_angle = 215.0,
            .z_angle = 82.0,
            .start = 21.0,
            .end = 6.0,
            .ambient_color = game.math.Color.initBytes(50, 50, 120, 255),
            .shadow_color = game.math.Color.initFloats(0.5, 0.5, 0.9, 1.0),
        },
    },

    pub const Phase = struct {
        name: [:0]const u8,
        xy_angle: f32,
        z_angle: f32,
        start: f32,
        end: f32,
        ambient_color: game.math.Color,
        shadow_color: game.math.Color,
    };

    pub fn ambientColor(self: Environment) game.math.Color {
        const time = game.state.time.hour();
        const current_phase = self.phase();
        const next_phase = self.nextPhase();

        if (time >= (current_phase.end - self.transition) and time < current_phase.end) {
            const t = (time - (current_phase.end - self.transition)) / self.transition;
            return current_phase.ambient_color.lerp(next_phase.ambient_color, t);
        }

        return current_phase.ambient_color;
    }

    pub fn shadowColor(self: Environment) game.math.Color {
        const time = game.state.time.hour();
        const current_phase = self.phase();
        const next_phase = self.nextPhase();

        if (time >= (current_phase.end - self.transition) and time < current_phase.end) {
            const t = (time - (current_phase.end - self.transition)) / self.transition;
            return current_phase.shadow_color.lerp(next_phase.shadow_color, t);
        }

        return current_phase.shadow_color;
    }

    pub fn ambientXYAngle(self: Environment) f32 {
        const time = game.state.time.hour();
        const current_phase = self.phase();
        const next_phase = self.nextPhase();

        var t: f32 = 0.0;
        var start: f32 = 0.0;
        var end: f32 = 0.0;

        if (current_phase.xy_angle < next_phase.xy_angle) {
            start = current_phase.xy_angle;
            end = next_phase.xy_angle;
        } else {
            start = current_phase.xy_angle;
            end = 360.0 + next_phase.xy_angle;
        }

        if (current_phase.start < current_phase.end) {
            t = (time - current_phase.start) / (current_phase.end - current_phase.start);
        } else {
            if (time > current_phase.start) {
                const duration = (24.0 - current_phase.start) + current_phase.end;
                t = (time - current_phase.start) / duration;
            } else {
                const duration = (24.0 - current_phase.start) + current_phase.end;
                t = (time + (24.0 - current_phase.start)) / duration;
            }
        }

        return lerp(start, end, t);
    }

    pub fn ambientZAngle(self: Environment) f32 {
        const time = game.state.time.hour();
        const current_phase = self.phase();
        const next_phase = self.nextPhase();

        if (time >= (current_phase.end - self.transition) and time < current_phase.end) {
            const t = (time - (current_phase.end - self.transition)) / self.transition;
            return lerp(current_phase.z_angle, next_phase.z_angle, flip(square(flip(t))));
        }

        return current_phase.z_angle;
    }

    pub fn phase(self: Environment) Phase {
        const time = game.state.time.hour();
        for (self.phases) |p| {
            if (p.start < p.end) {
                if (time >= p.start and time < p.end)
                    return p;
            } else {
                if (time >= p.start or time < p.end)
                    return p;
            }
        }
        return self.phases[0];
    }

    pub fn nextPhase(self: Environment) Phase {
        const time = game.state.time.hour();
        for (self.phases) |p, i| {
            if (p.start < p.end) {
                if (time >= p.start and time < p.end) {
                    if (i < self.phases.len - 1) {
                        return self.phases[i + 1];
                    }
                }
            } else {
                if (time >= p.start or time < p.end) {
                    //night
                    return self.phases[0];
                }
            }
        }
        return self.phases[1];
    }

    fn lerp(a: f32, b: f32, t: f32) f32 {
        return a + (b - a) * t;
    }

    fn flip(a: f32) f32 {
        return 1 - a;
    }

    fn square(a: f32) f32 {
        return a * a;
    }
};
