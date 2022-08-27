const std = @import("std");
const zm = @import("zmath");
const flecs = @import("flecs");
const game = @import("game");
const components = game.components;

pub fn system() flecs.EcsSystemDesc {
    var desc = std.mem.zeroes(flecs.EcsSystemDesc);
    desc.query.filter.terms[0] = std.mem.zeroInit(flecs.EcsTerm, .{ .id = flecs.ecs_pair(components.Cooldown, flecs.Constants.EcsWildcard) });
    desc.run = run;
    return desc;
}

pub fn run(it: *flecs.EcsIter) callconv(.C) void {
    const world = it.world.?;

    while (flecs.ecs_iter_next(it)) {
        var i: usize = 0;
        while (i < it.count) : (i += 1) {
            const entity = it.entities[i];

            if (flecs.ecs_field(it, components.Cooldown, 1)) |cooldowns| {

                if (cooldowns[i].current >= cooldowns[i].end) {
                    const pair_id = flecs.ecs_field_id(it, 1);
                    flecs.ecs_remove_id(world, entity, pair_id);
                }
                cooldowns[i].current += it.delta_time;
            }
        }
    }
}
