const std = @import("std");
const zm = @import("zmath");
const flecs = @import("flecs");
const game = @import("game");
const components = game.components;

pub fn system() flecs.EcsSystemDesc {
    var desc = std.mem.zeroes(flecs.EcsSystemDesc);
    desc.query.filter.terms[0] = std.mem.zeroInit(flecs.EcsTerm, .{ .id = flecs.ecs_id(components.Position) });
    desc.query.filter.terms[1] = std.mem.zeroInit(flecs.EcsTerm, .{ .id = flecs.ecs_id(components.SpriteRenderer), .oper = flecs.EcsOperKind.ecs_optional });
    desc.query.filter.terms[2] = std.mem.zeroInit(flecs.EcsTerm, .{ .id = flecs.ecs_id(components.CharacterRenderer), .oper = flecs.EcsOperKind.ecs_optional });
    desc.run = run;
    return desc;
}

pub fn run(it: *flecs.EcsIter) callconv(.C) void {
    const camera = game.state.camera;
    const camera_matrix = camera.frameBufferMatrix();
    const camera_tl = camera.screenToWorld(zm.f32x4(-camera.culling_margin, camera.culling_margin, 0, 0), camera_matrix);
    const camera_br = camera.screenToWorld(zm.f32x4(camera.window_size[0] + camera.culling_margin, -camera.window_size[1] - camera.culling_margin, 0, 0), camera_matrix);

    const world = it.world.?;

    while (flecs.ecs_iter_next(it)) {
        var i: usize = 0;
        while (i < it.count) : (i += 1) {
            if (flecs.ecs_field(it, components.Position, 1)) |positions| {
                if (flecs.ecs_field(it, components.SpriteRenderer, 2)) |renderers| {
                    const sprite = game.state.atlas.sprites[renderers[i].index];
                    const width = @intToFloat(f32, sprite.source.width);
                    const height = @intToFloat(f32, sprite.source.height);
                    const origin_x = @intToFloat(f32, sprite.origin.x);
                    const origin_y = @intToFloat(f32, sprite.origin.y);
                    const offset_x = -origin_x;
                    const offset_y = -(height - origin_y);
                    const renderer_tl = zm.f32x4(positions[i].x + offset_x, positions[i].y + offset_y + height, 0, 0);
                    const renderer_br = zm.f32x4(positions[i].x + offset_x + width, positions[i].y + offset_y, 0, 0);

                    if (visible(camera_tl, camera_br, renderer_tl, renderer_br)) {
                        flecs.ecs_add(world, it.entities[i], components.Visible);
                    } else {
                        flecs.ecs_remove(world, it.entities[i], components.Visible);
                    }
                }

                if (flecs.ecs_field(it, components.CharacterRenderer, 3)) |renderers| {
                    const sprite = game.state.atlas.sprites[renderers[i].body_index];
                    const width = @intToFloat(f32, sprite.source.width);
                    const height = @intToFloat(f32, sprite.source.height);
                    const origin_x = @intToFloat(f32, sprite.origin.x);
                    const origin_y = @intToFloat(f32, sprite.origin.y);
                    const offset_x = -origin_x;
                    const offset_y = -(height - origin_y);
                    const renderer_tl = zm.f32x4(positions[i].x + offset_x, positions[i].y + offset_y + height, 0, 0);
                    const renderer_br = zm.f32x4(positions[i].x + offset_x + width, positions[i].y + offset_y, 0, 0);

                    if (visible(camera_tl, camera_br, renderer_tl, renderer_br)) {
                        flecs.ecs_add(world, it.entities[i], components.Visible);
                    } else {
                        flecs.ecs_remove(world, it.entities[i], components.Visible);
                    }
                }
            }
        }
    }
}

fn visible(camera_tl: zm.F32x4, camera_br: zm.F32x4, renderer_tl: zm.F32x4, renderer_br: zm.F32x4) bool {
    return (renderer_tl[0] < camera_br[0] and renderer_br[0] > camera_tl[0] and renderer_tl[1] > camera_br[1] and renderer_br[1] < camera_tl[1]);
}
