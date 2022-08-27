const std = @import("std");
const zm = @import("zmath");
const flecs = @import("flecs");
const game = @import("game");
const components = game.components;

pub fn system() flecs.EcsSystemDesc {
    var desc = std.mem.zeroes(flecs.EcsSystemDesc);
    desc.query.filter.terms[0] = std.mem.zeroInit(flecs.EcsTerm, .{ .id = flecs.ecs_pair(components.Camera, components.Target) });
    desc.query.filter.terms[1] = std.mem.zeroInit(flecs.EcsTerm, .{ .id = flecs.ecs_id(components.Position) });
    desc.query.filter.terms[2] = std.mem.zeroInit(flecs.EcsTerm, .{ .id = flecs.ecs_id(components.Velocity), .oper = flecs.EcsOperKind.ecs_optional });
    desc.run = run;
    return desc;
}

pub fn run(it: *flecs.EcsIter) callconv(.C) void {
    const world = it.world.?;

    while (flecs.ecs_iter_next(it)) {
        var i: usize = 0;
        while (i < it.count) : (i += 1) {
            const entity = it.entities[i];

            if (flecs.ecs_field(it, components.Position, 2)) |positions| {
                const position = positions[i].toF32x4();
                const velocity = if (flecs.ecs_get(world, entity, components.Velocity)) |velocity| velocity.toF32x4() else zm.f32x4s(0);
                const target = position + velocity * zm.f32x4s(game.settings.pixels_per_unit);

                game.state.camera.position = zm.trunc(target);
            }
        }
    }
}
