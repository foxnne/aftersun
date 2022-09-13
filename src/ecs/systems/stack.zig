const std = @import("std");
const zm = @import("zmath");
const flecs = @import("flecs");
const game = @import("game");
const components = game.components;

pub fn system() flecs.EcsSystemDesc {
    var desc = std.mem.zeroes(flecs.EcsSystemDesc);
    desc.query.filter.terms[0] = std.mem.zeroInit(flecs.EcsTerm, .{ .id = flecs.ecs_id(components.Stack) });
    desc.query.filter.terms[1] = std.mem.zeroInit(flecs.EcsTerm, .{ .id = flecs.ecs_pair(components.Request, components.Stack) });
    desc.query.filter.terms[2] = std.mem.zeroInit(flecs.EcsTerm, .{ .id = flecs.ecs_pair(components.Cooldown, components.Movement), .oper = flecs.EcsOperKind.ecs_not });
    desc.run = run;
    return desc;
}

pub fn run(it: *flecs.EcsIter) callconv(.C) void {
    const world = it.world.?;

    while (flecs.ecs_iter_next(it)) {
        var i: usize = 0;
        while (i < it.count) : (i += 1) {
            const entity = it.entities[i];
            if (flecs.ecs_field(it, components.Stack, 1)) |stacks| {
                if (flecs.ecs_field(it, components.Stack, 2)) |requests| {
                    if (flecs.ecs_get_pair(world, entity, components.WaitForRemove, flecs.Constants.EcsWildcard)) |wait| {
                        const id = flecs.ecs_get_target(world, entity, flecs.ecs_id(components.WaitForRemove), 0);
                        if (id != 0) {
                            if (flecs.ecs_has_id(world, wait.target, id)) {
                                return;
                            } else {
                                flecs.ecs_remove_pair(world, entity, components.WaitForRemove, id);
                                return;
                            }
                        }
                    }

                    stacks[i].count = requests[i].count;
                    stacks[i].max = requests[i].max;
                    flecs.ecs_modified_id(world, entity, flecs.ecs_id(components.Stack));
                    flecs.ecs_remove_pair(world, entity, components.Request, components.Stack);
                }
            }
        }
    }
}
