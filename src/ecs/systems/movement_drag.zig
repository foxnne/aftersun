const std = @import("std");
const zm = @import("zmath");
const flecs = @import("flecs");
const game = @import("game");
const components = game.components;

pub fn groupBy(world: ?*flecs.EcsWorld, table: ?*flecs.EcsTable, id: flecs.EcsId, ctx: ?*anyopaque) callconv(.C) flecs.EcsId {
    _ = ctx;
    var match: flecs.EcsId = 0;
    if (flecs.ecs_search(world, table, flecs.ecs_pair(id, flecs.Constants.EcsWildcard), &match) != -1) {
        return flecs.ecs_pair_second(match);
    }
    return 0;
}

pub fn system(world: *flecs.EcsWorld) flecs.EcsSystemDesc {
    var desc = std.mem.zeroes(flecs.EcsSystemDesc);
    desc.query.filter.terms[0] = std.mem.zeroInit(flecs.EcsTerm, .{ .id = flecs.ecs_id(components.Player) });
    desc.query.filter.terms[1] = std.mem.zeroInit(flecs.EcsTerm, .{ .id = flecs.ecs_id(components.Tile) });
    desc.query.filter.terms[2] = std.mem.zeroInit(flecs.EcsTerm, .{ .id = flecs.ecs_pair(components.Request, components.Drag) });
    desc.run = run;

    var ctx_desc = std.mem.zeroes(flecs.EcsQueryDesc);
    ctx_desc.filter.terms[0] = std.mem.zeroInit(flecs.EcsTerm, .{ .id = flecs.ecs_pair(components.Cell, flecs.Constants.EcsWildcard) });
    ctx_desc.filter.terms[1] = std.mem.zeroInit(flecs.EcsTerm, .{ .id = flecs.ecs_id(components.Tile) });
    ctx_desc.filter.terms[2] = std.mem.zeroInit(flecs.EcsTerm, .{ .id = flecs.ecs_id(components.Stack), .oper = flecs.EcsOperKind.ecs_optional });
    ctx_desc.group_by = groupBy;
    ctx_desc.group_by_id = flecs.ecs_id(components.Cell);
    ctx_desc.order_by = orderBy;
    ctx_desc.order_by_component = flecs.ecs_id(components.Tile);
    desc.ctx = flecs.ecs_query_init(world, &ctx_desc);
    return desc;
}

pub fn run(it: *flecs.EcsIter) callconv(.C) void {
    const world = it.world.?;

    while (flecs.ecs_iter_next(it)) {
        var i: usize = 0;
        while (i < it.count) : (i += 1) {
            const entity = it.entities[i];
            if (flecs.ecs_field(it, components.Tile, 2)) |tiles| {
                if (flecs.ecs_field(it, components.Drag, 3)) |drags| {
                    const dist_x = std.math.absInt(drags[i].start.x - tiles[i].x) catch unreachable;
                    const dist_y = std.math.absInt(drags[i].start.y - tiles[i].y) catch unreachable;

                    if (dist_x <= 1 and dist_y <= 1 and drags[i].start.z == tiles[i].z) {
                        var target_entity: ?flecs.EcsEntity = null;
                        var counter: u64 = 0;
                        if (it.ctx) |ctx| {
                            var query = @ptrCast(*flecs.EcsQuery, ctx);
                            var query_it = flecs.ecs_query_iter(world, query);
                            if (game.state.cells.get(drags[i].start.toCell())) |cell_entity| {
                                flecs.ecs_query_set_group(&query_it, cell_entity);
                            }

                            while (flecs.ecs_iter_next(&query_it)) {
                                var j: usize = 0;
                                while (j < query_it.count) : (j += 1) {
                                    if (flecs.ecs_field(&query_it, components.Tile, 2)) |start_tiles| {
                                        if (query_it.entities[j] == entity)
                                            continue;

                                        if (start_tiles[j].x == drags[i].start.x and start_tiles[j].y == drags[i].start.y and start_tiles[j].z == drags[i].start.z) {
                                            if (start_tiles[j].counter > counter) counter = start_tiles[j].counter;
                                            target_entity = query_it.entities[j];
                                        }
                                    }
                                }
                            }
                        }

                        if (target_entity) |target| {
                            if (flecs.ecs_has_id(world, target, flecs.ecs_id(components.Moveable))) {
                                const direction = game.math.Direction.find(8, @intToFloat(f32, drags[i].end.x - drags[i].start.x), @intToFloat(f32, drags[i].end.y - drags[i].start.y));

                                const cooldown = switch (direction) {
                                    .n, .s, .e, .w => game.settings.movement_cooldown / 2,
                                    else => game.settings.movement_cooldown / 2 * game.math.sqrt2,
                                };

                                if (flecs.ecs_get(world, target, components.Stack)) |stack| {
                                    const count = switch (drags[i].modifier) {
                                        .all => stack.count,
                                        .half => if (stack.count > 1) @divTrunc(stack.count, 2) else stack.count,
                                        .one => 1,
                                    };
                                    if (count < stack.count) {
                                        const clone = flecs.ecs_new(world, null);
                                        _ = flecs.ecs_clone(world, clone, target, true);
                                        flecs.ecs_set(world, clone, &components.Stack{ .count = count, .max = stack.max });
                                        flecs.ecs_set(world, target, &components.Stack{ .count = stack.count - count, .max = stack.max });
                                        flecs.ecs_set_pair_second(world, clone, components.Request, &components.Movement{ .start = drags[i].start, .end = drags[i].end, .curve = .sin });
                                        flecs.ecs_set_pair(world, clone, &components.Cooldown{ .end = cooldown }, components.Movement);
                                    } else {
                                        flecs.ecs_set_pair_second(world, target, components.Request, &components.Movement{ .start = drags[i].start, .end = drags[i].end, .curve = .sin });
                                        flecs.ecs_set_pair(world, target, &components.Cooldown{ .end = cooldown }, components.Movement);
                                    }
                                } else {
                                    flecs.ecs_set_pair_second(world, target, components.Request, &components.Movement{ .start = drags[i].start, .end = drags[i].end, .curve = .sin });
                                    flecs.ecs_set_pair(world, target, &components.Cooldown{ .end = cooldown }, components.Movement);
                                }
                            }
                        }
                    }

                    flecs.ecs_remove_pair(world, entity, components.Request, components.Drag);
                }
            }
        }
    }
}

fn orderBy(_: flecs.EcsEntity, c1: ?*const anyopaque, _: flecs.EcsEntity, c2: ?*const anyopaque) callconv(.C) c_int {
    const tile_1 = flecs.ecs_cast(components.Tile, c1);
    const tile_2 = flecs.ecs_cast(components.Tile, c2);

    return @intCast(c_int, @boolToInt(tile_1.counter > tile_2.counter)) - @intCast(c_int, @boolToInt(tile_1.counter < tile_2.counter));
}
