const std = @import("std");
const zm = @import("zmath");
const ecs = @import("zflecs");
const game = @import("root");
const gfx = game.gfx;
const math = game.math;
const components = game.components;

pub fn system() ecs.system_desc_t {
    var desc: ecs.system_desc_t = .{};
    desc.query.filter.terms[0] = .{ .id = ecs.id(components.Position) };
    desc.query.filter.terms[1] = .{ .id = ecs.id(components.LightRenderer) };
    desc.query.order_by_component = ecs.id(components.Position);
    desc.query.order_by = orderBy;
    desc.run = run;
    return desc;
}

pub fn run(it: *ecs.iter_t) callconv(.C) void {
    const uniforms = gfx.Uniforms{ .mvp = zm.transpose(game.state.camera.renderTextureMatrix()) };

    // Draw diffuse texture sprites using diffuse pipeline
    game.state.batcher.begin(.{
        .pipeline_handle = game.state.pipeline_default,
        .bind_group_handle = game.state.bind_group_light,
        .output_handle = game.state.light_output.view_handle,
        .clear_color = math.Color.initBytes(0, 0, 0, 255).value,
    }) catch unreachable;

    while (ecs.iter_next(it)) {
        var i: usize = 0;
        while (i < it.count()) : (i += 1) {
            if (ecs.field(it, components.Position, 1)) |positions| {
                var position = positions[i].toF32x4();
                position[1] += position[2];

                if (ecs.field(it, components.LightRenderer, 2)) |renderers| {
                    game.state.batcher.sprite(
                        position,
                        game.state.lightmap,
                        game.state.light_atlas.sprites[renderers[i].index],
                        .{
                            .color = renderers[i].color,
                        },
                    ) catch unreachable;
                }
            }
        }
    }
    game.state.batcher.end(uniforms) catch unreachable;
}

fn orderBy(e1: ecs.entity_t, c1: ?*const anyopaque, e2: ecs.entity_t, c2: ?*const anyopaque) callconv(.C) c_int {
    const position_1 = ecs.cast(components.Position, c1);
    const position_2 = ecs.cast(components.Position, c2);

    if (@fabs(position_1.y - position_2.y) <= 16) {
        var counter1 = if (ecs.get(game.state.world, e1, components.Tile)) |tile| tile.counter else 0;
        var counter2 = if (ecs.get(game.state.world, e2, components.Tile)) |tile| tile.counter else 0;
        return @intCast(c_int, @boolToInt(counter1 > counter2)) - @intCast(c_int, @boolToInt(counter1 < counter2));
    }
    return @intCast(c_int, @boolToInt(position_1.y < position_2.y)) - @intCast(c_int, @boolToInt(position_1.y > position_2.y));
}
