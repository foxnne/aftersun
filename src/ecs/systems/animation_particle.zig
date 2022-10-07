const std = @import("std");
const zm = @import("zmath");
const flecs = @import("flecs");
const game = @import("game");
const components = game.components;

pub fn system() flecs.EcsSystemDesc {
    var desc = std.mem.zeroes(flecs.EcsSystemDesc);
    desc.query.filter.terms[0] = std.mem.zeroInit(flecs.EcsTerm, .{ .id = flecs.ecs_id(components.ParticleAnimator) });
    desc.query.filter.terms[1] = std.mem.zeroInit(flecs.EcsTerm, .{ .id = flecs.ecs_id(components.ParticleRenderer) });
    desc.query.filter.terms[2] = std.mem.zeroInit(flecs.EcsTerm, .{ .id = flecs.ecs_id(components.Position) });
    desc.run = run;
    return desc;
}

pub fn run(it: *flecs.EcsIter) callconv(.C) void {
    while (flecs.ecs_iter_next(it)) {
        var i: usize = 0;
        while (i < it.count) : (i += 1) {
            if (flecs.ecs_field(it, components.ParticleAnimator, 1)) |animators| {
                if (flecs.ecs_field(it, components.ParticleRenderer, 2)) |renderers| {
                    const start_life = animators[i].start_life;
                    var particles_to_emit: usize = 0;

                    if (animators[i].state == .play) {
                        if (animators[i].rate > 0.0) {
                            animators[i].time_since_emit += it.delta_time;
                            const emit_time = 1 / animators[i].rate;

                            if (animators[i].time_since_emit >= emit_time) {
                                particles_to_emit = @floatToInt(usize, @floor(animators[i].time_since_emit / emit_time));
                            }
                        }
                    }

                    for (renderers[i].particles) |*particle, j| {
                        if (particle.alive()) {
                            particle.life -= it.delta_time;
                            const t = (start_life - particle.life) / start_life;
                            const color = animators[i].start_color.lerp(animators[i].end_color, t);
                            const index = @floatToInt(usize, @trunc((@intToFloat(f32, animators[i].animation.len - 1)) * t));

                            if (index < animators[i].animation.len)
                                particle.index = animators[i].animation[index];
                            particle.color = color;
                            particle.position[0] += particle.velocity[0];
                            particle.position[1] += particle.velocity[1];
                        } else if (particles_to_emit > 0) {
                            var new_particle: components.ParticleRenderer.Particle = .{};
                            new_particle.life = animators[i].start_life;

                            if (flecs.ecs_field(it, components.Position, 3)) |positions| {
                                new_particle.position[0] = positions[i].x + renderers[i].offset[0];
                                new_particle.position[1] = positions[i].y + renderers[i].offset[1];
                                new_particle.position[2] = positions[i].z;
                            }

                            var prng = std.rand.DefaultPrng.init(@intCast(u64, j));
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
