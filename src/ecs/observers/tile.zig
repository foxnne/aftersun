const std = @import("std");
const zm = @import("zmath");
const flecs = @import("flecs");
const game = @import("game");
const components = game.components;

pub fn observer() flecs.EcsObserverDesc {
    var observer_desc = std.mem.zeroes(flecs.EcsObserverDesc);
    observer_desc.filter.terms[0] = std.mem.zeroInit(flecs.EcsTerm, .{ .id = flecs.ecs_id(components.Tile) });
    observer_desc.events[0] = flecs.Constants.EcsOnSet;
    observer_desc.run = run;
    return observer_desc;
}

pub fn run(it: *flecs.EcsIter) callconv(.C) void {
    const world = it.world.?;

    while (flecs.ecs_iter_next(it)) {
        var i: usize = 0;
        while (i < it.count) : (i += 1) {
            const entity = it.entities[i];
            if (flecs.ecs_field(it, components.Tile, 1)) |tiles| {
                const cell = tiles[i].toCell();
                if (game.state.cells.get(cell)) |cell_entity| {
                    flecs.ecs_remove_pair(world, entity, components.Cell, flecs.Constants.EcsWildcard);
                    flecs.ecs_set_pair(world, entity, &cell, cell_entity);
                } else {
                    std.log.debug("Cell entity created! {any}", .{cell});
                    const cell_entity = flecs.ecs_new_id(world);
                    flecs.ecs_set(world, cell_entity, &cell);
                    game.state.cells.put(cell, cell_entity) catch unreachable;
                    flecs.ecs_remove_pair(world, entity, components.Cell, flecs.Constants.EcsWildcard);
                    flecs.ecs_set_pair(world, entity, &cell, cell_entity);
                }
            }
        }
    }
}
