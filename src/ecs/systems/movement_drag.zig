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
    desc.query.filter.terms[0] = .{ .id = ecs.id(components.Player) };
    desc.query.filter.terms[1] = .{ .id = ecs.id(components.Tile) };
    desc.query.filter.terms[2] = .{ .id = ecs.pair(ecs.id(components.Request), ecs.id(components.Drag)), .oper = ecs.oper_kind_t.Optional };
    desc.run = run;

    var ctx_desc: ecs.query_desc_t = .{};
    ctx_desc.filter.terms[0] = .{ .id = ecs.pair(ecs.id(components.Cell), ecs.Wildcard) };
    ctx_desc.filter.terms[1] = .{ .id = ecs.id(components.Tile), .inout = .In };
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
                    const dist_x = @abs(drags[i].start.x - tiles[i].x);
                    const dist_y = @abs(drags[i].start.y - tiles[i].y);

                    if (dist_x <= 1 and dist_y <= 1 and drags[i].start.z == tiles[i].z) {
                        var target_entity: ?ecs.entity_t = null;
                        var counter: u64 = 0;
                        if (it.ctx) |ctx| {
                            var query = @as(*ecs.query_t, @ptrCast(ctx));
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
                                const direction = game.math.Direction.find(8, @as(f32, @floatFromInt(drags[i].end.x - drags[i].start.x)), @as(f32, @floatFromInt(drags[i].end.y - drags[i].start.y)));

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
                } else {
                    // Drag request is not yet present
                    if (game.state.mouse.button(.primary)) |bt| {
                        if (bt.released() and !std.mem.eql(i32, &bt.pressed_tile, &bt.released_tile)) {
                            _ = ecs.set_pair(game.state.world, game.state.entities.player, ecs.id(components.Request), ecs.id(components.Drag), components.Drag, .{
                                .start = .{ .x = bt.pressed_tile[0], .y = bt.pressed_tile[1] },
                                .end = .{ .x = bt.released_tile[0], .y = bt.released_tile[1] },
                                .modifier = if (bt.released_mods.shift) components.Drag.Modifier.half else if (bt.released_mods.control) components.Drag.Modifier.one else components.Drag.Modifier.all,
                            });
                        }
                    }
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
