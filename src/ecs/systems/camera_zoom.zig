const std = @import("std");
const zm = @import("zmath");
const flecs = @import("flecs");
const game = @import("root");
const components = game.components;

pub fn system() flecs.EcsSystemDesc {
    var desc = std.mem.zeroes(flecs.EcsSystemDesc);
    desc.run = run;
    return desc;
}

pub fn run(it: *flecs.EcsIter) callconv(.C) void {
    game.input.callbacks.scroll(game.state.gctx.window, 0.0, game.state.controls.zoom());

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
