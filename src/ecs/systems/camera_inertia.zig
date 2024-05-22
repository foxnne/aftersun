const std = @import("std");
const zmath = @import("zmath");
const ecs = @import("zflecs");
const game = @import("../../aftersun.zig");
const components = game.components;

pub fn system() ecs.system_desc_t {
    var desc: ecs.system_desc_t = .{};
    desc.query.filter.terms[0] = .{ .id = ecs.pair(ecs.id(components.Direction), ecs.id(components.Movement)) };
    desc.query.filter.terms[1] = .{ .id = ecs.id(components.Inertia) };
    desc.run = run;
    return desc;
}

pub fn run(it: *ecs.iter_t) callconv(.C) void {
    while (ecs.iter_next(it)) {
        var i: usize = 0;
        while (i < it.count()) : (i += 1) {
            if (ecs.field(it, components.Direction, 1)) |directions| {
                if (ecs.field(it, components.Inertia, 2)) |inertias| {
                    const step = it.delta_time * game.settings.camera_follow_speed;

                    const movement = directions[i].f32x4();

                    const target_v_x = movement[0];
                    const target_v_y = movement[1];

                    if (inertias[i].x > target_v_x) {
                        if (inertias[i].x >= target_v_x + step) {
                            inertias[i].x -= step;
                        } else inertias[i].x = target_v_x;
                    } else if (inertias[i].x < target_v_x) {
                        if (inertias[i].x <= target_v_x - step) {
                            inertias[i].x += step;
                        } else inertias[i].x = target_v_x;
                    }

                    if (inertias[i].y > target_v_y) {
                        if (inertias[i].y >= target_v_y + step) {
                            inertias[i].y -= step;
                        } else inertias[i].y = target_v_y;
                    } else if (inertias[i].y < target_v_y) {
                        if (inertias[i].y <= target_v_y - step) {
                            inertias[i].y += step;
                        } else inertias[i].y = target_v_y;
                    }
                }
            }
        }
    }
}
