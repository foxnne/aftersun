const std = @import("std");
const zmath = @import("zmath");
const ecs = @import("zflecs");
const game = @import("../../aftersun.zig");
const components = game.components;

pub fn observer() ecs.observer_desc_t {
    var observer_desc = std.mem.zeroes(ecs.observer_desc_t);
    observer_desc.filter.terms[0] = std.mem.zeroInit(ecs.term_t, .{ .id = ecs.id(components.Position) });
    observer_desc.events[0] = ecs.OnSet;
    observer_desc.run = run;
    return observer_desc;
}

pub fn run(it: *ecs.iter_t) callconv(.C) void {
    const world = it.world;

    while (ecs.iter_next(it)) {
        var i: usize = 0;
        while (i < it.count()) : (i += 1) {
            const entity = it.entities()[i];
            if (ecs.field(it, components.Position, 1)) |positions| {
                const cell = positions[i].tile.toCell();
                if (game.state.cells.get(cell)) |cell_entity| {
                    const id = ecs.get_target(world, entity, ecs.id(components.Cell), 0);
                    if (id != 0) {
                        if (id != cell_entity) {
                            ecs.remove_pair(world, entity, ecs.id(components.Cell), ecs.Wildcard);
                            _ = ecs.set_pair(world, entity, ecs.id(components.Cell), cell_entity, components.Cell, cell);
                        }
                    } else {
                        _ = ecs.set_pair(world, entity, ecs.id(components.Cell), cell_entity, components.Cell, cell);
                    }
                } else {
                    const cell_entity = ecs.new_id(world);
                    _ = ecs.set(world, cell_entity, components.Cell, cell);
                    game.state.cells.put(cell, cell_entity) catch unreachable;
                    ecs.remove_pair(world, entity, ecs.id(components.Cell), ecs.Wildcard);
                    _ = ecs.set_pair(world, entity, ecs.id(components.Cell), cell_entity, components.Cell, cell);
                }
            }
        }
    }
}
