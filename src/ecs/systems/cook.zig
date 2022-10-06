const std = @import("std");
const zm = @import("zmath");
const flecs = @import("flecs");
const game = @import("game");
const components = game.components;

pub fn system() flecs.EcsSystemDesc {
    var desc = std.mem.zeroes(flecs.EcsSystemDesc);
    desc.query.filter.terms[0] = std.mem.zeroInit(flecs.EcsTerm, .{ .id = flecs.ecs_id(components.Raw), .oper = flecs.EcsOperKind.ecs_optional });
    desc.query.filter.terms[1] = std.mem.zeroInit(flecs.EcsTerm, .{ .id = flecs.ecs_id(components.Cook) });
    desc.query.filter.terms[2] = std.mem.zeroInit(flecs.EcsTerm, .{ .id = flecs.ecs_id(components.Stack), .oper = flecs.EcsOperKind.ecs_optional });
    desc.query.filter.terms[3] = std.mem.zeroInit(flecs.EcsTerm, .{ .id = flecs.ecs_id(components.Position) });
    desc.query.filter.terms[4] = std.mem.zeroInit(flecs.EcsTerm, .{ .id = flecs.ecs_id(components.Tile) });
    desc.query.filter.terms[5] = std.mem.zeroInit(flecs.EcsTerm, .{ .id = flecs.ecs_pair(components.Cooldown, components.Movement), .oper = flecs.EcsOperKind.ecs_not });
    desc.run = run;
    return desc;
}

pub fn run(it: *flecs.EcsIter) callconv(.C) void {
    const world = it.world.?;

    while (flecs.ecs_iter_next(it)) {
        var i: usize = 0;
        while (i < it.count) : (i += 1) {
            const entity = it.entities[i];

            if (flecs.ecs_field(it, components.Raw, 1)) |raws| {
                if (flecs.ecs_field(it, components.Position, 4)) |positions| {
                    if (flecs.ecs_field(it, components.Tile, 5)) |tiles| {
                        const new = flecs.ecs_new_w_pair(world, flecs.Constants.EcsIsA, raws[i].cooked_prefab);

                        flecs.ecs_set(world, new, positions[i]);
                        flecs.ecs_set(world, new, tiles[i]);

                        flecs.ecs_set_pair_second(world, new, components.Request, &components.Movement{
                            .start = .{ .x = tiles[i].x, .y = tiles[i].y, .z = tiles[i].z + 1 },
                            .end = .{ .x = tiles[i].x, .y = tiles[i].y, .z = tiles[i].z },
                            .curve = .sin,
                        });
                        flecs.ecs_set_pair(world, new, &components.Cooldown{ .end = game.settings.movement_cooldown / 2 }, components.Movement);
                        if (flecs.ecs_field(it, components.Stack, 3)) |stacks| {
                            if (stacks[i].count > 0) {
                                stacks[i].count -= 1;
                                flecs.ecs_modified_id(world, entity, flecs.ecs_id(components.Stack));

                                flecs.ecs_set_pair_second(world, entity, components.Request, &components.Movement{
                                    .start = .{ .x = tiles[i].x, .y = tiles[i].y, .z = tiles[i].z + 1 },
                                    .end = .{ .x = tiles[i].x, .y = tiles[i].y, .z = tiles[i].z },
                                    .curve = .sin,
                                    .increase_counter = false,
                                });
                                flecs.ecs_set_pair(world, entity, &components.Cooldown{ .end = game.settings.movement_cooldown / 2 }, components.Movement);
                                flecs.ecs_remove(world, entity, components.Cook);
                            }
                        } else {
                            flecs.ecs_delete(world, entity);
                            flecs.ecs_remove(world, entity, components.Cook);
                        }
                    }
                }
            } else {
                flecs.ecs_remove(world, entity, components.Cook);
            }
        }
    }
}
