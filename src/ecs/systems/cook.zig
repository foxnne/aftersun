const std = @import("std");
const zm = @import("zmath");
const flecs = @import("flecs");
const game = @import("root");
const components = game.components;

pub fn system() flecs.system_desc_t {
    var desc = std.mem.zeroes(flecs.system_desc_t);
    desc.query.filter.terms[0] = std.mem.zeroInit(flecs.term_t, .{ .id = flecs.id(components.Raw), .oper = flecs.EcsOperKind.ecs_optional });
    desc.query.filter.terms[1] = std.mem.zeroInit(flecs.term_t, .{ .id = flecs.id(components.Cook) });
    desc.query.filter.terms[2] = std.mem.zeroInit(flecs.term_t, .{ .id = flecs.id(components.Stack), .oper = flecs.EcsOperKind.ecs_optional });
    desc.query.filter.terms[3] = std.mem.zeroInit(flecs.term_t, .{ .id = flecs.id(components.Position) });
    desc.query.filter.terms[4] = std.mem.zeroInit(flecs.term_t, .{ .id = flecs.id(components.Tile) });
    desc.query.filter.terms[5] = std.mem.zeroInit(flecs.term_t, .{ .id = flecs.ecs_pair(components.Cooldown, components.Movement), .oper = flecs.EcsOperKind.ecs_not });
    desc.run = run;
    return desc;
}

pub fn run(it: *flecs.iter_t) callconv(.C) void {
    const world = it.world.?;

    while (flecs.iter_next(it)) {
        var i: usize = 0;
        while (i < it.count()) : (i += 1) {
            const entity = it.entities[i];

            if (flecs.field(it, components.Raw, 1)) |raws| {
                if (flecs.field(it, components.Position, 4)) |positions| {
                    if (flecs.field(it, components.Tile, 5)) |tiles| {
                        const new = flecs.ecs_new_w_pair(world, flecs.Constants.EcsIsA, raws[i].cooked_prefab);
                        var tile = tiles[i];
                        tile.z += 1;

                        flecs.ecs_set(world, new, positions[i]);
                        flecs.ecs_set(world, new, &tile);

                        flecs.ecs_set_pair_second(world, new, components.Request, &components.Movement{
                            .start = tile,
                            .end = tiles[i],
                            .curve = .sin,
                        });
                        flecs.ecs_set_pair(world, new, &components.Cooldown{ .end = game.settings.movement_cooldown / 2 }, components.Movement);
                        if (flecs.field(it, components.Stack, 3)) |stacks| {
                            if (stacks[i].count > 0) {
                                stacks[i].count -= 1;
                                flecs.ecs_modified_id(world, entity, flecs.id(components.Stack));

                                flecs.ecs_set_pair_second(world, entity, components.Request, &components.Movement{
                                    .start = tile,
                                    .end = tiles[i],
                                    .curve = .sin,
                                });
                                flecs.ecs_set_pair(world, entity, &components.Cooldown{ .end = game.settings.movement_cooldown / 2 }, components.Movement);
                                flecs.ecs_remove(world, entity, components.Cook);
                            }
                        } else {
                            flecs.ecs_delete(world, entity);
                        }
                    }
                }
            } else {
                flecs.ecs_remove(world, entity, components.Cook);
            }
        }
    }
}
