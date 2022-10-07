const std = @import("std");
const zm = @import("zmath");
const flecs = @import("flecs");
const zgui = @import("zgui");
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

pub fn system() flecs.EcsSystemDesc {
    var desc = std.mem.zeroes(flecs.EcsSystemDesc);
    desc.query.filter.terms[0] = std.mem.zeroInit(flecs.EcsTerm, .{ .id = flecs.ecs_pair(components.Cell, flecs.Constants.EcsWildcard) });
    desc.query.filter.terms[1] = std.mem.zeroInit(flecs.EcsTerm, .{ .id = flecs.ecs_id(components.Tile) });
    desc.query.group_by = groupBy;
    desc.query.group_by_id = flecs.ecs_id(components.Cell);
    desc.query.order_by = orderBy;
    desc.query.order_by_component = flecs.ecs_id(components.Tile);
    desc.run = run;
    return desc;
}

pub fn run(it: *flecs.EcsIter) callconv(.C) void {
    if (game.state.controls.inspect() or game.state.controls.inspecting) {
        if (game.state.controls.mouse.tile_timer < 1.0) {
            game.state.controls.mouse.tile_timer += it.delta_time * 3;
            game.state.controls.mouse.tile_timer = std.math.clamp(game.state.controls.mouse.tile_timer, 0.0, 1.0);
        }

        const world = it.world.?;

        var mouse_tile = game.state.controls.mouse.tile;
        if (flecs.ecs_get(world, game.state.entities.player, components.Tile)) |tile| {
            mouse_tile.z = tile.z;
        }

        if (game.state.cells.get(mouse_tile.toCell())) |cell_entity| {
            flecs.ecs_query_set_group(it, cell_entity);
        }

        var counter: u64 = 0;
        var target_entity: ?flecs.EcsEntity = null;

        while (flecs.ecs_iter_next(it)) {
            var i: usize = 0;
            while (i < it.count) : (i += 1) {
                if (flecs.ecs_field(it, components.Tile, 2)) |tiles| {
                    if (tiles[i].x == mouse_tile.x and tiles[i].y == mouse_tile.y and tiles[i].z == mouse_tile.z) {
                        if (tiles[i].counter > counter) {
                            counter = tiles[i].counter;
                            target_entity = it.entities[i];
                        }
                    }
                }
            }
        }

        if (target_entity) |target| {
            const prefab = flecs.ecs_get_target(world, target, flecs.Constants.EcsIsA, 0);

            const tile_position = mouse_tile.toPosition().toF32x4();
            const screen_position = game.state.camera.worldToScreen(tile_position);

            var name = if (prefab != 0) flecs.ecs_get_name(world, prefab) else flecs.ecs_get_name(world, target);
            if (target == game.state.entities.player) name = "yourself";

            if (name != null) {
                const cs = game.state.gctx.window.getContentScale();
                const scale = std.math.max(cs[0], cs[1]);

                const text_spacing = game.settings.zgui_font_size * scale;
                const window_padding = game.settings.inspect_window_padding * scale;
                const window_spacing = game.settings.inspect_window_spacing * scale;

                zgui.pushStyleColor4f(.{ .idx = zgui.StyleCol.window_bg, .c = .{ 0, 0, 0, 0.0 } });
                zgui.pushStyleColor4f(.{ .idx = zgui.StyleCol.border, .c = .{ 1, 1, 1, 0.0 } });
                zgui.pushStyleColor4f(.{ .idx = zgui.StyleCol.separator, .c = .{ 1, 1, 1, 1 } });
                defer zgui.popStyleColor(.{ .count = 3 });
                zgui.pushStyleVar2f(.{ .idx = zgui.StyleVar.item_spacing, .v = .{ 2.0 * scale, 2.0 * scale } });
                defer zgui.popStyleVar(.{ .count = 1 });

                const radius = game.settings.pixels_per_unit / 8 * game.state.camera.zoom / 2 * scale;
                const leader_length = game.settings.pixels_per_unit / 3 * game.state.camera.zoom / 2;

                const direction: game.math.Direction = if (screen_position[1] < game.settings.pixels_per_unit * 2 * scale) .ne else .se;
                const normalized_direction = direction.normalized();

                const pos_1 = screen_position + normalized_direction * zm.f32x4s(game.math.lerp(0.0, radius, game.state.controls.mouse.tile_timer));
                const pos_2 = pos_1 + normalized_direction * zm.f32x4s(game.math.lerp(0.0, leader_length, game.state.controls.mouse.tile_timer) * scale);

                zgui.setNextWindowPos(.{ .x = pos_2[0], .y = pos_2[1] - text_spacing - window_padding - window_spacing, .cond = .always });
                if (zgui.begin("Inspect", .{ .flags = zgui.WindowFlags{
                    .no_title_bar = true,
                    .no_resize = true,
                    .always_auto_resize = true,
                } })) {
                    const pos_3 = pos_2 + zm.f32x4(game.math.lerp(0, zgui.getWindowWidth(), game.state.controls.mouse.tile_timer), 0, 0, 0);

                    const draw_list = zgui.getWindowDrawList();

                    draw_list.pushClipRectFullScreen();
                    defer draw_list.popClipRect();
                    draw_list.addCircleFilled(.{
                        .p = .{ screen_position[0], screen_position[1] },
                        .r = game.math.lerp(0.0, radius, game.state.controls.mouse.tile_timer),
                        .col = 0x99_ff_ff_ff,
                    });

                    draw_list.addPolyline(&[_][2]f32{
                        [_]f32{ pos_1[0], pos_1[1] },
                        [_]f32{ pos_2[0], pos_2[1] },
                        [_]f32{ pos_3[0], pos_3[1] },
                    }, .{ .col = 0xff_ff_ff_ff, .thickness = 1 * scale });

                    const prefix = "You see";

                    const count = if (flecs.ecs_get(world, target, components.Stack)) |stack| stack.count else 1;

                    var n = std.mem.span(name);
                    var buffer: [128]u8 = undefined;
                    _ = std.mem.replace(u8, n, "_", " ", &buffer);
                    const fixed_name = buffer[0..n.len];

                    if (count > 1) {
                        const description = zgui.formatZ("{s} {d} {s}s.", .{ prefix, count, fixed_name });
                        const index = @floatToInt(usize, @trunc(game.state.controls.mouse.tile_timer * @intToFloat(f32, description.len)));
                        zgui.text("{s}", .{description[0..index]});
                    } else {
                        if (target != game.state.entities.player) {
                            const a = "a";
                            const e = "e";
                            const i = "i";
                            const o = "o";
                            const u = "u";
                            const quantifier = switch (name[0]) {
                                a[0], e[0], i[0], o[0], u[0] => "an",
                                else => "a",
                            };

                            const description = zgui.formatZ("{s} {s} {s}.", .{ prefix, quantifier, fixed_name });
                            const index = @floatToInt(usize, @trunc(game.state.controls.mouse.tile_timer * @intToFloat(f32, description.len)));
                            zgui.text("{s}", .{description[0..index]});
                        } else {
                            const description = zgui.formatZ("{s} {s}.", .{ prefix, fixed_name });
                            const index = @floatToInt(usize, @trunc(game.state.controls.mouse.tile_timer * @intToFloat(f32, description.len)));
                            zgui.text("{s}", .{description[0..index]});
                        }
                    }
                    zgui.spacing();
                    zgui.spacing();
                    zgui.spacing();

                    if (flecs.ecs_has_id(world, target, flecs.ecs_id(components.Useable))) {
                        if (zgui.button(if (flecs.ecs_has_id(world, target, flecs.ecs_id(components.Consumeable))) "Consume" else "Use", .{ .w = -1 })) {
                            flecs.ecs_set_pair_second(world, game.state.entities.player, components.Request, &components.Use{ .target = mouse_tile });
                        }
                        if (zgui.button("Use with", .{ .w = -1 })) {}
                    }

                    if (target == game.state.entities.player) {
                        if (zgui.button("Change", .{ .w = -1 })) {
                            var prng = std.rand.DefaultPrng.init(@floatToInt(u64, game.state.gctx.stats.time * 100));
                            const rand = prng.random();

                            if (flecs.ecs_get_mut(world, game.state.entities.player, components.CharacterAnimator)) |animator| {
                                animator.top_set = if (rand.boolean()) game.animation_sets.top_f_01 else game.animation_sets.top_f_02;
                                animator.bottom_set = if (rand.boolean()) game.animation_sets.bottom_f_01 else game.animation_sets.bottom_f_02;
                            }

                            if (flecs.ecs_get_mut(world, game.state.entities.player, components.CharacterRenderer)) |renderer| {
                                const top = rand.intRangeAtMost(u8, 1, 12);
                                const bottom = rand.intRangeAtMost(u8, 1, 12);
                                const hair = rand.intRangeAtMost(u8, 1, 12);

                                renderer.top_color = game.math.Color.initBytes(top, 0, 0, 255);
                                renderer.bottom_color = game.math.Color.initBytes(bottom, 0, 0, 255);
                                renderer.hair_color = game.math.Color.initBytes(hair, 0, 0, 255);
                            }
                        }
                    }
                }
                zgui.end();
            }
        } else {
            game.state.controls.inspecting = false;
        }
    }
}

fn orderBy(_: flecs.EcsEntity, c1: ?*const anyopaque, _: flecs.EcsEntity, c2: ?*const anyopaque) callconv(.C) c_int {
    const tile_1 = flecs.ecs_cast(components.Tile, c1);
    const tile_2 = flecs.ecs_cast(components.Tile, c2);

    return @intCast(c_int, @boolToInt(tile_1.counter > tile_2.counter)) - @intCast(c_int, @boolToInt(tile_1.counter < tile_2.counter));
}
