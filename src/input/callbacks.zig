const std = @import("std");
const glfw = @import("glfw");
const game = @import("game");
const input = @import("input.zig");
const zgpu = @import("zgpu");

pub fn cursor(window: glfw.Window, x: f64, y: f64) void {
    const scale_factor = scale_factor: {
        const cs = window.getContentScale() catch unreachable;
        break :scale_factor std.math.max(cs.x_scale, cs.y_scale);
    };
    game.state.controls.mouse.position.x = @floatCast(f32, x / scale_factor);
    game.state.controls.mouse.position.y = @floatCast(f32, y / scale_factor);
}

pub fn scroll(_: glfw.Window, _: f64, y: f64) void {
    if (zgpu.zgui.io.getWantCaptureMouse()) return;

    if (y > game.settings.zoom_scroll_tolerance and game.state.camera.zoom_progress < 0.0) {
        const max_zoom = game.state.camera.maxZoom();
        game.state.camera.zoom_step = @round(game.state.camera.zoom);
        if (game.state.camera.zoom_step + 1.0 <= max_zoom) {
            game.state.camera.zoom_progress = 0.0;
            game.state.camera.zoom_step_next = game.state.camera.zoom_step + 1.0;
        }
    }
    if (y < -game.settings.zoom_scroll_tolerance and game.state.camera.zoom_progress < 0.0) {
        const min_zoom = game.state.camera.minZoom();
        game.state.camera.zoom_step = @round(game.state.camera.zoom);
        if (game.state.camera.zoom_step - 1.0 >= min_zoom) {
            game.state.camera.zoom_progress = 0.0;
            game.state.camera.zoom_step_next = game.state.camera.zoom_step - 1.0;
        }
    }
}

pub fn key(_: glfw.Window, glfw_key: glfw.Key, _: i32, action: glfw.Action, _: glfw.Mods) void {
    if (zgpu.zgui.io.getWantCaptureKeyboard()) return;
    for (game.state.controls.keys) |*k| {
        if (k.primary == glfw_key or k.secondary == glfw_key) {
            k.previous_state = k.state;
            k.state = switch (action) {
                .release => false,
                .press => true,
                .repeat => true,
            };
        }
    }
}
