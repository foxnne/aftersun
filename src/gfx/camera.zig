const std = @import("std");
const zm = @import("zmath");
const zgpu = @import("zgpu");
const glfw = @import("glfw");

pub const Camera = struct {
    design_size: zm.F32x4,
    window_size: zm.F32x4,
    zoom: f32 = 1,
    position: zm.F32x4 = zm.f32x4(0, 0, 0, 0),
    culling_margin: f32 = 256.0,

    pub fn init (design_size: zm.F32x4, window_size: glfw.Window.Size, zoom: f32, position: zm.F32x4) Camera {
        return .{
            .design_size = design_size,
            .window_size = zm.f32x4(@intToFloat(f32, window_size.width), @intToFloat(f32, window_size.height), 0, 0),
            .zoom = zoom,
            .position = position,
        };
    }

    /// Sets window size from the window, call this everytime the window changes.
    pub fn setWindow (self: *Camera, window: glfw.Window) void {
        const window_size = window.getSize() catch unreachable;
        self.window_size = zm.f32x4(@intToFloat(f32, window_size.width), @intToFloat(f32, window_size.height), 0, 0);
    }

    /// Use this matrix when drawing to the framebuffer.
    pub fn frameBufferMatrix (self: Camera) zm.Mat {
        const fb_ortho = zm.orthographicLh(self.window_size[0], self.window_size[1], -100, 100);
        const fb_scaling = zm.scaling(self.zoom, self.zoom, 0);
        const fb_translation = zm.translation(-self.design_size[0] / 2 * self.zoom, -self.design_size[1] / 2 * self.zoom, 0);

        return zm.mul(fb_scaling, zm.mul(fb_translation, fb_ortho));
    }

    /// Use this matrix when drawing to an off-screen render texture.
    pub fn renderTextureMatrix (self: Camera) zm.Mat {
        const rt_ortho = zm.orthographicLh(self.design_size[0], self.design_size[1], -100, 100);
        const rt_translation = zm.translation(-self.position[0], -self.position[1], 0);

        return zm.mul(rt_translation, rt_ortho);
    }

    /// Transforms a position from screen-space to world-space.
    /// Remember that in screen-space positive Y is down, and positive Y is up in world-space.
    pub fn screenToWorld (self: Camera, position: zm.F32x4, fb_mat: zm.Mat) zm.F32x4 {

        const ndc = zm.mul(fb_mat, zm.f32x4(position[0], -position[1], 0, 0)) / zm.f32x4(self.zoom * 2, self.zoom * 2, 0, 0) + zm.f32x4(-0.5, 0.5, 0, 0);
        const world = ndc * zm.f32x4(self.window_size[0] / self.zoom, self.window_size[1] / self.zoom, 0, 0) - zm.f32x4(-self.position[0], -self.position[1], 0, 0);
        
        return zm.f32x4(world[0], world[1], 0, 0);
    }
};