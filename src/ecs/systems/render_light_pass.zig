const std = @import("std");
const zmath = @import("zmath");
const ecs = @import("zflecs");
const game = @import("../../aftersun.zig");
const gfx = game.gfx;
const math = game.math;
const components = game.components;

pub fn system() ecs.system_desc_t {
    var desc: ecs.system_desc_t = .{};
    desc.query.filter.terms[0] = .{ .id = ecs.id(components.Position), .inout = .In };
    desc.query.filter.terms[1] = .{ .id = ecs.id(components.LightRenderer) };
    desc.query.order_by_component = ecs.id(components.Position);
    desc.query.order_by = orderBy;
    desc.run = run;
    return desc;
}

pub fn run(it: *ecs.iter_t) callconv(.C) void {
    const uniforms = gfx.UniformBufferObject{ .mvp = zmath.transpose(game.state.camera.renderTextureMatrix()) };

    // Draw diffuse texture sprites using diffuse pipeline
    game.state.batcher.begin(.{
        .pipeline_handle = game.state.pipeline_default,
        .bind_group_handle = game.state.bind_group_light,
        .output_handle = game.state.light_output.view_handle,
        .clear_color = math.Color.initBytes(0, 0, 0, 255).toGpuColor(),
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
                        &game.state.lightmap,
                        game.state.light_atlas.sprites[renderers[i].index],
                        .{
                            .color = renderers[i].color,
                        },
                    ) catch unreachable;
                }
            }
        }
    }
    game.state.batcher.end(uniforms, game.state.uniform_buffer_default) catch unreachable;
}

fn orderBy(e1: ecs.entity_t, c1: ?*const anyopaque, e2: ecs.entity_t, c2: ?*const anyopaque) callconv(.C) c_int {
    const position_1 = ecs.cast(components.Position, c1);
    const position_2 = ecs.cast(components.Position, c2);

    const tile_1 = position_1.toTile(0);
    const tile_2 = position_1.toTile(0);

    if (tile_1.y > tile_2.y) return @as(c_int, 1) else if (tile_1.y < tile_2.y) return @as(c_int, 0);

    if (@abs(position_1.y - position_2.y) <= 16) {
        var counter1 = if (ecs.get(game.state.world, e1, components.Tile)) |tile| tile.counter else 0;
        var counter2 = if (ecs.get(game.state.world, e2, components.Tile)) |tile| tile.counter else 0;
        return @as(c_int, @intCast(@intFromBool(counter1 > counter2))) - @as(c_int, @intCast(@intFromBool(counter1 < counter2)));
    }
    return @as(c_int, @intCast(@intFromBool(position_1.y < position_2.y))) - @as(c_int, @intCast(@intFromBool(position_1.y > position_2.y)));
}
