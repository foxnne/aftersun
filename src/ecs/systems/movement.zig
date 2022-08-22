const std = @import("std");
const zm = @import("zmath");
const flecs = @import("flecs");
const game = @import("game");
const components = game.components;
const atlas = game.state.atlas;

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
                        // Go ahead and move the tile first.
                        if (tiles[i].x != movements[i].end.x or tiles[i].y != movements[i].end.y or tiles[i].z != movements[i].end.z) {
                            tiles[i] = movements[i].end;
                            tiles[i].counter = game.state.counter.count();
                        }
                        if (flecs.ecs_field(it, components.Cooldown, 4)) |cooldowns| {
                            // Set position as a lerp between beginning and end tile positions.
                            const t = if (cooldowns[i].end > 0.0) cooldowns[i].current / cooldowns[i].end else 0.0;

                            const start_position = components.Position{ .x = @intToFloat(f32, movements[i].start.x) * game.settings.pixels_per_unit, .y = @intToFloat(f32, movements[i].start.y) * game.settings.pixels_per_unit };
                            const end_position = components.Position{ .x = @intToFloat(f32, movements[i].end.x) * game.settings.pixels_per_unit, .y = @intToFloat(f32, movements[i].end.y) * game.settings.pixels_per_unit };

                            
                            flecs.ecs_set_pair(world, entity, &components.Direction{ .value = game.math.Direction.find(8, end_position.x - start_position.x, end_position.y - start_position.y)}, components.Movement);

                            flecs.ecs_set(world, entity, components.Position{
                                .x = game.math.lerp(start_position.x, end_position.x, t),
                                .y = game.math.lerp(start_position.y, end_position.y, t),
                                .z = positions[i].z,
                            });
                        } else {
                            if (flecs.ecs_has_id(world, entity, flecs.ecs_id(components.Player))) {
                                const input = game.state.controls.movement().direction();

                                if (input == .none) {
                                    flecs.ecs_remove_pair(world, entity, components.Request, components.Movement);
                                    flecs.ecs_set_pair( world, entity, &components.Direction{ .value = input }, components.Movement);
                                    
                                } else {
                                    // Set the cooldown and request pairs like the movement request system to avoid an extra frame between.
                                    const cooldown = switch (input) {
                                        .n, .s, .e, .w => 0.4,
                                        else => 0.4 * game.math.sqrt2,
                                    };
                                    flecs.ecs_set_pair_second(world, entity, components.Request, &components.Movement{ .start = tiles[i], .end = .{
                                        .x = tiles[i].x + @floatToInt(i32, input.x()),
                                        .y = tiles[i].y + @floatToInt(i32, input.y()),
                                    } });
                                    flecs.ecs_set_pair(world, entity, &components.Cooldown{ .current = 0.0, .end = cooldown }, components.Movement);
                                }
                            } else {
                                flecs.ecs_remove_pair(world, entity, components.Request, components.Movement);
                                flecs.ecs_set_pair( world, entity, &components.Direction{ .value = .none }, components.Movement);
                            }
                        }
                    }
                }
            }
        }
    }
}
