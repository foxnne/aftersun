const std = @import("std");
const zm = @import("zmath");
const flecs = @import("flecs");
const game = @import("game");
const components = game.components;
const atlas = game.state.atlas;

pub fn system() flecs.EcsSystemDesc {
    var desc = std.mem.zeroes(flecs.EcsSystemDesc);
    desc.query.filter.terms[0] = std.mem.zeroInit(flecs.EcsTerm, .{ .id = flecs.ecs_pair(components.Camera, components.Target) });
    desc.query.filter.terms[1] = std.mem.zeroInit(flecs.EcsTerm, .{ .id = flecs.ecs_id(components.Position) });
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
                const movement = if (flecs.ecs_get_pair(world, entity, components.Direction, components.Movement)) |direction| direction.value.f32x4() * zm.f32x4s(20.0) else zm.f32x4s(0.0);
                const cooldown = if (flecs.ecs_get_pair(world, entity, components.Cooldown, components.Movement)) |cooldown| cooldown.current / cooldown.end else 0.0;
                const target = position + movement;
                game.state.camera.position = @trunc(zm.lerp(position, target, cooldown));
            }
        }
    }
}
