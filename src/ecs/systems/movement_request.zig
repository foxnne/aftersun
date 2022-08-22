const std = @import("std");
const zm = @import("zmath");
const flecs = @import("flecs");
const game = @import("game");
const components = game.components;
const atlas = game.state.atlas;

pub fn system() flecs.EcsSystemDesc {
    var desc = std.mem.zeroes(flecs.EcsSystemDesc);
    desc.query.filter.terms[0] = std.mem.zeroInit(flecs.EcsTerm, .{ .id = flecs.ecs_id(components.Player), });
    desc.query.filter.terms[1] = std.mem.zeroInit(flecs.EcsTerm, .{ .id = flecs.ecs_id(components.Tile), });
    desc.query.filter.terms[2] = std.mem.zeroInit(flecs.EcsTerm, .{ .id = flecs.ecs_pair(components.Request, components.Movement), .oper = flecs.EcsOperKind.ecs_not });
    desc.query.filter.terms[3] = std.mem.zeroInit(flecs.EcsTerm, .{ .id = flecs.ecs_pair(components.Cooldown, components.Movement), .oper = flecs.EcsOperKind.ecs_not });
    desc.run = run;
    return desc;
}

pub fn run(it: *flecs.EcsIter) callconv(.C) void {
    const world = it.world.?;

    while (flecs.ecs_iter_next(it)) {
        var i: usize = 0;
        while (i < it.count) : (i += 1) {
            const entity = it.entities[i];
            const input_direction = game.state.controls.movement().direction();

            if (input_direction != .none) {
                if (flecs.ecs_field(it, components.Tile, 2)) |current_tiles| {
                    const end_tile = components.Tile{
                        .x = current_tiles[i].x + @floatToInt(i32, input_direction.x()),
                        .y = current_tiles[i].y + @floatToInt(i32, input_direction.y()),
                    };

                    const cooldown = switch (input_direction) {
                        .n, .s, .e, .w => 0.4,
                        else => 0.4 * game.math.sqrt2,
                    };

                    // ! When setting pairs, the intended data type attached must either be matched with a tag, or first in the pair of components.
                    flecs.ecs_set_pair_second(world, entity, components.Request, &components.Movement{ .start = current_tiles[i], .end = end_tile });
                    flecs.ecs_set_pair(world, entity, &components.Cooldown{ .current = 0.0, .end = cooldown }, components.Movement);
                }
            }
        }
    }
}
