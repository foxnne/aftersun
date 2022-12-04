const std = @import("std");
const zm = @import("zmath");
const flecs = @import("flecs");
const game = @import("game");
const components = game.components;

pub fn system() flecs.EcsSystemDesc {
    var desc = std.mem.zeroes(flecs.EcsSystemDesc);
    desc.query.filter.terms[0] = std.mem.zeroInit(flecs.EcsTerm, .{ .id = flecs.ecs_id(components.Player) });
    desc.query.filter.terms[1] = std.mem.zeroInit(flecs.EcsTerm, .{ .id = flecs.ecs_id(components.Tile) });
    desc.query.filter.terms[2] = std.mem.zeroInit(flecs.EcsTerm, .{ .id = flecs.ecs_pair(components.Request, components.Movement), .oper = flecs.EcsOperKind.ecs_not });
    desc.query.filter.terms[3] = std.mem.zeroInit(flecs.EcsTerm, .{ .id = flecs.ecs_pair(components.Cooldown, components.Movement), .oper = flecs.EcsOperKind.ecs_not });
    desc.no_staging = true;
    desc.run = run;
    return desc;
}

pub fn run(it: *flecs.EcsIter) callconv(.C) void {
    const world = it.world.?;

    while (flecs.ecs_iter_next(it)) {
        var i: usize = 0;
        while (i < it.count) : (i += 1) {
            const entity = it.entities[i];

            if (entity != game.state.entities.player) break;

            const direction = game.state.controls.movement();
            if (flecs.ecs_field(it, components.Tile, 2)) |tiles| {
                if (direction != .none) {
                    const end_tile = components.Tile{
                        .x = tiles[i].x + @floatToInt(i32, direction.x()),
                        .y = tiles[i].y + @floatToInt(i32, direction.y()),
                    };

                    // ! When setting pairs, the intended data type attached must either be matched with a tag, or first in the pair of components.
                    flecs.ecs_set_pair_second(world, entity, components.Request, &components.Movement{ .start = tiles[i], .end = end_tile });

                    // Set cooldown
                    const cooldown = switch (direction) {
                        .n, .s, .e, .w => game.settings.movement_cooldown,
                        else => game.settings.movement_cooldown * game.math.sqrt2,
                    };
                    flecs.ecs_set_pair(world, entity, &components.Cooldown{ .current = 0.0, .end = cooldown }, components.Movement);
                } else {
                    // Zero movement direction.
                    flecs.ecs_add_pair(world, entity, components.Direction.none, components.Movement);
                }
            }
        }
    }
}
