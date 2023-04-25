const std = @import("std");
const zm = @import("zmath");
const ecs = @import("zflecs");
const zgui = @import("zgui");
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

pub fn system() ecs.system_desc_t {
    var desc: ecs.system_desc_t = .{};
    desc.query.filter.terms[0] = .{ .id = ecs.pair(ecs.id(components.Cell), ecs.EcsWildcard) };
    desc.query.filter.terms[1] = .{ .id = ecs.id(components.Tile) };
    desc.query.group_by = groupBy;
    desc.query.group_by_id = ecs.id(components.Cell);
    desc.query.order_by = orderBy;
    desc.query.order_by_component = ecs.id(components.Tile);
    desc.run = run;
    return desc;
}

pub fn run(it: *ecs.iter_t) callconv(.C) void {
    if (game.state.controls.inspect() or game.state.controls.inspecting) {
        if (game.state.controls.mouse.tile_timer < 1.0) {
            game.state.controls.mouse.tile_timer += it.delta_time * 2.0;
        }
        game.state.controls.mouse.tile_timer = std.math.clamp(game.state.controls.mouse.tile_timer, 0.0, 1.0);

        const world = it.world;

        var mouse_tile = game.state.controls.mouse.tile;
        if (ecs.get(world, game.state.entities.player, components.Tile)) |tile| {
            mouse_tile.z = tile.z;
        }

        if (game.state.cells.get(mouse_tile.toCell())) |cell_entity| {
            ecs.query_set_group(it, cell_entity);
        }

        var counter: u64 = 0;
        var target_entity: ?ecs.entity_t = null;

        while (ecs.iter_next(it)) {
            var i: usize = 0;
            while (i < it.count()) : (i += 1) {
                if (ecs.field(it, components.Tile, 2)) |tiles| {
                    if (tiles[i].x == mouse_tile.x and tiles[i].y == mouse_tile.y and tiles[i].z == mouse_tile.z) {
                        if (tiles[i].counter > counter) {
                            counter = tiles[i].counter;
                            target_entity = it.entities()[i];
                        }
                    }
                }
            }
        }
        if (target_entity) |target| {
            const prefab = ecs.get_target(world, target, ecs.EcsIsA, 0);

            const tile_position = mouse_tile.toPosition().toF32x4();
            const screen_position = game.state.camera.worldToScreen(tile_position);

            var name = if (prefab != 0) (if (ecs.get_name(world, prefab)) |n| n else "error") else if (ecs.get_name(world, target)) |n| n else "error";
            if (target == game.state.entities.player) name = "yourself";

            const cs = game.state.gctx.window.getContentScale();
            const scale = std.math.max(cs[0], cs[1]);

            const text_spacing = game.settings.zgui_font_size * scale;
            const window_padding = game.settings.inspect_window_padding * scale;
            const window_spacing = game.settings.inspect_window_spacing * scale;

            const bg = game.math.Color.initBytes(225, 225, 225, @floatToInt(u8, 225.0 * game.state.controls.mouse.tile_timer));

            zgui.pushStyleColor4f(.{ .idx = zgui.StyleCol.window_bg, .c = bg.toSlice() });
            defer zgui.popStyleColor(.{ .count = 1 });
            zgui.pushStyleVar2f(.{ .idx = zgui.StyleVar.item_spacing, .v = .{ 2.0 * scale, 2.0 * scale } });
            defer zgui.popStyleVar(.{ .count = 1 });

            const radius = game.settings.pixels_per_unit / 8 * game.state.camera.zoom / 2 * scale;
            const leader_length = (game.settings.pixels_per_unit / 2) * (game.state.camera.zoom / 1.5) * scale;

            const direction: game.math.Direction = .e;
            const normalized_direction = direction.normalized();

            const pos_1 = screen_position + normalized_direction * zm.f32x4s(game.math.lerp(0.0, radius, game.state.controls.mouse.tile_timer));
            const pos_2 = pos_1 + normalized_direction * zm.f32x4s(game.math.lerp(0.0, leader_length, game.state.controls.mouse.tile_timer));

            zgui.setNextWindowPos(.{ .x = pos_2[0], .y = pos_2[1] - text_spacing - window_padding - window_spacing, .cond = .always });
            if (zgui.begin(name[0..std.mem.len(name) :0], .{ .flags = zgui.WindowFlags{
                .no_title_bar = true,
                .no_resize = true,
                .always_auto_resize = true,
            } })) {
                const draw_list = zgui.getWindowDrawList();

                draw_list.pushClipRectFullScreen();
                defer draw_list.popClipRect();

                draw_list.addTriangleFilled(.{
                    .p1 = .{ pos_2[0], pos_2[1] },
                    .p2 = .{ pos_2[0] - (10.0 * scale), pos_2[1] - (5.0 * scale) },
                    .p3 = .{ pos_2[0], pos_2[1] - (10.0 * scale) },
                    .col = bg.toU32(),
                });

                const prefix = "You see";

                const count = if (ecs.get(world, target, components.Stack)) |stack| stack.count else 1;

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
                        const quantifier = switch (name[0]) {
                            'a', 'e', 'i', 'o', 'u' => "an",
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

                zgui.pushStyleColor4f(.{ .idx = zgui.StyleCol.text, .c = game.math.Color.initBytes(225, 225, 225, 255).toSlice() });
                zgui.pushStyleColor4f(.{ .idx = zgui.StyleCol.button, .c = game.math.Color.initBytes(0, 0, 0, 255).toSlice() });
                zgui.pushStyleColor4f(.{ .idx = zgui.StyleCol.button_hovered, .c = game.math.Color.initBytes(60, 60, 60, 255).toSlice() });
                zgui.pushStyleColor4f(.{ .idx = zgui.StyleCol.button_active, .c = game.math.Color.initBytes(0, 0, 0, 255).toSlice() });
                defer zgui.popStyleColor(.{ .count = 4 });

                if (ecs.has_id(world, target, ecs.id(components.Useable))) {
                    if (zgui.button(if (ecs.has_id(world, target, ecs.id(components.Consumeable))) "Consume" else "Use", .{ .w = -1 })) {
                        _ = ecs.set_pair(world, game.state.entities.player, ecs.id(components.Request), ecs.id(components.Use), components.Use, .{ .target = mouse_tile });
                    }
                    if (zgui.button("Use with", .{ .w = -1 })) {}
                }

                _ = zgui.invisibleButton("Placeholder", .{ .w = -1, .h = 1.0 });

                if (target == game.state.entities.player) {
                    if (zgui.button("Change", .{ .w = -1 })) {
                        var prng = std.rand.DefaultPrng.init(@floatToInt(u64, game.state.gctx.stats.time * 100));
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
            zgui.end();
        } else {
            game.state.controls.inspecting = false;
        }
    } else {
        game.state.controls.mouse.tile_timer = 0.0;
    }
}

fn orderBy(_: ecs.entity_t, c1: ?*const anyopaque, _: ecs.entity_t, c2: ?*const anyopaque) callconv(.C) c_int {
    const tile_1 = ecs.cast(components.Tile, c1);
    const tile_2 = ecs.cast(components.Tile, c2);

    return @intCast(c_int, @boolToInt(tile_1.counter > tile_2.counter)) - @intCast(c_int, @boolToInt(tile_1.counter < tile_2.counter));
}
