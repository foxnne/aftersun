const std = @import("std");
const zmath = @import("zmath");
const ecs = @import("zflecs");
const game = @import("../../aftersun.zig");
const components = game.components;

pub fn system() ecs.system_desc_t {
    var desc: ecs.system_desc_t = .{};
    desc.query.filter.terms[0] = .{ .id = ecs.pair(ecs.id(components.Camera), ecs.id(components.Target)) };
    desc.query.filter.terms[1] = .{ .id = ecs.id(components.Position) };
    desc.query.filter.terms[2] = .{ .id = ecs.id(components.Inertia), .oper = ecs.oper_kind_t.Optional };
    desc.query.filter.terms[3] = .{ .id = ecs.id(components.Player), .oper = ecs.oper_kind_t.Optional };
    desc.run = run;
    return desc;
}

pub fn run(it: *ecs.iter_t) callconv(.C) void {
    while (ecs.iter_next(it)) {
        var i: usize = 0;
        while (i < it.count()) : (i += 1) {
            if (ecs.field(it, components.Position, 2)) |positions| {
                const position = positions[i].toF32x4();
                const inertia = if (ecs.field(it, components.Inertia, 3)) |velocities| velocities[i].toF32x4() else zmath.f32x4s(0);
                var target: zmath.F32x4 = position;
                target[0] -= game.math.ease(0, std.math.sign(inertia[0]) * game.settings.pixels_per_unit, @abs(inertia[0]), .ease_in);
                target[1] -= game.math.ease(0, std.math.sign(inertia[1]) * game.settings.pixels_per_unit, @abs(inertia[1]), .ease_in);

                if (@abs(inertia[0]) > 0.9 or @abs(inertia[0]) < 0.1)
                    game.state.camera.position[0] = @trunc(target[0])
                else
                    game.state.camera.position[0] = target[0];

                if (@abs(inertia[1]) > 0.9 or @abs(inertia[1]) < 0.1)
                    game.state.camera.position[1] = @trunc(target[1])
                else
                    game.state.camera.position[1] = target[1];
            }
        }
    }
}
