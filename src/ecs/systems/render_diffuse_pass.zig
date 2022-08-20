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
    desc.query.filter.terms[1] = std.mem.zeroInit(flecs.EcsTerm, .{ .id = flecs.ecs_id(components.Rotation), .oper = flecs.EcsOperKind.ecs_optional });
    desc.query.filter.terms[2] = std.mem.zeroInit(flecs.EcsTerm, .{ .id = flecs.ecs_id(components.SpriteRenderer), .oper = flecs.EcsOperKind.ecs_optional });
    desc.query.filter.terms[3] = std.mem.zeroInit(flecs.EcsTerm, .{ .id = flecs.ecs_id(components.CharacterRenderer), .oper = flecs.EcsOperKind.ecs_optional });
    desc.query.order_by_component = flecs.ecs_id(components.Position);
    desc.query.order_by = orderBy;
    desc.run = run;
    return desc;
}

pub fn run(it: *flecs.EcsIter) callconv(.C) void {
    const uniforms = gfx.Uniforms{ .mvp = zm.transpose(game.state.camera.renderTextureMatrix()) };

    // Draw diffuse texture sprites using diffuse pipeline
    game.state.batcher.begin(.{
        .pipeline_handle = game.state.pipeline_diffuse,
        .bind_group_handle = game.state.bind_group_diffuse,
        .output_handle = game.state.diffuse_output.view_handle,
        .clear_color = math.Colors.grass.value,
    }) catch unreachable;

    while (flecs.ecs_query_next(it)) {
    
        var i: usize = 0;
        while (i < it.count) : (i += 1) {

            if (flecs.ecs_field(it, components.Position, 1)) |positions| {
                const rotation = if (flecs.ecs_field(it, components.Rotation, 2)) |rotations| rotations[i].value else 0.0;

                if (flecs.ecs_field(it, components.SpriteRenderer, 3)) |renderers| {
                    renderers[i].order = i; // Set order so height passes can match time

                    game.state.batcher.sprite(
                        zm.f32x4(positions[i].x, positions[i].y + positions[i].z, positions[i].z, 0),
                        game.state.diffusemap,
                        game.state.atlas.sprites[renderers[i].index],
                        .{
                            .color = renderers[i].color.value,
                            .vert_mode = renderers[i].vert_mode,
                            .frag_mode = renderers[i].frag_mode,
                            .time = @floatCast(f32, game.state.gctx.stats.time) + @intToFloat(f32, renderers[i].order),
                            .rotation = rotation,
                        },
                    ) catch unreachable;
                }

                if (flecs.ecs_field(it, components.CharacterRenderer, 4)) |renderers| {
                    // Body
                    game.state.batcher.sprite(
                        zm.f32x4(positions[i].x, positions[i].y + positions[i].z, positions[i].z, 0),
                        game.state.diffusemap,
                        game.state.atlas.sprites[renderers[i].body_index],
                        .{
                            .color = renderers[i].body_color.value,
                            .frag_mode = .palette,
                            .flip_x = renderers[i].flip_body,
                            .rotation = rotation,
                        },
                    ) catch unreachable;

                    // Head
                    game.state.batcher.sprite(
                        zm.f32x4(positions[i].x, positions[i].y + positions[i].z, positions[i].z, 0),
                        game.state.diffusemap,
                        game.state.atlas.sprites[renderers[i].head_index],
                        .{
                            .color = renderers[i].head_color.value,
                            .frag_mode = .palette,
                            .flip_x = renderers[i].flip_head,
                            .rotation = rotation,
                        },
                    ) catch unreachable;

                    // Bottom
                    game.state.batcher.sprite(
                        zm.f32x4(positions[i].x, positions[i].y + positions[i].z, positions[i].z, 0),
                        game.state.diffusemap,
                        game.state.atlas.sprites[renderers[i].bottom_index],
                        .{
                            .color = renderers[i].bottom_color.value,
                            .frag_mode = .palette,
                            .flip_x = renderers[i].flip_body,
                            .rotation = rotation,
                        },
                    ) catch unreachable;

                    // Top
                    game.state.batcher.sprite(
                        zm.f32x4(positions[i].x, positions[i].y + positions[i].z, positions[i].z, 0),
                        game.state.diffusemap,
                        game.state.atlas.sprites[renderers[i].top_index],
                        .{
                            .color = renderers[i].top_color.value,
                            .frag_mode = .palette,
                            .flip_x = renderers[i].flip_body,
                            .rotation = rotation,
                        },
                    ) catch unreachable;

                    // Hair
                    game.state.batcher.sprite(
                        zm.f32x4(positions[i].x, positions[i].y + positions[i].z, positions[i].z, 0),
                        game.state.diffusemap,
                        game.state.atlas.sprites[renderers[i].hair_index],
                        .{
                            .color = renderers[i].hair_color.value,
                            .frag_mode = .palette,
                            .flip_x = renderers[i].flip_head,
                            .rotation = rotation,
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
