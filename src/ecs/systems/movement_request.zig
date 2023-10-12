const std = @import("std");
const zm = @import("zmath");
const ecs = @import("zflecs");
const game = @import("../../aftersun.zig");
const components = game.components;

pub fn system() ecs.system_desc_t {
    var desc: ecs.system_desc_t = .{};
    desc.query.filter.terms[0] = .{ .id = ecs.id(components.Player) };
    desc.query.filter.terms[1] = .{ .id = ecs.id(components.Tile) };
    desc.query.filter.terms[2] = .{ .id = ecs.pair(ecs.id(components.Request), ecs.id(components.Movement)), .oper = ecs.oper_kind_t.Not };
    desc.query.filter.terms[3] = .{ .id = ecs.pair(ecs.id(components.Cooldown), ecs.id(components.Movement)), .oper = ecs.oper_kind_t.Not };
    desc.no_readonly = true;
    desc.run = run;
    return desc;
}

pub fn run(it: *ecs.iter_t) callconv(.C) void {
    const world = it.world;

    while (ecs.iter_next(it)) {
        var i: usize = 0;
        while (i < it.count()) : (i += 1) {
            const entity = it.entities()[i];

            if (entity != game.state.entities.player) break;

            const n: bool = if (game.state.hotkeys.hotkey(.directional_up)) |hk| hk.down() else false;
            const s: bool = if (game.state.hotkeys.hotkey(.directional_down)) |hk| hk.down() else false;
            const e: bool = if (game.state.hotkeys.hotkey(.directional_right)) |hk| hk.down() else false;
            const w: bool = if (game.state.hotkeys.hotkey(.directional_left)) |hk| hk.down() else false;

            const direction = game.math.Direction.write(n, s, e, w);
            if (ecs.field(it, components.Tile, 2)) |tiles| {
                if (direction != .none) {
                    const end_tile = components.Tile{
                        .x = tiles[i].x + @as(i32, @intFromFloat(direction.x())),
                        .y = tiles[i].y + @as(i32, @intFromFloat(direction.y())),
                    };

                    // ! When setting pairs, the intended data type attached must either be matched with a tag, or first in the pair of components.
                    _ = ecs.set_pair(world, entity, ecs.id(components.Request), ecs.id(components.Movement), components.Movement, .{ .start = tiles[i], .end = end_tile });

                    // Set cooldown
                    const cooldown = switch (direction) {
                        .n, .s, .e, .w => game.settings.movement_cooldown,
                        else => game.settings.movement_cooldown * game.math.sqrt2,
                    };
                    _ = ecs.set_pair(world, entity, ecs.id(components.Cooldown), ecs.id(components.Movement), components.Cooldown, .{ .current = 0.0, .end = cooldown });
                } else {
                    // Zero movement direction.
                    _ = ecs.set_pair(world, entity, ecs.id(components.Direction), ecs.id(components.Movement), components.Direction, .none);
                }
            }
        }
    }
}
