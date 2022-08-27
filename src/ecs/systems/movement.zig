const std = @import("std");
const zm = @import("zmath");
const flecs = @import("flecs");
const game = @import("game");
const components = game.components;

pub fn system() flecs.EcsSystemDesc {
    var desc = std.mem.zeroes(flecs.EcsSystemDesc);
    desc.query.filter.terms[0] = std.mem.zeroInit(flecs.EcsTerm, .{ .id = flecs.ecs_id(components.Position) });
    desc.query.filter.terms[1] = std.mem.zeroInit(flecs.EcsTerm, .{ .id = flecs.ecs_id(components.Tile) });
    desc.query.filter.terms[2] = std.mem.zeroInit(flecs.EcsTerm, .{ .id = flecs.ecs_pair(components.Request, components.Movement), .oper = flecs.EcsOperKind.ecs_optional });
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
                        // Go ahead and move the tile first, only once so counter is only set on the actual move.
                        if (tiles[i].x != movements[i].end.x or tiles[i].y != movements[i].end.y or tiles[i].z != movements[i].end.z) {
                            tiles[i] = movements[i].end;
                            tiles[i].counter = game.state.counter.count();
                        }

                        if (flecs.ecs_field(it, components.Cooldown, 4)) |cooldowns| {
                            // Set position as a lerp between beginning and end tile positions.
                            const t = if (cooldowns[i].end > 0.0) cooldowns[i].current / cooldowns[i].end else 0.0;

                            const start_position = movements[i].start.toPosition().toF32x4();
                            const end_position = movements[i].end.toPosition().toF32x4();
                            const difference = end_position - start_position;
                            const direction = game.math.Direction.find(8, difference[0], difference[1]);
                            const direction_vector = direction.f32x4();
                            
                            flecs.ecs_set_pair(world, entity, &components.Direction{ .value = game.math.Direction.find(8, difference[0], difference[1])}, components.Movement);

                            const position = zm.lerp(start_position, end_position, t);

                            positions[i].x = position[0];
                            positions[i].y = position[1];
                            positions[i].z = position[2]; 

                            if (flecs.ecs_get_mut(world, entity, components.Velocity)) |velocity| {
                                velocity.x = if (direction_vector[0] - velocity.x != 0.0) game.math.lerp(velocity.x, direction_vector[0], t) else direction_vector[0];
                                velocity.y = if (direction_vector[1] - velocity.y != 0.0) game.math.lerp(velocity.y, direction_vector[1], t) else direction_vector[1];
                            } else {
                                flecs.ecs_set(world, entity, &components.Velocity{ .x = direction_vector[0] * t, .y = direction_vector[1] * t });
                            }
                        } else {
                            if (flecs.ecs_has_id(world, entity, flecs.ecs_id(components.Player))) {
                                const input = game.state.controls.movement().direction();

                                if (input == .none) {
                                    flecs.ecs_remove_pair(world, entity, components.Request, components.Movement);
                                    flecs.ecs_set_pair( world, entity, &components.Direction{ .value = input }, components.Movement);
                                } else {
                                    // Set the cooldown and request pairs like the movement request system to avoid an extra frame between.
                                    const cooldown = switch (input) {
                                        .n, .s, .e, .w => game.settings.movement_cooldown,
                                        else => game.settings.movement_cooldown * game.math.sqrt2,
                                    };
                                    const start = tiles[i];
                                    const end = components.Tile{ 
                                        .x = tiles[i].x + @floatToInt(i32, input.x()),
                                        .y = tiles[i].y + @floatToInt(i32, input.y()),
                                    };

                                    flecs.ecs_set_pair_second(world, entity, components.Request, &components.Movement{ .start = start, .end = end});
                                    flecs.ecs_set_pair(world, entity, &components.Cooldown{ .current = 0.0, .end = cooldown }, components.Movement);
                                }
                            } else {
                                flecs.ecs_remove_pair(world, entity, components.Request, components.Movement);
                                flecs.ecs_set_pair( world, entity, &components.Direction{ .value = .none }, components.Movement);
                                flecs.ecs_set(world, entity, &components.Velocity{});
                            }
                        }
                    } else {
                        if (flecs.ecs_get_mut(world, entity, components.Velocity)) |velocity| {
                            const step = it.delta_time * 2;
                            velocity.x = if (velocity.x > step) velocity.x - step else if (velocity.x > 0.0 and velocity.x < step) velocity.x - velocity.x else if (velocity.x < -step) velocity.x + step else if (velocity.x < 0.0 and velocity.x > -step) velocity.x - velocity.x else 0.0;
                            velocity.y = if (velocity.y > step) velocity.y - step else if (velocity.y > 0.0 and velocity.y < step) velocity.y - velocity.y else if (velocity.y < -step) velocity.y + step else if (velocity.y < 0.0 and velocity.y > -step) velocity.y - velocity.y else 0.0;
                        }
                    }
                }
            }
        }
    }
}
