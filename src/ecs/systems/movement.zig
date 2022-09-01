const std = @import("std");
const zm = @import("zmath");
const flecs = @import("flecs");
const game = @import("game");
const components = game.components;

pub fn system() flecs.EcsSystemDesc {
    var desc = std.mem.zeroes(flecs.EcsSystemDesc);
    desc.query.filter.terms[0] = std.mem.zeroInit(flecs.EcsTerm, .{ .id = flecs.ecs_id(components.Position) });
    desc.query.filter.terms[1] = std.mem.zeroInit(flecs.EcsTerm, .{ .id = flecs.ecs_id(components.Tile) });
    desc.query.filter.terms[2] = std.mem.zeroInit(flecs.EcsTerm, .{ .id = flecs.ecs_pair(components.Request, components.Movement) });
    desc.query.filter.terms[3] = std.mem.zeroInit(flecs.EcsTerm, .{ .id = flecs.ecs_pair(components.Cooldown, components.Movement), .oper = flecs.EcsOperKind.ecs_optional });
    desc.run = run;
    return desc;
}

pub fn run(it: *flecs.EcsIter) callconv(.C) void {
    const world = it.world.?;

    while (flecs.ecs_iter_next(it)) {
        var i: usize = 0;
        while (i < it.count) : (i += 1) {
            const entity = it.entities[i];
            if (flecs.ecs_field(it, components.Position, 1)) |positions| {
                if (flecs.ecs_field(it, components.Tile, 2)) |tiles| {
                    if (flecs.ecs_field(it, components.Movement, 3)) |movements| {
                        if (flecs.ecs_field(it, components.Cooldown, 4)) |cooldowns| {

                            // Get progress of the lerp using cooldown duration
                            const t = if (cooldowns[i].end > 0.0) cooldowns[i].current / cooldowns[i].end else 0.0;

                            const start_position = movements[i].start.toPosition().toF32x4();
                            const end_position = movements[i].end.toPosition().toF32x4();
                            const difference = end_position - start_position;
                            const direction = game.math.Direction.find(8, difference[0], difference[1]);

                            // Update movement direction
                            flecs.ecs_set_pair(world, entity, &components.Direction{ .value = direction }, components.Movement);

                            // Update position
                            const position = zm.lerp(start_position, end_position, t);
                            positions[i].x = position[0];
                            positions[i].y = position[1];
                            positions[i].z = position[2];
                        } else if (tiles[i].x != movements[i].end.x or tiles[i].y != movements[i].end.y or tiles[i].z != movements[i].end.z) {
                            // If cooldown is not yet present, but move request is, we are in the frame before cooldown is added.
                            // Move the tile, only once so counter is only set on the actual move.
                            tiles[i] = movements[i].end;
                            tiles[i].counter = game.state.counter.count();

                            // Set modified so that observers are triggered.
                            flecs.ecs_modified_id(world, entity, flecs.ecs_id(components.Tile));
                        }
                    }
                }
            }
        }
    }
}
