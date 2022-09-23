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
    if (game.state.controls.inspect()) {
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

            const position = mouse_tile.toPosition().toF32x4() + game.settings.inspect_window_offset;
            const screen_position = game.state.camera.worldToScreen(position);

            const name = if (prefab != 0) flecs.ecs_get_name(world, prefab) else flecs.ecs_get_name(world, target);

            if (name != null) {
                zgui.pushStyleColor4f(.{ .idx = .window_bg, .c = [_]f32{ 0, 0, 0, 0.6 } });
                zgui.setNextWindowPos(.{ .x = screen_position[0], .y = screen_position[1], .cond = .always });
                if (zgui.begin("Inspect", .{ .flags = zgui.WindowFlags{
                    .no_title_bar = true,
                    .no_resize = true,
                    .always_auto_resize = true,
                } })) {
                    const prefix = "You see";
                    const count = if (flecs.ecs_get(world, target, components.Stack)) |stack| stack.count else 1;
                    var n = std.mem.span(name);
                    var buffer: [128]u8 = undefined;
                    _ = std.mem.replace(u8, n, "_", " ", &buffer);
                    const fixed_name = buffer[0..n.len];

                    if (count > 1) {
                        zgui.text("{s} {d} {s}s.", .{ prefix, count, fixed_name });
                    } else {
                        const a = "a";
                        const e = "e";
                        const i = "i";
                        const o = "o";
                        const u = "u";
                        const quantifier = switch (name[0]) {
                            a[0], e[0], i[0], o[0], u[0] => "an",
                            else => "a",
                        };

                        zgui.text("{s} {s} {s}.", .{ prefix, quantifier, fixed_name });
                    }

                    if (flecs.ecs_has_id(world, target, flecs.ecs_id(components.Useable))) {
                        if (zgui.button("Use", .{ .w = -1 })) {
                            flecs.ecs_set_pair_second(world, game.state.entities.player, components.Request, &components.Use{ .target = mouse_tile });
                        }
                    }
                }
                zgui.end();

                zgui.popStyleColor(.{ .count = 1 });
            }
        }
    }
}

fn orderBy(_: flecs.EcsEntity, c1: ?*const anyopaque, _: flecs.EcsEntity, c2: ?*const anyopaque) callconv(.C) c_int {
    const tile_1 = flecs.ecs_cast(components.Tile, c1);
    const tile_2 = flecs.ecs_cast(components.Tile, c2);

    return @intCast(c_int, @boolToInt(tile_1.counter > tile_2.counter)) - @intCast(c_int, @boolToInt(tile_1.counter < tile_2.counter));
}
