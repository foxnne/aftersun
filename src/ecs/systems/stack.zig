const std = @import("std");
const zm = @import("zmath");
const flecs = @import("flecs");
const game = @import("root");
const components = game.components;

pub fn system() flecs.system_desc_t {
    var desc = std.mem.zeroes(flecs.system_desc_t);
    desc.query.filter.terms[0] = std.mem.zeroInit(flecs.term_t, .{ .id = flecs.id(components.Stack) });
    desc.query.filter.terms[1] = std.mem.zeroInit(flecs.term_t, .{ .id = flecs.ecs_pair(components.Request, components.Stack) });
    desc.query.filter.terms[2] = std.mem.zeroInit(flecs.term_t, .{ .id = flecs.ecs_pair(components.RequestZeroOther, components.Stack), .oper = flecs.EcsOperKind.ecs_optional });
    desc.query.filter.terms[3] = std.mem.zeroInit(flecs.term_t, .{ .id = flecs.ecs_pair(components.Cooldown, components.Movement), .oper = flecs.EcsOperKind.ecs_not });

    desc.run = run;
    return desc;
}

pub fn run(it: *flecs.iter_t) callconv(.C) void {
    const world = it.world.?;

    while (flecs.iter_next(it)) {
        var i: usize = 0;
        while (i < it.count()) : (i += 1) {
            const entity = it.entities[i];
            if (flecs.field(it, components.Stack, 1)) |stacks| {
                if (flecs.field(it, components.Stack, 2)) |requests| {
                    if (flecs.field(it, components.RequestZeroOther, 3)) |request_others| {
                        if (flecs.ecs_get_mut(world, request_others[i].target, components.Stack)) |stack| {
                            stack.count = 0;
                            flecs.ecs_modified_id(world, request_others[i].target, flecs.id(components.Stack));
                        }
                        flecs.ecs_remove_pair(world, entity, components.RequestZeroOther, components.Stack);
                    }

                    stacks[i].count = requests[i].count;
                    stacks[i].max = requests[i].max;
                    flecs.ecs_modified_id(world, entity, flecs.id(components.Stack));
                    flecs.ecs_remove_pair(world, entity, components.Request, components.Stack);
                }
            }
        }
    }
}
