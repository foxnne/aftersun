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
    desc.query.filter.terms[0] = std.mem.zeroInit(ecs.term_t, .{ .id = ecs.id(components.Player) });
    desc.query.filter.terms[1] = std.mem.zeroInit(ecs.term_t, .{ .id = ecs.id(components.Tile) });
    desc.query.filter.terms[2] = std.mem.zeroInit(ecs.term_t, .{ .id = ecs.pair(ecs.id(components.Request), ecs.id(components.Drag)) });
    desc.run = run;

    var ctx_desc = std.mem.zeroes(ecs.query_desc_t);
    ctx_desc.filter.terms[0] = std.mem.zeroInit(ecs.term_t, .{ .id = ecs.pair(ecs.id(components.Cell), ecs.EcsWildcard) });
    ctx_desc.filter.terms[1] = std.mem.zeroInit(ecs.term_t, .{ .id = ecs.id(components.Tile) });
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
                if (ecs.field(it, components.Drag, 3)) |drags| {
                    const dist_x = std.math.absInt(drags[i].start.x - tiles[i].x) catch unreachable;
                    const dist_y = std.math.absInt(drags[i].start.y - tiles[i].y) catch unreachable;

                    if (dist_x <= 1 and dist_y <= 1 and drags[i].start.z == tiles[i].z) {
                        var target_entity: ?ecs.entity_t = null;
                        var counter: u64 = 0;
                        if (it.ctx) |ctx| {
                            var query = @ptrCast(*ecs.query_t, ctx);
                            var query_it = ecs.query_iter(world, query);
                            if (game.state.cells.get(drags[i].start.toCell())) |cell_entity| {
                                ecs.query_set_group(&query_it, cell_entity);
                            }

                            while (ecs.iter_next(&query_it)) {
                                var j: usize = 0;
                                while (j < query_it.count()) : (j += 1) {
                                    if (ecs.field(&query_it, components.Tile, 2)) |start_tiles| {
                                        if (query_it.entities()[j] == entity)
                                            continue;

                                        if (start_tiles[j].x == drags[i].start.x and start_tiles[j].y == drags[i].start.y and start_tiles[j].z == drags[i].start.z) {
                                            if (start_tiles[j].counter > counter) {
                                                counter = start_tiles[j].counter;
                                                target_entity = query_it.entities()[j];
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        if (target_entity) |target| {
                            if (ecs.has_id(world, target, ecs.id(components.Moveable))) {
                                const direction = game.math.Direction.find(8, @intToFloat(f32, drags[i].end.x - drags[i].start.x), @intToFloat(f32, drags[i].end.y - drags[i].start.y));

                                const cooldown = switch (direction) {
                                    .n, .s, .e, .w => game.settings.movement_cooldown / 2,
                                    else => game.settings.movement_cooldown / 2 * game.math.sqrt2,
                                };

                                if (ecs.get(world, target, components.Stack)) |stack| {
                                    const count = switch (drags[i].modifier) {
                                        .all => stack.count,
                                        .half => if (stack.count > 1) @divTrunc(stack.count, 2) else stack.count,
                                        .one => 1,
                                    };
                                    if (count < stack.count) {
                                        const clone = ecs.new_id(world);
                                        _ = ecs.clone(world, clone, target, false);
                                        _ = ecs.set(world, clone, components.Stack, .{ .count = count, .max = stack.max });
                                        _ = ecs.set(world, target, components.Stack, .{ .count = stack.count - count, .max = stack.max });
                                        _ = ecs.set_pair(world, clone, ecs.id(components.Request), ecs.id(components.Movement), components.Movement, .{ .start = drags[i].start, .end = drags[i].end, .curve = .sin });
                                        _ = ecs.set_pair(world, clone, ecs.id(components.Cooldown), ecs.id(components.Movement), components.Cooldown, .{ .end = cooldown });
                                    } else {
                                        _ = ecs.set_pair(world, target, ecs.id(components.Request), ecs.id(components.Movement), components.Movement, .{ .start = drags[i].start, .end = drags[i].end, .curve = .sin });
                                        _ = ecs.set_pair(world, target, ecs.id(components.Cooldown), ecs.id(components.Movement), components.Cooldown, .{ .end = cooldown });
                                    }
                                } else {
                                    _ = ecs.set_pair(world, target, ecs.id(components.Request), ecs.id(components.Movement), components.Movement, .{ .start = drags[i].start, .end = drags[i].end, .curve = .sin });
                                    _ = ecs.set_pair(world, target, ecs.id(components.Cooldown), ecs.id(components.Movement), components.Cooldown, .{ .end = cooldown });
                                }
                            }
                        }
                    }
                    ecs.remove_pair(world, entity, ecs.id(components.Request), ecs.id(components.Drag));
                }
            }
        }
    }
}

fn orderBy(_: ecs.entity_t, c1: ?*const anyopaque, _: ecs.entity_t, c2: ?*const anyopaque) callconv(.C) c_int {
    const tile_1 = ecs.cast(components.Tile, c1);
    const tile_2 = ecs.cast(components.Tile, c2);

    return @intCast(c_int, @boolToInt(tile_1.counter > tile_2.counter)) - @intCast(c_int, @boolToInt(tile_1.counter < tile_2.counter));
}
