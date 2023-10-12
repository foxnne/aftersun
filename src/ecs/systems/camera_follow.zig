const std = @import("std");
const zmath = @import("zmath");
const ecs = @import("zflecs");
const game = @import("../../aftersun.zig");
const components = game.components;

pub fn system() ecs.system_desc_t {
    var desc: ecs.system_desc_t = .{};
    desc.query.filter.terms[0] = .{ .id = ecs.pair(ecs.id(components.Camera), ecs.id(components.Target)) };
    desc.query.filter.terms[1] = .{ .id = ecs.id(components.Position) };
    desc.query.filter.terms[2] = .{ .id = ecs.id(components.Velocity), .oper = ecs.oper_kind_t.Optional };
    desc.run = run;
    return desc;
}

pub fn run(it: *ecs.iter_t) callconv(.C) void {
    while (ecs.iter_next(it)) {
        var i: usize = 0;
        while (i < it.count()) : (i += 1) {
            if (ecs.field(it, components.Position, 2)) |positions| {
                const position = positions[i].toF32x4();
                const velocity = if (ecs.field(it, components.Velocity, 3)) |velocities| velocities[i].toF32x4() else zmath.f32x4s(0);
                var target: zmath.F32x4 = position;
                target[0] -= game.math.ease(0, std.math.sign(velocity[0]) * game.settings.pixels_per_unit, @abs(velocity[0]), .ease_in);
                target[1] -= game.math.ease(0, std.math.sign(velocity[1]) * game.settings.pixels_per_unit, @abs(velocity[1]), .ease_in);
                game.state.camera.position = zmath.trunc(target);
            }
        }
    }
}
