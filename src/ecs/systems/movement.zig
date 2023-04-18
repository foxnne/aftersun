const std = @import("std");
const zm = @import("zmath");
const ecs = @import("zflecs");
const game = @import("root");
const components = game.components;

pub fn system() ecs.system_desc_t {
    var desc = std.mem.zeroes(ecs.system_desc_t);
    desc.query.filter.terms[0] = std.mem.zeroInit(ecs.term_t, .{ .id = ecs.id(components.Position) });
    desc.query.filter.terms[1] = std.mem.zeroInit(ecs.term_t, .{ .id = ecs.id(components.Tile) });
    desc.query.filter.terms[2] = std.mem.zeroInit(ecs.term_t, .{ .id = ecs.pair(ecs.id(components.Request), ecs.id(components.Movement)) });
    desc.query.filter.terms[3] = std.mem.zeroInit(ecs.term_t, .{ .id = ecs.pair(ecs.id(components.Cooldown), ecs.id(components.Movement)), .oper = ecs.oper_kind_t.Optional });
    desc.run = run;
    return desc;
}

pub fn run(it: *ecs.iter_t) callconv(.C) void {
    const world = it.world;

    while (ecs.iter_next(it)) {
        var i: usize = 0;
        while (i < it.count()) : (i += 1) {
            const entity = it.entities()[i];
            if (ecs.field(it, components.Position, 1)) |positions| {
                if (ecs.field(it, components.Tile, 2)) |tiles| {
                    if (ecs.field(it, components.Movement, 3)) |movements| {
                        if (tiles[i].x != movements[i].end.x or tiles[i].y != movements[i].end.y or tiles[i].z != movements[i].end.z) {
                            // Move the tile, only once so counter is only set on the actual move.
                            tiles[i] = movements[i].end;
                            tiles[i].counter = game.state.counter.count();

                            // Set modified so that observers are triggered.
                            ecs.modified_id(world, entity, ecs.id(components.Tile));
                        }

                        if (ecs.field(it, components.Cooldown, 4)) |cooldowns| {

                            // Get progress of the lerp using cooldown duration
                            const t = if (cooldowns[i].end > 0.0) cooldowns[i].current / cooldowns[i].end else 0.0;

                            const start_position = movements[i].start.toPosition().toF32x4();
                            const end_position = movements[i].end.toPosition().toF32x4();
                            const difference = end_position - start_position;
                            const direction = game.math.Direction.find(8, difference[0], difference[1]);

                            // Update movement direction
                            _ = ecs.set_pair(world, entity, ecs.id(components.Direction), ecs.id(components.Movement), components.Direction, direction);

                            // Update position
                            const position = zm.lerp(start_position, end_position, t);
                            positions[i].x = position[0];
                            positions[i].y = position[1];
                            positions[i].z = if (movements[i].curve == .sin) @sin(std.math.pi * t) * 10.0 else position[2];
                        } else {
                            const end_position = movements[i].end.toPosition().toF32x4();
                            positions[i].x = end_position[0];
                            positions[i].y = end_position[1];
                            positions[i].z = end_position[2];
                            ecs.remove_pair(world, entity, ecs.id(components.Request), ecs.id(components.Movement));
                        }
                    }
                }
            }
        }
    }
}
