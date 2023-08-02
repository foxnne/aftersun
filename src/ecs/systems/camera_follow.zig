const std = @import("std");
const zm = @import("zmath");
const ecs = @import("zflecs");
const game = @import("root");
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
                const velocity = if (ecs.field(it, components.Velocity, 3)) |velocities| velocities[i].toF32x4() else zm.f32x4s(0);
                const target = position - velocity * zm.f32x4s(game.settings.pixels_per_unit);

                game.state.camera.position = zm.trunc(target);
            }
        }
    }
}
