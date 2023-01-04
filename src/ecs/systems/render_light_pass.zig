const std = @import("std");
const zm = @import("zmath");
const flecs = @import("flecs");
const game = @import("game");
const gfx = game.gfx;
const math = game.math;
const components = game.components;

pub fn system() flecs.EcsSystemDesc {
    var desc = std.mem.zeroes(flecs.EcsSystemDesc);
    desc.query.filter.terms[0] = std.mem.zeroInit(flecs.EcsTerm, .{ .id = flecs.ecs_id(components.Position) });
    desc.query.filter.terms[1] = std.mem.zeroInit(flecs.EcsTerm, .{ .id = flecs.ecs_id(components.LightRenderer) });
    desc.query.order_by_component = flecs.ecs_id(components.Position);
    desc.query.order_by = orderBy;
    desc.run = run;
    return desc;
}

pub fn run(it: *flecs.EcsIter) callconv(.C) void {
    const uniforms = gfx.Uniforms{ .mvp = zm.transpose(game.state.camera.renderTextureMatrix()) };

    // Draw diffuse texture sprites using diffuse pipeline
    game.state.batcher.begin(.{
        .pipeline_handle = game.state.pipeline_default,
        .bind_group_handle = game.state.bind_group_light,
        .output_handle = game.state.light_output.view_handle,
        .clear_color = math.Color.initBytes(0, 0, 0, 255).value,
    }) catch unreachable;

    while (flecs.ecs_iter_next(it)) {
        var i: usize = 0;
        while (i < it.count) : (i += 1) {
            if (flecs.ecs_field(it, components.Position, 1)) |positions| {
                var position = positions[i].toF32x4();
                position[1] += position[2];

                if (flecs.ecs_field(it, components.LightRenderer, 2)) |renderers| {
                    game.state.batcher.sprite(
                        position,
                        game.state.lightmap,
                        game.state.light_atlas.sprites[renderers[i].index],
                        .{
                            .color = renderers[i].color.value,
                        },
                    ) catch unreachable;
                }
            }
        }
    }

    game.state.batcher.end(uniforms) catch unreachable;
}

fn orderBy(e1: flecs.EcsEntity, c1: ?*const anyopaque, e2: flecs.EcsEntity, c2: ?*const anyopaque) callconv(.C) c_int {
    const position_1 = flecs.ecs_cast(components.Position, c1);
    const position_2 = flecs.ecs_cast(components.Position, c2);

    if (@fabs(position_1.y - position_2.y) <= 16) {
        var counter1 = if (flecs.ecs_get(game.state.world, e1, components.Tile)) |tile| tile.counter else 0;
        var counter2 = if (flecs.ecs_get(game.state.world, e2, components.Tile)) |tile| tile.counter else 0;
        return @intCast(c_int, @boolToInt(counter1 > counter2)) - @intCast(c_int, @boolToInt(counter1 < counter2));
    }
    return @intCast(c_int, @boolToInt(position_1.y < position_2.y)) - @intCast(c_int, @boolToInt(position_1.y > position_2.y));
}
