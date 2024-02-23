const std = @import("std");
const zmath = @import("zmath");
const game = @import("../aftersun.zig");

const core = @import("mach-core");

pub const Camera = struct {
    zoom: f32 = 1.0,
    zoom_step: f32 = 1.0,
    zoom_step_next: f32 = 1.0,
    zoom_progress: f32 = -1.0,
    position: zmath.F32x4 = zmath.f32x4s(0),
    culling_margin: f32 = 256.0,

    pub fn init(position: zmath.F32x4) Camera {
        return .{
            .zoom = minZoom() + 1.0,
            .position = position,
        };
    }

    pub fn frameBufferResize(camera: *Camera) void {
        const min_zoom = minZoom();
        camera.zoom = min_zoom + 1.0;
    }

    /// Use this matrix when drawing to the framebuffer.
    pub fn frameBufferMatrix(camera: Camera) zmath.Mat {
        const fb_ortho = zmath.orthographicLh(game.window_size[0], game.window_size[1], -100, 100);
        const fb_scaling = zmath.scaling(camera.zoom, camera.zoom, 1);
        const fb_translation = zmath.translation(-game.settings.design_size[0] / 2 * camera.zoom, -game.settings.design_size[1] / 2 * camera.zoom, 1);

        return zmath.mul(fb_scaling, zmath.mul(fb_translation, fb_ortho));
    }

    /// Use this matrix when drawing to an off-screen render texture.
    pub fn renderTextureMatrix(camera: Camera) zmath.Mat {
        const rt_ortho = zmath.orthographicLh(game.settings.design_size[0], game.settings.design_size[1], -100, 100);
        const rt_translation = zmath.translation(-camera.position[0], -camera.position[1], 0);

        return zmath.mul(rt_translation, rt_ortho);
    }

    /// Transforms a position from screen-space to world-space.
    /// Remember that in screen-space positive Y is down, and positive Y is up in world-space.
    pub fn screenToWorld(camera: Camera, position: zmath.F32x4) zmath.F32x4 {
        const fb_mat = camera.frameBufferMatrix();
        const ndc = zmath.mul(fb_mat, zmath.f32x4(position[0], -position[1], 1, 1)) / zmath.f32x4(camera.zoom * 2, camera.zoom * 2, 1, 1) + zmath.f32x4(-0.5, 0.5, 1, 1);
        const world = ndc * zmath.f32x4(game.window_size[0] / camera.zoom, game.window_size[1] / camera.zoom, 1, 1) - zmath.f32x4(-camera.position[0], -camera.position[1], 1, 1);

        return zmath.f32x4(world[0], world[1], 0, 0);
    }

    /// Transforms a position from world-space to screen-space.
    /// Remember that in screen-space positive Y is down, and positive Y is up in world-space.
    pub fn worldToScreen(camera: Camera, position: zmath.F32x4) zmath.F32x4 {
        const cs = game.state.gctx.window.getContentScale();
        const screen = (camera.position - position) * zmath.f32x4(camera.zoom * cs[0], camera.zoom * cs[1], 0, 0) - zmath.f32x4((game.window_size[0] / 2) * cs[0], (-game.window_size[1] / 2) * cs[1], 0, 0);

        return zmath.f32x4(-screen[0], screen[1], 0, 0);
    }

    /// Returns the minimum zoom needed to render to the window without black bars.
    pub fn minZoom() f32 {
        const window_size = zmath.f32x4(game.window_size[0], game.window_size[1], 1.0, 1.0);
        const max_visible_size = zmath.f32x4s(game.settings.max_visible_tiles * game.settings.pixels_per_unit);
        const min_zoom = zmath.ceil(window_size / max_visible_size);
        return @max(min_zoom[0], min_zoom[1]);
    }

    /// Returns the maximum zoom allowed for the current window size.
    pub fn maxZoom() f32 {
        const min = minZoom();
        return min + game.settings.max_zoom_offset;
    }
};
