const std = @import("std");
const zmath = @import("zmath");
const ecs = @import("zflecs");
const game = @import("../../aftersun.zig");
const components = game.components;

pub fn groupBy(world: *ecs.world_t, table: *ecs.table_t, id: ecs.entity_t, ctx: ?*anyopaque) callconv(.C) ecs.entity_t {
    _ = ctx;
    var match: ecs.entity_t = 0;
    if (ecs.search(world, table, ecs.pair(id, ecs.Wildcard), &match) != -1) {
        return ecs.pair_second(match);
    }
    return 0;
}

pub fn system(world: *ecs.world_t) ecs.system_desc_t {
    var desc: ecs.system_desc_t = .{};
    desc.query.filter.terms[0] = .{ .id = ecs.id(components.Position) };
    desc.query.filter.terms[1] = .{ .id = ecs.id(components.Tile) };
    desc.query.filter.terms[2] = .{ .id = ecs.pair(ecs.id(components.Request), ecs.id(components.Movement)) };
    desc.query.filter.terms[3] = .{ .id = ecs.pair(ecs.id(components.Cooldown), ecs.id(components.Movement)), .oper = ecs.oper_kind_t.Optional };
    desc.run = run;

    var ctx_desc: ecs.query_desc_t = .{};
    ctx_desc.filter.terms[0] = .{ .id = ecs.pair(ecs.id(components.Cell), ecs.Wildcard) };
    ctx_desc.filter.terms[1] = .{ .id = ecs.id(components.Tile) };
    ctx_desc.filter.terms[2] = .{ .id = ecs.id(components.Unloadable) };
    ctx_desc.group_by = groupBy;
    ctx_desc.group_by_id = ecs.id(components.Cell);
    desc.ctx = ecs.query_init(world, &ctx_desc) catch unreachable;

    return desc;
}

pub fn run(it: *ecs.iter_t) callconv(.C) void {
    const world = it.world;

    while (ecs.iter_next(it)) {
        var i: usize = 0;
        while (i < it.count()) : (i += 1) {
            const entity = it.entities()[i];
            if (ecs.field(it, components.Position, 1)) |positions| {
                if (ecs.field(it, components.Tile, 2)) |tiles| {
                    if (ecs.field(it, components.Movement, 3)) |movements| {
                        var instant: bool = false;
                        if (tiles[i].x != movements[i].end.x or tiles[i].y != movements[i].end.y or tiles[i].z != movements[i].end.z) {
                            if (entity == game.state.entities.player) {
                                const player_cell = tiles[i].toCell();
                                var next_cell = movements[i].end.toCell();

                                if (player_cell.x != next_cell.x or player_cell.y != next_cell.y) {
                                    if (player_cell.y > next_cell.y and tiles[i].y > game.settings.cell_size + 1) {
                                        movements[i].end.y = game.settings.cell_size + 1;
                                        instant = true;
                                        next_cell = movements[i].end.toCell();
                                    }

                                    if (it.ctx) |ctx| {
                                        const old_cells = player_cell.getAllSurrounding();
                                        const new_cells = next_cell.getAllSurrounding();

                                        var query = @as(*ecs.query_t, @ptrCast(ctx));

                                        for (old_cells) |old_cell| {
                                            var found: bool = false;
                                            for (new_cells) |new_cell| {
                                                if (old_cell.x == new_cell.x and old_cell.y == new_cell.y and old_cell.z == new_cell.z) {
                                                    found = true;
                                                }
                                            }
                                            if (!found) {
                                                var query_it = ecs.query_iter(world, query);
                                                game.unloadCell(old_cell, &query_it);
                                            }
                                        }

                                        for (new_cells) |new_cell| {
                                            var found: bool = false;
                                            for (old_cells) |old_cell| {
                                                if (old_cell.x == new_cell.x and old_cell.y == new_cell.y and old_cell.z == new_cell.z) {
                                                    found = true;
                                                }
                                            }
                                            if (!found)
                                                game.loadCell(new_cell);
                                        }
                                    }
                                }
                            }

                            // Move the tile, only once so counter is only set on the actual move.
                            tiles[i] = movements[i].end;
                            tiles[i].counter = game.state.counter.count();

                            // Set modified so that observers are triggered.
                            ecs.modified_id(world, entity, ecs.id(components.Tile));
                        }

                        if (ecs.field(it, components.Cooldown, 4)) |cooldowns| {
                            if (!instant) {
                                // Get progress of the lerp using cooldown duration
                                const t = if (cooldowns[i].end > 0.0) cooldowns[i].current / cooldowns[i].end else 0.0;

                                const start_position = movements[i].start.toPosition().toF32x4();
                                const end_position = movements[i].end.toPosition().toF32x4();
                                const difference = end_position - start_position;
                                const direction = game.math.Direction.find(8, difference[0], difference[1]);

                                // Update movement direction
                                _ = ecs.set_pair(world, entity, ecs.id(components.Direction), ecs.id(components.Movement), components.Direction, direction);

                                // Update position
                                const position = zmath.lerp(start_position, end_position, t);
                                positions[i].x = position[0];
                                positions[i].y = position[1];
                                positions[i].z = if (movements[i].curve == .sin) @sin(std.math.pi * t) * 10.0 else position[2];
                            } else {
                                cooldowns[i].current = cooldowns[i].end;
                                const position = tiles[i].toPosition();
                                positions[i].x = position.x;
                                positions[i].y = position.y;
                                positions[i].z = position.z;
                            }
                        } else {
                            const end_position = movements[i].end.toPosition().toF32x4();
                            positions[i].x = end_position[0];
                            positions[i].y = end_position[1];
                            positions[i].z = end_position[2];
                            ecs.remove_pair(world, entity, ecs.id(components.Request), ecs.id(components.Movement));
                        }
                    }
                }
            }
        }
    }
}
