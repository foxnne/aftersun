const std = @import("std");
const zm = @import("zmath");
const flecs = @import("flecs");
const game = @import("game");
const components = game.components;

pub fn observer() flecs.EcsObserverDesc {
    var observer_desc = std.mem.zeroes(flecs.EcsObserverDesc);
    observer_desc.filter.terms[0] = std.mem.zeroInit(flecs.EcsTerm, .{ .id = flecs.ecs_id(components.Stack) });
    observer_desc.events[0] = flecs.Constants.EcsOnSet;
    observer_desc.run = run;
    return observer_desc;
}

pub fn run(it: *flecs.EcsIter) callconv(.C) void {
    const world = it.world.?;
    while (flecs.ecs_iter_next(it)) {
        var i: usize = 0;
        while (i < it.count) : (i += 1) {
            const entity = it.entities[i];
            if (flecs.ecs_field(it, components.Stack, 1)) |stacks| {
                if (stacks[i].count == 0) {
                    flecs.ecs_delete(world, entity);
                    continue;
                }
                if (flecs.ecs_get(world, entity, components.StackAnimator)) |animator| {
                    if (flecs.ecs_get_mut(world, entity, components.SpriteRenderer)) |renderer| {

                        var index: usize = 0;
                        for (animator.counts) |count, j| {
                            if (stacks[i].count >= count) {
                                index = j;
                            }
                        }
                        renderer.index = animator.animation[index];
                    }
                }
            }
        }
    }
}
