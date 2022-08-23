const std = @import("std");
const zm = @import("zmath");
const flecs = @import("flecs");
const game = @import("game");
const components = game.components;
const atlas = game.state.atlas;

pub fn system() flecs.EcsSystemDesc {
    var desc = std.mem.zeroes(flecs.EcsSystemDesc);
    desc.run = run;
    return desc;
}

pub fn run(_: *flecs.EcsIter) callconv(.C) void {
    const scroll = std.math.clamp(game.state.controls.mouse.scroll.y, 0.0, 100.0) / 100.0;
    const zoom = game.math.lerp(game.state.camera.minZoom(), game.state.camera.maxZoom(), scroll);
    game.state.camera.zoom = zoom;
}
