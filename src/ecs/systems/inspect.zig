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

            const position = mouse_tile.toPosition().toF32x4();
            const screen_position = game.state.camera.worldToScreen(position, game.state.camera.frameBufferMatrix());

            const name = if (prefab != 0) flecs.ecs_get_name(world, prefab) else flecs.ecs_get_name(world, target);

            if (name != null) {
                zgui.setNextWindowPos(.{ .x = screen_position[0], .y = screen_position[1], .cond = .always });
                if (zgui.begin("Inspect", .{ .flags = zgui.WindowFlags{
                    .no_title_bar = true,
                    .no_resize = true,
                    .always_auto_resize = true,
                } })) {
                    if (name != null) {
                        const prefix = "You see";
                        const count = if (flecs.ecs_get(world, target, components.Stack)) |stack| stack.count else 1;
                        const suffix = if (count > 1) "s." else ".";
                        zgui.text("{s} {d} {s}{s}", .{ prefix, count, name, suffix });
                    }
                    zgui.end();
                }
            }
        }
    }
}

fn orderBy(_: flecs.EcsEntity, c1: ?*const anyopaque, _: flecs.EcsEntity, c2: ?*const anyopaque) callconv(.C) c_int {
    const tile_1 = flecs.ecs_cast(components.Tile, c1);
    const tile_2 = flecs.ecs_cast(components.Tile, c2);

    return @intCast(c_int, @boolToInt(tile_1.counter > tile_2.counter)) - @intCast(c_int, @boolToInt(tile_1.counter < tile_2.counter));
}
