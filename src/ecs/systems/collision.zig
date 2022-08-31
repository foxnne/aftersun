const std = @import("std");
const zm = @import("zmath");
const flecs = @import("flecs");
const game = @import("game");
const components = game.components;

pub fn system(world: *flecs.EcsWorld) flecs.EcsSystemDesc {
    var desc = std.mem.zeroes(flecs.EcsSystemDesc);
    desc.query.filter.terms[0] = std.mem.zeroInit(flecs.EcsTerm, .{ .id = flecs.ecs_pair(components.Request, components.Movement) });
    desc.query.filter.terms[1] = std.mem.zeroInit(flecs.EcsTerm, .{ .id = flecs.ecs_id(components.Tile) });
    desc.query.filter.terms[2] = std.mem.zeroInit(flecs.EcsTerm, .{ .id = flecs.ecs_id(components.Collider) });
    desc.run = run;

    var ctx_desc = std.mem.zeroes(flecs.EcsQueryDesc);
    ctx_desc.filter.terms[0] = std.mem.zeroInit(flecs.EcsTerm, .{ .id = flecs.ecs_pair(flecs.Constants.EcsWildcard, components.Cell) });
    ctx_desc.filter.terms[1] = std.mem.zeroInit(flecs.EcsTerm, .{ .id = flecs.ecs_id(components.Tile) });
    ctx_desc.filter.terms[2] = std.mem.zeroInit(flecs.EcsTerm, .{ .id = flecs.ecs_id(components.Collider) });
    desc.ctx = flecs.ecs_query_init(world, &ctx_desc);

    return desc;
}

pub fn run(it: *flecs.EcsIter) callconv(.C) void {
    const world = it.world.?;

    while (flecs.ecs_iter_next(it)) {
        var i: usize = 0;
        while (i < it.count) : (i += 1) {
            const entity = it.entities[i];

            if (flecs.ecs_field(it, components.Movement, 1)) |movements| {
                if (flecs.ecs_field(it, components.Tile, 2)) |tiles| {
                const target_tile = movements[i].end;
                const target_cell = target_tile.toCell();

                if (it.ctx) |ctx| {
                    var query = @ptrCast(*flecs.EcsQuery, ctx);
                    var query_it = flecs.ecs_query_iter(world, query);

                    while (flecs.ecs_iter_next(&query_it)) {
                        var j: usize = 0;
                        while (j < query_it.count) : (j += 1) {
                            if (flecs.ecs_field(&query_it, components.Cell, 1)) |cells| {
                                if (cells[j].x == target_cell.x and cells[j].y == target_cell.y and cells[j].z == target_cell.z) {
                                    if (flecs.ecs_field(&query_it, components.Tile, 2)) |target_tiles| {
                                        if (query_it.entities[j] != entity) {
                                            if (target_tiles[j].x == target_tile.x and target_tiles[j].y == target_tile.y and target_tiles[j].z == target_tile.z) {
                                                // Collision.
                                                flecs.ecs_set_pair_second(world, entity, components.Request, &components.Movement{ .start = tiles[i], .end = tiles[i]});
                                                //flecs.ecs_remove_pair(world, entity, components.Request, components.Movement);
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            }
        }
    }
}
