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

            find: {
                if (flecs.ecs_field(it, components.Tile, 2)) |tiles| {
                    if (flecs.ecs_field(it, components.Drag, 3)) |drags| {
                        const start_cell = drags[i].start.toCell();
                        const dist_x = std.math.absInt(drags[i].start.x - tiles[i].x) catch unreachable;
                        const dist_y = std.math.absInt(drags[i].start.y - tiles[i].y) catch unreachable;

                        if (dist_x <= 1 and dist_y <= 1 and drags[i].start.z == tiles[i].z) {
                            if (it.ctx) |ctx| {
                                var query = @ptrCast(*flecs.EcsQuery, ctx);
                                var query_it = flecs.ecs_query_iter(world, query);
                                if (game.state.cells.get(start_cell)) |cell_entity| {
                                    flecs.ecs_query_set_group(&query_it, cell_entity);
                                }

                                while (flecs.ecs_iter_next(&query_it)) {
                                    var j: usize = 0;
                                    while (j < query_it.count) : (j += 1) {
                                        if (flecs.ecs_field(&query_it, components.Tile, 2)) |start_tiles| {
                                            if (query_it.entities[j] == entity)
                                                continue;

                                            if (start_tiles[j].x == drags[i].start.x and start_tiles[j].y == drags[i].start.y and start_tiles[j].z == drags[i].start.z) {
                                                if (flecs.ecs_has_id(world, query_it.entities[j], flecs.ecs_id(components.Moveable))) {
                                                    const direction = game.math.Direction.find(8, @intToFloat(f32, drags[i].end.x - drags[i].start.x), @intToFloat(f32, drags[i].end.y - drags[i].start.y));

                                                    const cooldown = switch (direction) {
                                                        .n, .s, .e, .w => game.settings.movement_cooldown / 2,
                                                        else => game.settings.movement_cooldown / 2 * game.math.sqrt2,
                                                    };
                                                    flecs.ecs_set_pair_second(world, query_it.entities[j], components.Request, &components.Movement{ .start = drags[i].start, .end = drags[i].end, .curve = .sin });
                                                    flecs.ecs_set_pair(world, query_it.entities[j], &components.Cooldown{ .end = cooldown }, components.Movement);
                                                }

                                                break :find;
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            flecs.ecs_remove_pair(world, entity, components.Request, components.Drag);
        }
    }
}

fn orderBy(_: flecs.EcsEntity, c1: ?*const anyopaque, _: flecs.EcsEntity, c2: ?*const anyopaque) callconv(.C) c_int {
    const tile_1 = flecs.ecs_cast(components.Tile, c1);
    const tile_2 = flecs.ecs_cast(components.Tile, c2);

    return @intCast(c_int, @boolToInt(tile_1.counter < tile_2.counter)) - @intCast(c_int, @boolToInt(tile_1.counter > tile_2.counter));
}
