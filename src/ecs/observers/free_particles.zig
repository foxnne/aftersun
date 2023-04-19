const std = @import("std");
const zm = @import("zmath");
const ecs = @import("zflecs");
const game = @import("root");
const components = game.components;

pub fn observer() ecs.observer_desc_t {
    var observer_desc = std.mem.zeroes(ecs.observer_desc_t);
    observer_desc.filter.terms[0] = std.mem.zeroInit(ecs.term_t, .{ .id = ecs.id(components.ParticleRenderer) });
    observer_desc.events[0] = ecs.EcsOnRemove;
    observer_desc.run = run;
    return observer_desc;
}

pub fn run(it: *ecs.iter_t) callconv(.C) void {
    while (ecs.iter_next(it)) {
        var i: usize = 0;
        while (i < it.count()) : (i += 1) {
            if (ecs.field(it, components.ParticleRenderer, 1)) |renderers| {
                game.state.allocator.free(renderers[i].particles);
            }
        }
    }
}
