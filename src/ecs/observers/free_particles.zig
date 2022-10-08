const std = @import("std");
const zm = @import("zmath");
const flecs = @import("flecs");
const game = @import("game");
const components = game.components;

pub fn observer() flecs.EcsObserverDesc {
    var observer_desc = std.mem.zeroes(flecs.EcsObserverDesc);
    observer_desc.filter.terms[0] = std.mem.zeroInit(flecs.EcsTerm, .{ .id = flecs.ecs_id(components.ParticleRenderer) });
    observer_desc.events[0] = flecs.Constants.EcsOnRemove;
    observer_desc.run = run;
    return observer_desc;
}

pub fn run(it: *flecs.EcsIter) callconv(.C) void {
    while (flecs.ecs_iter_next(it)) {
        var i: usize = 0;
        while (i < it.count) : (i += 1) {
            if (flecs.ecs_field(it, components.ParticleRenderer, 1)) |renderers| {
                game.state.allocator.free(renderers[i].particles);
            }
        }
    }
}
