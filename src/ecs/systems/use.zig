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
    desc.query.filter.terms[2] = std.mem.zeroInit(flecs.EcsTerm, .{ .id = flecs.ecs_pair(components.Request, components.Use) });
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
                if (flecs.ecs_field(it, components.Use, 3)) |uses| {
                    const dist_x = std.math.absInt(uses[i].target.x - tiles[i].x) catch unreachable;
                    const dist_y = std.math.absInt(uses[i].target.y - tiles[i].y) catch unreachable;

                    if (dist_x <= 1 and dist_y <= 1) {
                        var target_entity: ?flecs.EcsEntity = null;
                        var target_tile: ?components.Tile = null;
                        var counter: u64 = 0;
                        if (it.ctx) |ctx| {
                            var query = @ptrCast(*flecs.EcsQuery, ctx);
                            var query_it = flecs.ecs_query_iter(world, query);
                            if (game.state.cells.get(uses[i].target.toCell())) |cell_entity| {
                                flecs.ecs_query_set_group(&query_it, cell_entity);
                            }

                            while (flecs.ecs_iter_next(&query_it)) {
                                var j: usize = 0;
                                while (j < query_it.count) : (j += 1) {
                                    if (flecs.ecs_field(&query_it, components.Tile, 2)) |start_tiles| {
                                        if (query_it.entities[j] == entity)
                                            continue;

                                        if (start_tiles[j].x == uses[i].target.x and start_tiles[j].y == uses[i].target.y and start_tiles[j].z == uses[i].target.z) {
                                            if (start_tiles[j].counter > counter) {
                                                counter = start_tiles[j].counter;
                                                target_entity = query_it.entities[j];
                                                target_tile = start_tiles[j];
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        if (target_entity) |target| {
                            if (flecs.ecs_has_id(world, target, flecs.ecs_id(components.Useable))) {
                                if (flecs.ecs_has_id(world, target, flecs.ecs_id(components.Consumeable))) {
                                    if (flecs.ecs_get_mut(world, target, components.Stack)) |stack| {
                                        stack.count -= 1;
                                        flecs.ecs_modified_id(world, target, flecs.ecs_id(components.Stack));
                                    } else {
                                        flecs.ecs_delete(world, target);
                                    }
                                }

                                if (flecs.ecs_get(world, target, components.Toggleable)) |toggle| {
                                    const new = flecs.ecs_new_w_pair(world, flecs.Constants.EcsIsA, if (toggle.state) toggle.off_prefab else toggle.on_prefab);
                                    flecs.ecs_set(world, new, target_tile.?);
                                    flecs.ecs_set(world, new, target_tile.?.toPosition());
                                    flecs.ecs_delete(world, target);
                                }
                            }
                        }
                    }

                    flecs.ecs_remove_pair(world, entity, components.Request, components.Use);
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
