const std = @import("std");
const zm = @import("zmath");
const flecs = @import("flecs");
const game = @import("root");
const components = game.components;

pub fn system() flecs.EcsSystemDesc {
    var desc = std.mem.zeroes(flecs.EcsSystemDesc);
    desc.query.filter.terms[0] = std.mem.zeroInit(flecs.EcsTerm, .{ .id = flecs.ecs_id(components.SpriteAnimator) });
    desc.query.filter.terms[1] = std.mem.zeroInit(flecs.EcsTerm, .{ .id = flecs.ecs_id(components.SpriteRenderer) });
    desc.run = run;
    return desc;
}

pub fn run(it: *flecs.EcsIter) callconv(.C) void {
    while (flecs.ecs_iter_next(it)) {
        var i: usize = 0;
        while (i < it.count) : (i += 1) {
            if (flecs.ecs_field(it, components.SpriteAnimator, 1)) |animators| {
                if (flecs.ecs_field(it, components.SpriteRenderer, 2)) |renderers| {
                    if (animators[i].state == components.SpriteAnimator.State.play) {
                        animators[i].elapsed += it.delta_time;

                        if (animators[i].elapsed > (1.0 / @intToFloat(f32, animators[i].fps))) {
                            animators[i].elapsed = 0.0;

                            if (animators[i].frame < animators[i].animation.len - 1) {
                                animators[i].frame += 1;
                            } else animators[i].frame = 0;
                        }
                        renderers[i].index = animators[i].animation[animators[i].frame];
                    }
                }
            }
        }
    }
}
