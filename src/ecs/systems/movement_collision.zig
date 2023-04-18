const std = @import("std");
const zm = @import("zmath");
const ecs = @import("zflecs");
const game = @import("root");
const components = game.components;

pub fn groupBy(world: *ecs.world_t, table: *ecs.table_t, id: ecs.entity_t, ctx: ?*anyopaque) callconv(.C) ecs.entity_t {
    _ = ctx;
    var match: ecs.entity_t = 0;
    if (ecs.search(world, table, ecs.pair(id, ecs.EcsWildcard), &match) != -1) {
        return ecs.pair_second(match);
    }
    return 0;
}

pub fn system(world: *ecs.world_t) ecs.system_desc_t {
    var desc = std.mem.zeroes(ecs.system_desc_t);
    desc.query.filter.terms[0] = std.mem.zeroInit(ecs.term_t, .{ .id = ecs.pair(ecs.id(components.Request), ecs.id(components.Movement)) });
    desc.query.filter.terms[1] = std.mem.zeroInit(ecs.term_t, .{ .id = ecs.id(components.Tile) });
    desc.query.filter.terms[2] = std.mem.zeroInit(ecs.term_t, .{ .id = ecs.id(components.Collider), .oper = ecs.oper_kind_t.Optional });
    desc.query.filter.terms[3] = std.mem.zeroInit(ecs.term_t, .{ .id = ecs.id(components.Stack), .oper = ecs.oper_kind_t.Optional });
    desc.run = run;

    var ctx_desc = std.mem.zeroes(ecs.query_desc_t);
    ctx_desc.filter.terms[0] = std.mem.zeroInit(ecs.term_t, .{ .id = ecs.pair(ecs.id(components.Cell), ecs.EcsWildcard) });
    ctx_desc.filter.terms[1] = std.mem.zeroInit(ecs.term_t, .{ .id = ecs.id(components.Tile) });
    ctx_desc.filter.terms[2] = std.mem.zeroInit(ecs.term_t, .{ .id = ecs.id(components.Collider), .oper = ecs.oper_kind_t.Optional });
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

            if (ecs.field(it, components.Movement, 1)) |movements| {
                if (ecs.field(it, components.Tile, 2)) |tiles| {
                    // Movement request remains until the entire move is done, so we need to make sure we only
                    // check for a collision when the tile hasn't yet been moved.
                    if (tiles[i].x != movements[i].end.x or tiles[i].y != movements[i].end.y or tiles[i].z != movements[i].end.z) {
                        if (it.ctx) |ctx| {
                            var query = @ptrCast(*ecs.query_t, ctx);
                            var query_it = ecs.query_iter(world, query);
                            if (game.state.cells.get(movements[i].end.toCell())) |cell_entity| {
                                ecs.query_set_group(&query_it, cell_entity);
                            }
                            var top_entity: ?ecs.entity_t = null;
                            var top_counter: u64 = 0;
                            while (ecs.iter_next(&query_it)) {
                                var j: usize = 0;
                                while (j < query_it.count()) : (j += 1) {
                                    if (ecs.field(&query_it, components.Tile, 2)) |potential_collisions| {
                                        if (query_it.entities()[j] != entity) {
                                            if (potential_collisions[j].x == movements[i].end.x and potential_collisions[j].y == movements[i].end.y and potential_collisions[j].z == movements[i].end.z) {
                                                if (potential_collisions[j].counter > top_counter) {
                                                    top_counter = potential_collisions[j].counter;
                                                    top_entity = query_it.entities()[j];
                                                }

                                                if (ecs.field(&query_it, components.Collider, 3)) |collisions| {
                                                    if (collisions[j].trigger) {
                                                        const add = ecs.get_target(world, query_it.entities()[j], ecs.id(components.Trigger), 0);
                                                        if (add != 0) {
                                                            ecs.add_id(world, entity, add);
                                                        }
                                                    } else {
                                                        if (ecs.field(it, components.Collider, 3)) |colliders| {
                                                            if (!colliders[i].trigger) {
                                                                // Collision. Set movement request to same tile to prevent extra frames on set/add and
                                                                // zero movement direction.
                                                                movements[i].end = tiles[i];
                                                                _ = ecs.set_pair(world, entity, ecs.id(components.Direction), ecs.id(components.Movement), components.Direction, .none);
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                            if (top_entity) |other| {
                                // Handle stacking, movement can trigger stacks to combine.
                                if (ecs.field(it, components.Stack, 4)) |stacks| {
                                    if (ecs.get(world, other, components.Stack)) |other_stack| {
                                        if (stacks[i].count + other_stack.count <= stacks[i].max) {
                                            const prefab = ecs.get_target(world, entity, ecs.EcsIsA, 0);
                                            const other_prefab = ecs.get_target(world, other, ecs.EcsIsA, 0);
                                            if (prefab == other_prefab) {
                                                _ = ecs.set_pair(world, entity, ecs.id(components.Request), ecs.id(components.Stack), components.Stack, .{
                                                    .count = stacks[i].count + other_stack.count,
                                                    .max = stacks[i].max,
                                                });

                                                _ = ecs.set_pair(world, entity, ecs.id(components.RequestZeroOther), ecs.id(components.Stack), components.RequestZeroOther, .{ .target = other });
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
