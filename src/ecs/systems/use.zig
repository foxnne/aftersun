const std = @import("std");
const zm = @import("zmath");
const ecs = @import("zflecs");
const game = @import("root");
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
    desc.query.filter.terms[0] = .{ .id = ecs.id(components.Player) };
    desc.query.filter.terms[1] = .{ .id = ecs.id(components.Tile) };
    desc.query.filter.terms[2] = .{ .id = ecs.pair(ecs.id(components.Request), ecs.id(components.Use)) };
    desc.run = run;

    var ctx_desc: ecs.query_desc_t = .{};
    ctx_desc.filter.terms[0] = .{ .id = ecs.pair(ecs.id(components.Cell), ecs.Wildcard) };
    ctx_desc.filter.terms[1] = .{ .id = ecs.id(components.Tile) };
    ctx_desc.group_by = groupBy;
    ctx_desc.group_by_id = ecs.id(components.Cell);
    ctx_desc.order_by = orderBy;
    ctx_desc.order_by_component = ecs.id(components.Tile);
    desc.ctx = ecs.query_init(world, &ctx_desc) catch unreachable;
    return desc;
}

pub fn run(it: *ecs.iter_t) callconv(.C) void {
    const world = it.world;

    while (ecs.iter_next(it)) {
        var i: usize = 0;
        while (i < it.count()) : (i += 1) {
            const entity = it.entities()[i];

            if (ecs.field(it, components.Tile, 2)) |tiles| {
                if (ecs.field(it, components.Use, 3)) |uses| {
                    const dist_x = @abs(uses[i].target.x - tiles[i].x);
                    const dist_y = @abs(uses[i].target.y - tiles[i].y);

                    if (dist_x <= 1 and dist_y <= 1) {
                        var target_entity: ?ecs.entity_t = null;
                        var target_tile: components.Tile = .{};
                        var counter: u64 = 0;
                        if (it.ctx) |ctx| {
                            var query = @as(*ecs.query_t, @ptrCast(ctx));
                            var query_it = ecs.query_iter(world, query);
                            if (game.state.cells.get(uses[i].target.toCell())) |cell_entity| {
                                ecs.query_set_group(&query_it, cell_entity);
                            }

                            while (ecs.iter_next(&query_it)) {
                                var j: usize = 0;
                                while (j < query_it.count()) : (j += 1) {
                                    if (ecs.field(&query_it, components.Tile, 2)) |start_tiles| {
                                        if (query_it.entities()[j] == entity)
                                            continue;

                                        if (start_tiles[j].x == uses[i].target.x and start_tiles[j].y == uses[i].target.y and start_tiles[j].z == uses[i].target.z) {
                                            if (start_tiles[j].counter > counter) {
                                                counter = start_tiles[j].counter;
                                                target_entity = query_it.entities()[j];
                                                target_tile = start_tiles[j];
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        if (target_entity) |target| {
                            if (ecs.has_id(world, target, ecs.id(components.Useable))) {
                                if (ecs.has_id(world, target, ecs.id(components.Consumeable))) {
                                    if (ecs.get_mut(world, target, components.Stack)) |stack| {
                                        stack.count -= 1;
                                        ecs.modified_id(world, target, ecs.id(components.Stack));
                                    } else {
                                        ecs.delete(world, target);
                                    }
                                }

                                if (ecs.get(world, target, components.Toggleable)) |toggle| {
                                    const new = ecs.new_w_id(world, ecs.pair(ecs.IsA, if (toggle.state) toggle.off_prefab else toggle.on_prefab));
                                    _ = ecs.set(world, new, components.Tile, target_tile);
                                    _ = ecs.set(world, new, components.Position, target_tile.toPosition());
                                    ecs.delete(world, target);
                                }
                            }
                        }
                    }

                    ecs.remove_pair(world, entity, ecs.id(components.Request), ecs.id(components.Use));
                }
            }
        }
    }
}

fn orderBy(_: ecs.entity_t, c1: ?*const anyopaque, _: ecs.entity_t, c2: ?*const anyopaque) callconv(.C) c_int {
    const tile_1 = ecs.cast(components.Tile, c1);
    const tile_2 = ecs.cast(components.Tile, c2);

    return @as(c_int, @intCast(@intFromBool(tile_1.counter > tile_2.counter))) - @as(c_int, @intCast(@intFromBool(tile_1.counter < tile_2.counter)));
}
