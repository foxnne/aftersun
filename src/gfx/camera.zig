const std = @import("std");
const zmath = @import("zmath");
const game = @import("../aftersun.zig");

const core = @import("mach-core");

pub const Camera = struct {
    design_size: zmath.F32x4,
    window_size: zmath.F32x4,
    zoom: f32 = 1.0,
    zoom_step: f32 = 1.0,
    zoom_step_next: f32 = 1.0,
    zoom_progress: f32 = -1.0,
    position: zmath.F32x4 = zmath.f32x4s(0),
    tile: zmath.F32x4 = zmath.f32x4s(0),
    target_tile: zmath.F32x4 = zmath.f32x4s(0),
    culling_margin: f32 = 256.0,

    pub fn init(design_size: zmath.F32x4, window_size: [2]f32, position: zmath.F32x4) Camera {
        const w_size = zmath.f32x4(window_size[0], window_size[1], 0, 0);
        const zooms = zmath.ceil(w_size / design_size);
        const zoom = @max(zooms[0], zooms[1]) + 1.0; // Initially set the zoom to be 1 step greater than minimum.

        return .{
            .design_size = design_size,
            .window_size = w_size,
            .zoom = zoom,
            .position = position,
        };
    }

    pub fn frameBufferResize(camera: *Camera, new_size: core.Size) void {
        camera.window_size[0] = @floatFromInt(new_size.width);
        camera.window_size[1] = @floatFromInt(new_size.height);

        const min_zoom = camera.minZoom();
        const max_zoom = camera.maxZoom();
        if (camera.zoom < min_zoom) camera.zoom = min_zoom;
        if (camera.zoom > max_zoom) camera.zoom = max_zoom;
    }

    /// Use this matrix when drawing to the framebuffer.
    pub fn frameBufferMatrix(camera: Camera) zmath.Mat {
        const fb_ortho = zmath.orthographicLh(camera.window_size[0], camera.window_size[1], -100, 100);
        const fb_scaling = zmath.scaling(camera.zoom, camera.zoom, 1);
        const fb_translation = zmath.translation(-camera.design_size[0] / 2 * camera.zoom, -camera.design_size[1] / 2 * camera.zoom, 1);

        return zmath.mul(fb_scaling, zmath.mul(fb_translation, fb_ortho));
    }

    /// Use this matrix when drawing to an off-screen render texture.
    pub fn renderTextureMatrix(camera: Camera) zmath.Mat {
        const rt_ortho = zmath.orthographicLh(camera.design_size[0], camera.design_size[1], -100, 100);
        const rt_translation = zmath.translation(-camera.position[0], -camera.position[1], 0);

        return zmath.mul(rt_translation, rt_ortho);
    }

    /// Transforms a position from screen-space to world-space.
    /// Remember that in screen-space positive Y is down, and positive Y is up in world-space.
    pub fn screenToWorld(camera: Camera, position: zmath.F32x4, fb_mat: zmath.Mat) zmath.F32x4 {
        const ndc = zmath.mul(fb_mat, zmath.f32x4(position[0], -position[1], 1, 1)) / zmath.f32x4(camera.zoom * 2, camera.zoom * 2, 1, 1) + zmath.f32x4(-0.5, 0.5, 1, 1);
        const world = ndc * zmath.f32x4(camera.window_size[0] / camera.zoom, camera.window_size[1] / camera.zoom, 1, 1) - zmath.f32x4(-camera.position[0], -camera.position[1], 1, 1);

        return zmath.f32x4(world[0], world[1], 0, 0);
    }

    /// Transforms a position from world-space to screen-space.
    /// Remember that in screen-space positive Y is down, and positive Y is up in world-space.
    pub fn worldToScreen(camera: Camera, position: zmath.F32x4) zmath.F32x4 {
        const cs = game.state.gctx.window.getContentScale();
        const screen = (camera.position - position) * zmath.f32x4(camera.zoom * cs[0], camera.zoom * cs[1], 0, 0) - zmath.f32x4((camera.window_size[0] / 2) * cs[0], (-camera.window_size[1] / 2) * cs[1], 0, 0);

        return zmath.f32x4(-screen[0], screen[1], 0, 0);
    }

    /// Returns the minimum zoom needed to render to the window without black bars.
    pub fn minZoom(camera: Camera) f32 {
        const zoom = zmath.ceil(camera.window_size / camera.design_size);
        return @max(zoom[0], zoom[1]);
    }

    /// Returns the maximum zoom allowed for the current window size.
    pub fn maxZoom(camera: Camera) f32 {
        const min = camera.minZoom();
        return min + game.settings.max_zoom_offset;
    }
};
