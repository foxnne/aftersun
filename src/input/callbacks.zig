const std = @import("std");
const zglfw = @import("zglfw");
const game = @import("game");
const input = @import("input.zig");
const zgpu = @import("zgpu");
const zgui = @import("zgui");

const flecs = @import("flecs");
const components = game.components;

pub fn cursor(window: zglfw.Window, x: f64, y: f64) void {
    const scale_factor = scale_factor: {
        const cs = window.getContentScale();
        break :scale_factor std.math.max(cs.x, cs.y);
    };
    game.state.controls.mouse.position.x = @floatCast(f32, x / scale_factor);
    game.state.controls.mouse.position.y = @floatCast(f32, y / scale_factor);
}

pub fn scroll(_: zglfw.Window, _: f64, y: f64) void {
    if (zgui.io.getWantCaptureMouse()) return;

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

pub fn button(_: zglfw.Window, glfw_button: zglfw.MouseButton, action: zglfw.Action, mods: zglfw.Mods) void {
    if (zgui.io.getWantCaptureMouse()) return;

    const tile = game.state.controls.mouse.position.tile();

    if (glfw_button == game.state.controls.mouse.primary.button) {
        game.state.controls.mouse.primary.previous_state = game.state.controls.mouse.primary.state;
        switch (action) {
            .release => {
                game.state.controls.mouse.primary.state = false;
                game.state.controls.mouse.primary_up = tile;
            },
            .repeat,
            .press => {
                game.state.controls.mouse.primary.state = true;
                game.state.controls.mouse.primary_down = tile;
            },
        }
    }

    if (glfw_button == game.state.controls.mouse.secondary.button) {
        game.state.controls.mouse.secondary.previous_state = game.state.controls.mouse.secondary.state;
        switch (action) {
            .release => {
                game.state.controls.mouse.secondary.state = false;
                game.state.controls.mouse.secondary_up = tile;
            },
            .repeat,
            .press => {
                game.state.controls.mouse.secondary.state = true;
                game.state.controls.mouse.secondary_down = tile;
            },
        }
    }

    if (game.state.controls.mouse.primary_down) |down| {
        if (game.state.controls.mouse.primary_up) |up| {
            if (down.x != up.x or down.y != up.y) {
                flecs.ecs_set_pair_second(game.state.world, game.state.entities.player, components.Request, &components.Drag{
                    .start = down,
                    .end = up,
                    .modifier = if (mods.super or mods.control) .half else if (mods.shift) .one else .all,
                });
            }
            game.state.controls.mouse.primary_up = null;
            game.state.controls.mouse.primary_down = null;
        } 
    }
}

pub fn key(_: zglfw.Window, glfw_key: zglfw.Key, _: i32, action: zglfw.Action, _: zglfw.Mods) void {
    if (zgui.io.getWantCaptureKeyboard()) return;
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
