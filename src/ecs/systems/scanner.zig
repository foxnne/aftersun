const std = @import("std");
const zmath = @import("zmath");
const ecs = @import("zflecs");
const game = @import("../../aftersun.zig");
const components = game.components;

pub fn system() ecs.system_desc_t {
    var desc: ecs.system_desc_t = .{};
    desc.run = run;
    return desc;
}

pub fn run(it: *ecs.iter_t) callconv(.C) void {
    if (game.state.hotkeys.hotkey(.scanner)) |hk| {
        if (hk.pressed()) {
            game.state.scanner_state = game.state.camera.zoom == game.gfx.Camera.minZoom();
            game.state.scanner_state = !game.state.scanner_state;

            if (game.state.scanner_state) {
                game.state.camera.zoom_progress = 0.0;
                game.state.camera.zoom_step = @round(game.state.camera.zoom);
                game.state.camera.zoom_step_next = game.gfx.Camera.minZoom();
            } else {
                game.state.camera.zoom_step_next = game.gfx.Camera.maxZoom() - 1.0;
                game.state.camera.zoom_step = @round(game.state.camera.zoom);
                game.state.camera.zoom_progress = 0.0;
            }
        }
    }

    if (game.state.scanner_state or game.state.camera.zoom == game.gfx.Camera.minZoom()) {
        if (game.state.scanner_time < 1.0) {
            game.state.scanner_time = @min(1.0, game.state.scanner_time + (it.delta_time / 6.0));
        } else {
            game.state.scanner_time = 0.0;
        }
    } else {
        if (game.state.scanner_time > 0.0)
            game.state.scanner_time = @max(0.0, game.state.scanner_time - it.delta_time);
    }
}
