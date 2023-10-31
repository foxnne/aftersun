const std = @import("std");
const zmath = @import("zmath");
const ecs = @import("zflecs");
const game = @import("../../aftersun.zig");
const gfx = game.gfx;
const components = game.components;

pub fn system() ecs.system_desc_t {
    var desc: ecs.system_desc_t = .{};
    desc.callback = callback;
    return desc;
}

pub fn callback(it: *ecs.iter_t) callconv(.C) void {
    if (it.count() > 0) return;

    const uniforms = gfx.UniformBufferObject{
        .mvp = zmath.transpose(zmath.orthographicLh(game.settings.design_size[0], game.settings.design_size[1], -100, 100)),
    };

    game.state.batcher.begin(.{
        .pipeline_handle = game.state.pipeline_glow,
        .bind_group_handle = game.state.bind_group_glow,
        .output_handle = game.state.glow_output.view_handle,
    }) catch unreachable;

    const position = zmath.f32x4(-@as(f32, @floatFromInt(game.state.glow_output.image.width)) / 2, -@as(f32, @floatFromInt(game.state.glow_output.image.height)) / 2, 0, 0);

    game.state.batcher.texture(position, &game.state.glow_output, .{}) catch unreachable;

    game.state.batcher.end(uniforms, game.state.uniform_buffer_default) catch unreachable;
}
