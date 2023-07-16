const std = @import("std");
const zm = @import("zmath");
const ecs = @import("zflecs");
const game = @import("root");
const components = game.components;

pub fn system() ecs.system_desc_t {
    var desc: ecs.system_desc_t = .{};
    desc.query.filter.terms[0] = .{ .id = ecs.id(components.ParticleAnimator) };
    desc.query.filter.terms[1] = .{ .id = ecs.id(components.ParticleRenderer) };
    desc.query.filter.terms[2] = .{ .id = ecs.id(components.Position) };
    desc.run = run;
    return desc;
}

pub fn run(it: *ecs.iter_t) callconv(.C) void {
    while (ecs.iter_next(it)) {
        var i: usize = 0;
        while (i < it.count()) : (i += 1) {
            if (ecs.field(it, components.ParticleAnimator, 1)) |animators| {
                if (ecs.field(it, components.ParticleRenderer, 2)) |renderers| {
                    const start_life = animators[i].start_life;
                    var particles_to_emit: usize = 0;

                    if (animators[i].state == .play) {
                        if (animators[i].rate > 0.0) {
                            animators[i].time_since_emit += it.delta_time;
                            const emit_time = 1 / animators[i].rate;

                            if (animators[i].time_since_emit >= emit_time) {
                                particles_to_emit = @as(usize, @intFromFloat(@floor(animators[i].time_since_emit / emit_time)));
                            }
                        }
                    }

                    for (renderers[i].particles, 0..) |*particle, j| {
                        if (particle.alive()) {
                            particle.life -= it.delta_time;
                            const t = (start_life - particle.life) / start_life;
                            const color: [4]f32 = .{
                                game.math.lerp(animators[i].start_color[0], animators[i].end_color[0], t),
                                game.math.lerp(animators[i].start_color[1], animators[i].end_color[1], t),
                                game.math.lerp(animators[i].start_color[2], animators[i].end_color[2], t),
                                game.math.lerp(animators[i].start_color[3], animators[i].end_color[3], t),
                            };
                            const index = @as(usize, @intFromFloat(@trunc((@as(f32, @floatFromInt(animators[i].animation.len - 1))) * t)));

                            if (index < animators[i].animation.len)
                                particle.index = animators[i].animation[index];
                            particle.color = color;
                            particle.position[0] += particle.velocity[0] * it.delta_time;
                            particle.position[1] += particle.velocity[1] * it.delta_time;
                            particle.position[2] += particle.velocity[1] * it.delta_time * 1.5;
                        } else if (particles_to_emit > 0) {
                            var new_particle: components.ParticleRenderer.Particle = .{};
                            new_particle.life = animators[i].start_life;

                            if (ecs.field(it, components.Position, 3)) |positions| {
                                new_particle.position[0] = positions[i].x + renderers[i].offset[0];
                                new_particle.position[1] = positions[i].y + renderers[i].offset[1];
                                new_particle.position[2] = positions[i].z;
                            }

                            var prng = std.rand.DefaultPrng.init(@as(u64, @intCast(j)));
                            const rand = prng.random();
                            const t = rand.float(f32);

                            const velocity_x = game.math.lerp(animators[i].velocity_min[0], animators[i].velocity_max[0], t);
                            const velocity_y = game.math.lerp(animators[i].velocity_min[1], animators[i].velocity_max[1], t);

                            new_particle.velocity = .{ velocity_x, velocity_y };
                            new_particle.index = animators[i].animation[0];

                            renderers[i].particles[j] = new_particle;

                            particles_to_emit -= 1;
                            animators[i].time_since_emit = 0.0;
                        }
                    }
                }
            }
        }
    }
}
