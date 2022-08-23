const std = @import("std");
const glfw = @import("glfw");
const game = @import("game");
const input = @import("input.zig");
 
pub fn cursor(window: glfw.Window, x: f64, y: f64) void {
    const scale_factor = scale_factor: {
        const cs = window.getContentScale() catch unreachable;
        break :scale_factor std.math.max(cs.x_scale, cs.y_scale);
    };
    game.state.controls.mouse.position.x = @floatCast(f32, x / scale_factor);
    game.state.controls.mouse.position.y = @floatCast(f32, y / scale_factor);
}

pub fn scroll(_: glfw.Window, x: f64, y: f64) void {
    game.state.controls.mouse.scroll.x += @floatCast(f32, x);
    game.state.controls.mouse.scroll.y += @floatCast(f32, y);
}

pub fn key(_: glfw.Window, glfw_key: glfw.Key, _: i32, action: glfw.Action, _: glfw.Mods) void {
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
