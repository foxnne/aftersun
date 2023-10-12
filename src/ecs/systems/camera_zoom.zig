const std = @import("std");
const zm = @import("zmath");
const ecs = @import("zflecs");
const game = @import("root");
const components = game.components;

pub fn system() ecs.system_desc_t {
    var desc: ecs.system_desc_t = .{};
    desc.run = run;
    return desc;
}

pub fn run(it: *ecs.iter_t) callconv(.C) void {
    if (game.state.camera.zoom_progress >= 0.0) {
        game.state.camera.zoom_progress += it.delta_time * game.settings.zoom_speed;
        if (game.state.camera.zoom_progress >= 1.0) {
            game.state.camera.zoom_progress = -1.0;
            game.state.camera.zoom = game.state.camera.zoom_step_next;
        } else {
            game.state.camera.zoom = game.math.lerp(game.state.camera.zoom_step, game.state.camera.zoom_step_next, game.state.camera.zoom_progress);
        }
    }
}
