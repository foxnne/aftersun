const std = @import("std");
const zmath = @import("zmath");
const ecs = @import("zflecs");
const game = @import("../../aftersun.zig");
const gfx = game.gfx;
const math = game.math;
const components = game.components;

pub fn system(world: *ecs.world_t) ecs.system_desc_t {
    var desc: ecs.system_desc_t = .{};
    desc.run = run;

    var ctx_desc: ecs.query_desc_t = .{};
    ctx_desc.filter.terms[0] = .{ .id = ecs.id(components.Position), .inout = .In };
    ctx_desc.filter.terms[1] = .{ .id = ecs.id(components.Rotation), .oper = ecs.oper_kind_t.Optional, .inout = .In };
    ctx_desc.filter.terms[2] = .{ .id = ecs.id(components.SpriteRenderer), .oper = ecs.oper_kind_t.Optional, .inout = .In };
    ctx_desc.filter.terms[3] = .{ .id = ecs.id(components.CharacterRenderer), .oper = ecs.oper_kind_t.Optional, .inout = .In };
    ctx_desc.filter.terms[4] = .{ .id = ecs.id(components.ParticleRenderer), .oper = ecs.oper_kind_t.Optional, .inout = .In };
    ctx_desc.filter.terms[5] = .{ .id = ecs.id(components.Tile), .inout = .In };
    ctx_desc.order_by_component = ecs.id(components.Tile);
    ctx_desc.order_by = orderBy;
    desc.ctx = ecs.query_init(world, &ctx_desc) catch unreachable;

    return desc;
}

pub fn run(it: *ecs.iter_t) callconv(.C) void {
    const uniforms = gfx.UniformBufferObject{ .mvp = zmath.transpose(game.state.camera.renderTextureMatrix()) };

    if (it.ctx) |ctx| {
        const query = @as(*ecs.query_t, @ptrCast(ctx));

        { // Draw diffuse texture sprites using diffuse pipeline
            var query_it = ecs.query_iter(it.world, query);

            game.state.batcher.begin(.{
                .pipeline_handle = game.state.pipeline_diffuse,
                .bind_group_handle = game.state.bind_group_diffuse,
                .output_handle = game.state.diffuse_output.view_handle,
                .clear_color = math.Colors.clear.toGpuColor(),
            }) catch unreachable;

            while (ecs.iter_next(&query_it)) {
                var i: usize = 0;
                while (i < query_it.count()) : (i += 1) {
                    if (ecs.field(&query_it, components.Position, 1)) |positions| {
                        const rotation = if (ecs.field(&query_it, components.Rotation, 2)) |rotations| rotations[i].value else 0.0;
                        var position = positions[i].toF32x4();
                        position[1] += position[2];

                        if (ecs.field(&query_it, components.SpriteRenderer, 3)) |renderers| {
                            renderers[i].order = @as(usize, @intFromFloat(@abs(@floor(position[1] + position[0])))) + i;

                            game.state.batcher.sprite(
                                position,
                                &game.state.diffusemap,
                                game.state.atlas.sprites[renderers[i].index],
                                .{
                                    .color = renderers[i].color,
                                    .vert_mode = renderers[i].vert_mode,
                                    .frag_mode = renderers[i].frag_mode,
                                    .time = game.state.game_time + @as(f32, @floatFromInt(renderers[i].order)),
                                    .flip_x = renderers[i].flip_x,
                                    .flip_y = renderers[i].flip_y,
                                    .rotation = rotation,
                                },
                            ) catch unreachable;
                        }

                        if (ecs.field(&query_it, components.CharacterRenderer, 4)) |renderers| {
                            // Body
                            game.state.batcher.sprite(
                                position,
                                &game.state.diffusemap,
                                game.state.atlas.sprites[renderers[i].body_index],
                                .{
                                    .color = renderers[i].body_color,
                                    .frag_mode = .palette,
                                    .flip_x = renderers[i].flip_body,
                                    .rotation = rotation,
                                },
                            ) catch unreachable;

                            // Head
                            game.state.batcher.sprite(
                                position,
                                &game.state.diffusemap,
                                game.state.atlas.sprites[renderers[i].head_index],
                                .{
                                    .color = renderers[i].head_color,
                                    .frag_mode = .palette,
                                    .flip_x = renderers[i].flip_head,
                                    .rotation = rotation,
                                },
                            ) catch unreachable;

                            // Bottom
                            game.state.batcher.sprite(
                                position,
                                &game.state.diffusemap,
                                game.state.atlas.sprites[renderers[i].bottom_index],
                                .{
                                    .color = renderers[i].bottom_color,
                                    .frag_mode = .palette,
                                    .flip_x = renderers[i].flip_body,
                                    .rotation = rotation,
                                },
                            ) catch unreachable;

                            // Feet
                            game.state.batcher.sprite(
                                position,
                                &game.state.diffusemap,
                                game.state.atlas.sprites[renderers[i].feet_index],
                                .{
                                    .color = renderers[i].feet_color,
                                    .frag_mode = .palette,
                                    .flip_x = renderers[i].flip_body,
                                    .rotation = rotation,
                                },
                            ) catch unreachable;

                            // Top
                            game.state.batcher.sprite(
                                position,
                                &game.state.diffusemap,
                                game.state.atlas.sprites[renderers[i].top_index],
                                .{
                                    .color = renderers[i].top_color,
                                    .frag_mode = .palette,
                                    .flip_x = renderers[i].flip_body,
                                    .rotation = rotation,
                                },
                            ) catch unreachable;

                            // Back
                            game.state.batcher.sprite(
                                position,
                                &game.state.diffusemap,
                                game.state.atlas.sprites[renderers[i].back_index],
                                .{
                                    .flip_x = renderers[i].flip_body,
                                    .rotation = rotation,
                                },
                            ) catch unreachable;

                            // Hair
                            game.state.batcher.sprite(
                                position,
                                &game.state.diffusemap,
                                game.state.atlas.sprites[renderers[i].hair_index],
                                .{
                                    .color = renderers[i].hair_color,
                                    .frag_mode = .palette,
                                    .flip_x = renderers[i].flip_head,
                                    .rotation = rotation,
                                },
                            ) catch unreachable;
                        }

                        if (ecs.field(&query_it, components.ParticleRenderer, 5)) |renderers| {
                            for (renderers[i].particles) |particle| {
                                if (particle.alive()) {
                                    game.state.batcher.sprite(
                                        zmath.f32x4(particle.position[0], particle.position[1], particle.position[2], 0),
                                        &game.state.diffusemap,
                                        game.state.atlas.sprites[particle.index],
                                        .{
                                            .color = particle.color,
                                        },
                                    ) catch unreachable;
                                }
                            }
                        }
                    }
                }
            }

            game.state.batcher.end(uniforms, game.state.uniform_buffer_default) catch unreachable;
        }

        { // Draw height texture sprites using height pipeline

            var query_it = ecs.query_iter(it.world, query);

            game.state.batcher.begin(.{
                .pipeline_handle = game.state.pipeline_height,
                .bind_group_handle = game.state.bind_group_height,
                .output_handle = game.state.height_output.view_handle,
                .clear_color = math.Color.initBytes(0, 0, 0, 255).toGpuColor(),
            }) catch unreachable;

            while (ecs.iter_next(&query_it)) {
                var i: usize = 0;
                while (i < query_it.count()) : (i += 1) {
                    if (ecs.field(&query_it, components.Position, 1)) |positions| {
                        const rotation = if (ecs.field(&query_it, components.Rotation, 2)) |rotations| rotations[i].value else 0.0;
                        var position = positions[i].toF32x4();
                        position[1] += position[2];

                        if (ecs.field(&query_it, components.SpriteRenderer, 3)) |renderers| {
                            renderers[i].order = @as(usize, @intFromFloat(@abs(@floor(position[1] + position[0])))) + i;

                            game.state.batcher.sprite(
                                position,
                                &game.state.heightmap,
                                game.state.atlas.sprites[renderers[i].index],
                                .{
                                    .vert_mode = renderers[i].vert_mode,
                                    .time = game.state.game_time + @as(f32, @floatFromInt(renderers[i].order)),
                                    .rotation = rotation,
                                    .flip_x = renderers[i].flip_x,
                                    .flip_y = renderers[i].flip_y,
                                },
                            ) catch unreachable;
                        }

                        if (ecs.field(&query_it, components.CharacterRenderer, 4)) |renderers| {
                            // Body
                            game.state.batcher.sprite(
                                position,
                                &game.state.heightmap,
                                game.state.atlas.sprites[renderers[i].body_index],
                                .{
                                    .flip_x = renderers[i].flip_body,
                                    .rotation = rotation,
                                },
                            ) catch unreachable;

                            // Head
                            game.state.batcher.sprite(
                                position,
                                &game.state.heightmap,
                                game.state.atlas.sprites[renderers[i].head_index],
                                .{
                                    .flip_x = renderers[i].flip_head,
                                    .rotation = rotation,
                                },
                            ) catch unreachable;

                            // Bottom
                            game.state.batcher.sprite(
                                position,
                                &game.state.heightmap,
                                game.state.atlas.sprites[renderers[i].bottom_index],
                                .{
                                    .flip_x = renderers[i].flip_body,
                                    .rotation = rotation,
                                },
                            ) catch unreachable;

                            // Feet
                            game.state.batcher.sprite(
                                position,
                                &game.state.heightmap,
                                game.state.atlas.sprites[renderers[i].feet_index],
                                .{
                                    .flip_x = renderers[i].flip_body,
                                    .rotation = rotation,
                                },
                            ) catch unreachable;

                            // Top
                            game.state.batcher.sprite(
                                position,
                                &game.state.heightmap,
                                game.state.atlas.sprites[renderers[i].top_index],
                                .{
                                    .flip_x = renderers[i].flip_body,
                                    .rotation = rotation,
                                },
                            ) catch unreachable;

                            // Back
                            game.state.batcher.sprite(
                                position,
                                &game.state.heightmap,
                                game.state.atlas.sprites[renderers[i].back_index],
                                .{
                                    .flip_x = renderers[i].flip_body,
                                    .rotation = rotation,
                                },
                            ) catch unreachable;

                            // Hair
                            game.state.batcher.sprite(
                                position,
                                &game.state.heightmap,
                                game.state.atlas.sprites[renderers[i].hair_index],
                                .{
                                    .flip_x = renderers[i].flip_head,
                                    .rotation = rotation,
                                },
                            ) catch unreachable;
                        }

                        if (ecs.field(&query_it, components.ParticleRenderer, 5)) |renderers| {
                            for (renderers[i].particles) |particle| {
                                if (particle.alive()) {
                                    game.state.batcher.sprite(
                                        zmath.f32x4(particle.position[0], particle.position[1], particle.position[2], 0),
                                        &game.state.heightmap,
                                        game.state.atlas.sprites[particle.index],
                                        .{},
                                    ) catch unreachable;
                                }
                            }
                        }
                    }
                }
            }

            game.state.batcher.end(uniforms, game.state.uniform_buffer_default) catch unreachable;
        }

        { // Draw reflection sprites using diffuse pipeline

            var query_it = ecs.query_iter(it.world, query);

            game.state.batcher.begin(.{
                .pipeline_handle = game.state.pipeline_diffuse,
                .bind_group_handle = game.state.bind_group_diffuse,
                .output_handle = game.state.reflection_output.view_handle,
                .clear_color = math.Colors.clear.toGpuColor(),
            }) catch unreachable;

            while (ecs.iter_next(&query_it)) {
                var i: usize = 0;
                while (i < query_it.count()) : (i += 1) {
                    if (ecs.field(&query_it, components.Position, 1)) |positions| {
                        const rotation = 180;
                        var position = positions[i].toF32x4();
                        position[1] -= position[2];
                        position[1] -= game.settings.pixels_per_unit / 3;

                        if (ecs.field(&query_it, components.SpriteRenderer, 3)) |renderers| {
                            renderers[i].order = @as(usize, @intFromFloat(@abs(@floor(position[1] + position[0])))) + i;

                            if (renderers[i].reflect) {
                                game.state.batcher.sprite(
                                    position,
                                    &game.state.diffusemap,
                                    game.state.atlas.sprites[renderers[i].index],
                                    .{
                                        .color = renderers[i].color,
                                        .vert_mode = renderers[i].vert_mode,
                                        .frag_mode = renderers[i].frag_mode,
                                        .time = game.state.game_time + @as(f32, @floatFromInt(renderers[i].order)),
                                        .flip_x = !renderers[i].flip_x,
                                        .flip_y = renderers[i].flip_y,
                                        .rotation = rotation,
                                    },
                                ) catch unreachable;
                            }
                        }

                        if (ecs.field(&query_it, components.CharacterRenderer, 4)) |renderers| {
                            // Body
                            game.state.batcher.sprite(
                                position,
                                &game.state.diffusemap,
                                game.state.atlas.sprites[renderers[i].body_index],
                                .{
                                    .color = renderers[i].body_color,
                                    .frag_mode = .palette,
                                    .flip_x = !renderers[i].flip_body,
                                    .rotation = rotation,
                                },
                            ) catch unreachable;

                            // Head
                            game.state.batcher.sprite(
                                position,
                                &game.state.diffusemap,
                                game.state.atlas.sprites[renderers[i].head_index],
                                .{
                                    .color = renderers[i].head_color,
                                    .frag_mode = .palette,
                                    .flip_x = !renderers[i].flip_head,
                                    .rotation = rotation,
                                },
                            ) catch unreachable;

                            // Bottom
                            game.state.batcher.sprite(
                                position,
                                &game.state.diffusemap,
                                game.state.atlas.sprites[renderers[i].bottom_index],
                                .{
                                    .color = renderers[i].bottom_color,
                                    .frag_mode = .palette,
                                    .flip_x = !renderers[i].flip_body,
                                    .rotation = rotation,
                                },
                            ) catch unreachable;

                            // Feet
                            game.state.batcher.sprite(
                                position,
                                &game.state.diffusemap,
                                game.state.atlas.sprites[renderers[i].feet_index],
                                .{
                                    .color = renderers[i].feet_color,
                                    .frag_mode = .palette,
                                    .flip_x = !renderers[i].flip_body,
                                    .rotation = rotation,
                                },
                            ) catch unreachable;

                            // Top
                            game.state.batcher.sprite(
                                position,
                                &game.state.diffusemap,
                                game.state.atlas.sprites[renderers[i].top_index],
                                .{
                                    .color = renderers[i].top_color,
                                    .frag_mode = .palette,
                                    .flip_x = !renderers[i].flip_body,
                                    .rotation = rotation,
                                },
                            ) catch unreachable;

                            // Back
                            game.state.batcher.sprite(
                                position,
                                &game.state.diffusemap,
                                game.state.atlas.sprites[renderers[i].back_index],
                                .{
                                    .flip_x = !renderers[i].flip_body,
                                    .rotation = rotation,
                                },
                            ) catch unreachable;

                            // Hair
                            game.state.batcher.sprite(
                                position,
                                &game.state.diffusemap,
                                game.state.atlas.sprites[renderers[i].hair_index],
                                .{
                                    .color = renderers[i].hair_color,
                                    .frag_mode = .palette,
                                    .flip_x = !renderers[i].flip_head,
                                    .rotation = rotation,
                                },
                            ) catch unreachable;
                        }
                    }
                }
            }

            game.state.batcher.end(uniforms, game.state.uniform_buffer_default) catch unreachable;
        }

        { // Draw reverse height texture sprites using height pipeline

            // Since we cant reliably and quickly afford another full entity sort and
            // render just for the sake of overlapping heightmaps, a compromise was made here.

            // Instead, we render all of the heightmaps of any regular sprites, this removes all
            // particle systems and characters, which should remove a large portion of the overlapping.

            var query_it = ecs.query_iter(it.world, query);

            game.state.batcher.begin(.{
                .pipeline_handle = game.state.pipeline_height,
                .bind_group_handle = game.state.bind_group_height,
                .output_handle = game.state.reverse_height_output.view_handle,
                .clear_color = math.Color.initBytes(0, 0, 0, 255).toGpuColor(),
            }) catch unreachable;

            while (ecs.iter_next(&query_it)) {
                var i: usize = 0;
                while (i < query_it.count()) : (i += 1) {
                    if (ecs.field(&query_it, components.Position, 1)) |positions| {
                        const rotation = if (ecs.field(&query_it, components.Rotation, 2)) |rotations| rotations[i].value else 0.0;
                        var position = positions[i].toF32x4();
                        position[1] += position[2];

                        if (ecs.field(&query_it, components.SpriteRenderer, 3)) |renderers| {
                            renderers[i].order = @as(usize, @intFromFloat(@abs(@floor(position[1] + position[0])))) + i;

                            game.state.batcher.sprite(
                                position,
                                &game.state.heightmap,
                                game.state.atlas.sprites[renderers[i].index],
                                .{
                                    .vert_mode = renderers[i].vert_mode,
                                    .time = game.state.game_time + @as(f32, @floatFromInt(renderers[i].order)),
                                    .rotation = rotation,
                                    .flip_x = renderers[i].flip_x,
                                    .flip_y = renderers[i].flip_y,
                                },
                            ) catch unreachable;
                        }
                    }
                }
            }

            game.state.batcher.end(uniforms, game.state.uniform_buffer_default) catch unreachable;
        }
    }
}

fn orderBy(e1: ecs.entity_t, c1: ?*const anyopaque, e2: ecs.entity_t, c2: ?*const anyopaque) callconv(.C) c_int {
    _ = e2;
    _ = e1;
    const tile_1 = ecs.cast(components.Tile, c1);
    const tile_2 = ecs.cast(components.Tile, c2);

    if (tile_1.z > tile_2.z) return @as(c_int, 1) else if (tile_1.z < tile_2.z) return @as(c_int, 0);

    if (tile_1.y == tile_2.y) {
        return @as(c_int, @intCast(@intFromBool(tile_1.counter > tile_2.counter))) - @as(c_int, @intCast(@intFromBool(tile_1.counter < tile_2.counter)));
    }

    if (tile_1.kind != .none and tile_2.kind == .none) return @as(c_int, 0) else if (tile_1.kind == .none and tile_2.kind != .none) return @as(c_int, 1);

    return @as(c_int, @intCast(@intFromBool(tile_1.y < tile_2.y))) - @as(c_int, @intCast(@intFromBool(tile_1.y > tile_2.y)));
}
