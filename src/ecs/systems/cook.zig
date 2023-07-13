const std = @import("std");
const zm = @import("zmath");
const ecs = @import("zflecs");
const game = @import("root");
const components = game.components;

pub fn system() ecs.system_desc_t {
    var desc: ecs.system_desc_t = .{};
    desc.query.filter.terms[0] = .{ .id = ecs.id(components.Raw), .oper = ecs.oper_kind_t.Optional };
    desc.query.filter.terms[1] = .{ .id = ecs.id(components.Cook) };
    desc.query.filter.terms[2] = .{ .id = ecs.id(components.Stack), .oper = ecs.oper_kind_t.Optional };
    desc.query.filter.terms[3] = .{ .id = ecs.id(components.Position) };
    desc.query.filter.terms[4] = .{ .id = ecs.id(components.Tile) };
    desc.query.filter.terms[5] = .{ .id = ecs.pair(ecs.id(components.Cooldown), ecs.id(components.Movement)), .oper = ecs.oper_kind_t.Not };
    desc.run = run;
    return desc;
}

pub fn run(it: *ecs.iter_t) callconv(.C) void {
    const world = it.world;

    while (ecs.iter_next(it)) {
        var i: usize = 0;
        while (i < it.count()) : (i += 1) {
            const entity = it.entities()[i];

            if (ecs.field(it, components.Raw, 1)) |raws| {
                if (ecs.field(it, components.Position, 4)) |positions| {
                    if (ecs.field(it, components.Tile, 5)) |tiles| {
                        const new = ecs.new_w_id(world, ecs.pair(ecs.IsA, raws[i].cooked_prefab));
                        var tile = tiles[i];
                        tile.z += 1;

                        _ = ecs.set(world, new, components.Position, positions[i]);
                        _ = ecs.set(world, new, components.Tile, tile);

                        _ = ecs.set_pair(world, new, ecs.id(components.Request), ecs.id(components.Movement), components.Movement, .{
                            .start = tile,
                            .end = tiles[i],
                            .curve = .sin,
                        });
                        _ = ecs.set_pair(world, new, ecs.id(components.Cooldown), ecs.id(components.Movement), components.Cooldown, .{ .end = game.settings.movement_cooldown / 2 });
                        if (ecs.field(it, components.Stack, 3)) |stacks| {
                            if (stacks[i].count > 0) {
                                stacks[i].count -= 1;
                                ecs.modified_id(world, entity, ecs.id(components.Stack));

                                _ = ecs.set_pair(world, entity, ecs.id(components.Request), ecs.id(components.Movement), components.Movement, .{
                                    .start = tile,
                                    .end = tiles[i],
                                    .curve = .sin,
                                });
                                _ = ecs.set_pair(world, entity, ecs.id(components.Cooldown), ecs.id(components.Movement), components.Cooldown, .{ .end = game.settings.movement_cooldown / 2 });
                            }
                        } else {
                            ecs.delete(world, entity);
                        }
                    }
                }
            } else {
                ecs.remove(world, entity, components.Cook);
            }
        }
    }
}
