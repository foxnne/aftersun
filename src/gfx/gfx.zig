const std = @import("std");
const zm = @import("zmath");
const game = @import("game");

pub const utils = @import("utils.zig");

pub const Animation = @import("animation.zig").Animation;
pub const Atlas = @import("atlas.zig").Atlas;
pub const Sprite = @import("sprite.zig").Sprite;
pub const Quad = @import("quad.zig").Quad;
pub const Batcher = @import("batcher.zig").Batcher;
pub const Texture = @import("texture.zig").Texture;
pub const Camera = @import("camera.zig").Camera;

pub const Vertex = struct {
    position: [3]f32 = [_]f32{ 0.0, 0.0, 0.0 },
    uv: [2]f32 = [_]f32{ 0.0, 0.0 },
    color: [4]f32 = [_]f32{ 1.0, 1.0, 1.0, 1.0 },
    data: [3]f32 = [_]f32{ 0.0, 0.0, 0.0 },
};

pub const Uniforms = struct {
    mvp: zm.Mat,
};

test "Camera - CoordinateConversion" {
        var camera = Camera.init(game.settings.design_size, .{ .w = game.settings.design_width, .h = game.settings.design_height}, zm.f32x4(2, 4, 0, 0));
        camera.zoom = 2.0;
        const screen_pos = zm.f32x4(24, 36, 0, 0);
        const fb_mat = camera.frameBufferMatrix();
        const world_pos = camera.screenToWorld(screen_pos, fb_mat);
        const screen_pos_converted = camera.worldToScreen(world_pos, fb_mat);
        try std.testing.expect(screen_pos[0] == screen_pos_converted[0]);
        try std.testing.expect(screen_pos[1] == screen_pos_converted[1]);
}