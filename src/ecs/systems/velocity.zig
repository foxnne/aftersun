const std = @import("std");
const zm = @import("zmath");
const flecs = @import("flecs");
const game = @import("game");
const components = game.components;

pub fn system() flecs.EcsSystemDesc {
    var desc = std.mem.zeroes(flecs.EcsSystemDesc);
    desc.query.filter.terms[0] = std.mem.zeroInit(flecs.EcsTerm, .{ .id = flecs.ecs_pair(components.Direction, components.Movement) });
    desc.query.filter.terms[1] = std.mem.zeroInit(flecs.EcsTerm, .{ .id = flecs.ecs_id(components.Velocity) });
    desc.run = run;
    return desc;
}

pub fn run(it: *flecs.EcsIter) callconv(.C) void {
    while (flecs.ecs_iter_next(it)) {
        var i: usize = 0;
        while (i < it.count) : (i += 1) {
            if (flecs.ecs_field(it, components.Direction, 1)) |directions| {
                if (flecs.ecs_field(it, components.Velocity, 2)) |velocities| {
                    const step = it.delta_time * game.settings.camera_follow_speed;

                    const target_v_x = directions[i].x();
                    const target_v_y = directions[i].y();

                    if (velocities[i].x > target_v_x) {
                        if (velocities[i].x >= target_v_x + step) {
                            velocities[i].x -= step;
                        } else velocities[i].x = target_v_x;
                    } else if (velocities[i].x < target_v_x) {
                        if (velocities[i].x <= target_v_x - step) {
                            velocities[i].x += step;
                        } else velocities[i].x = target_v_x;
                    }

                    if (velocities[i].y > target_v_y) {
                        if (velocities[i].y >= target_v_y + step) {
                            velocities[i].y -= step;
                        } else velocities[i].y = target_v_y;
                    } else if (velocities[i].y < target_v_y) {
                        if (velocities[i].y <= target_v_y - step) {
                            velocities[i].y += step;
                        } else velocities[i].y = target_v_y;
                    }
                }
            }
        }
    }
}
