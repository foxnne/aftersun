const std = @import("std");
const zmath = @import("zmath");
const ecs = @import("zflecs");
const game = @import("../../aftersun.zig");
const components = game.components;

pub fn system() ecs.system_desc_t {
    var desc: ecs.system_desc_t = .{};
    desc.query.filter.terms[0] = .{ .id = ecs.pair(ecs.id(components.Direction), ecs.id(components.Movement)) };
    desc.query.filter.terms[1] = .{ .id = ecs.id(components.Velocity) };
    desc.run = run;
    return desc;
}

pub fn run(it: *ecs.iter_t) callconv(.C) void {
    while (ecs.iter_next(it)) {
        var i: usize = 0;
        while (i < it.count()) : (i += 1) {
            if (ecs.field(it, components.Direction, 1)) |directions| {
                if (ecs.field(it, components.Velocity, 2)) |velocities| {
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
