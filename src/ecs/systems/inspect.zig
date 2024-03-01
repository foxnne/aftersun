const std = @import("std");
const zmath = @import("zmath");
const ecs = @import("zflecs");
const zgui = @import("zgui");
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

pub fn system() ecs.system_desc_t {
    var desc: ecs.system_desc_t = .{};
    desc.query.filter.terms[0] = .{ .id = ecs.pair(ecs.id(components.Cell), ecs.Wildcard) };
    desc.query.filter.terms[1] = .{ .id = ecs.id(components.Position) };
    desc.query.filter.terms[2] = .{ .id = ecs.id(components.Visible) };
    desc.query.group_by = groupBy;
    desc.query.group_by_id = ecs.id(components.Cell);
    desc.query.order_by = orderBy;
    desc.query.order_by_component = ecs.id(components.Position);
    desc.run = run;
    return desc;
}

pub fn run(it: *ecs.iter_t) callconv(.C) void {
    const world = it.world;

    if (game.state.mouse.button(.secondary)) |button| {
        if (button.released()) {
            var mouse_tile: components.Tile = .{
                .x = button.released_tile[0],
                .y = button.released_tile[1],
            };

            if (ecs.get(world, game.state.entities.player, components.Position)) |position| {
                mouse_tile.z = position.tile.z;
            }

            if (game.state.cells.get(mouse_tile.toCell())) |cell_entity| {
                ecs.query_set_group(it, cell_entity);
            }

            var counter: u64 = 0;
            var target_entity: ?ecs.entity_t = null;

            while (ecs.iter_next(it)) {
                var i: usize = 0;
                while (i < it.count()) : (i += 1) {
                    if (ecs.field(it, components.Position, 2)) |positions| {
                        if (positions[i].tile.x == mouse_tile.x and positions[i].tile.y == mouse_tile.y and positions[i].tile.z == mouse_tile.z) {
                            if (positions[i].tile.counter > counter) {
                                counter = positions[i].tile.counter;
                                target_entity = it.entities()[i];
                            }
                        }
                    }
                }
            }
            if (target_entity) |target| {
                if (ecs.has_id(world, target, ecs.id(components.Useable))) {
                    _ = ecs.set_pair(world, game.state.entities.player, ecs.id(components.Request), ecs.id(components.Use), components.Use, .{ .target = mouse_tile });
                }

                if (target == game.state.entities.player) {
                    var prng = std.rand.DefaultPrng.init(@as(u64, @intFromFloat(game.state.game_time * 100)));
                    const rand = prng.random();

                    if (ecs.get_mut(world, game.state.entities.player, components.CharacterAnimator)) |animator| {
                        animator.top_set = if (rand.boolean()) game.animation_sets.top_f_01 else game.animation_sets.top_f_02;
                        animator.bottom_set = if (rand.boolean()) game.animation_sets.bottom_f_02 else game.animation_sets.bottom_f_01;
                    }

                    if (ecs.get_mut(world, game.state.entities.player, components.CharacterRenderer)) |renderer| {
                        const top = rand.intRangeAtMost(u8, 1, 12);
                        const bottom = rand.intRangeAtMost(u8, 1, 12);
                        const hair = rand.intRangeAtMost(u8, 1, 12);

                        renderer.top_color = game.math.Color.initBytes(top, 0, 0, 255).toSlice();
                        renderer.bottom_color = game.math.Color.initBytes(bottom, 0, 0, 255).toSlice();
                        renderer.hair_color = game.math.Color.initBytes(hair, 0, 0, 255).toSlice();
                    }
                }
            }
        }
    }
}

fn orderBy(_: ecs.entity_t, c1: ?*const anyopaque, _: ecs.entity_t, c2: ?*const anyopaque) callconv(.C) c_int {
    const pos_1 = ecs.cast(components.Position, c1);
    const pos_2 = ecs.cast(components.Position, c2);

    return @as(c_int, @intCast(@intFromBool(pos_1.tile.counter > pos_2.tile.counter))) - @as(c_int, @intCast(@intFromBool(pos_1.tile.counter < pos_2.tile.counter)));
}
