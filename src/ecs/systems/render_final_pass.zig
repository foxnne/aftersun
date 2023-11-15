const std = @import("std");
const zmath = @import("zmath");
const ecs = @import("zflecs");
const game = @import("../../aftersun.zig");
const gfx = game.gfx;
const components = game.components;
const core = @import("mach-core");

pub fn system() ecs.system_desc_t {
    var desc: ecs.system_desc_t = .{};
    desc.callback = callback;
    return desc;
}

pub const FinalUniforms = extern struct {
    mvp: zmath.Mat,
    output_channel: i32 = 0,
};

pub fn callback(it: *ecs.iter_t) callconv(.C) void {
    if (it.count() > 0) return;

    const final_uniforms = FinalUniforms{ .mvp = zmath.transpose(zmath.orthographicLh(game.settings.design_size[0], game.settings.design_size[1], -100, 100)), .output_channel = @intFromEnum(game.state.output_channel) };

    game.state.batcher.begin(.{
        .pipeline_handle = game.state.pipeline_final,
        .bind_group_handle = game.state.bind_group_final,
        .output_handle = game.state.final_output.view_handle,
        .clear_color = game.math.Color.initBytes(50, 60, 200, 255).toGpuColor(),
    }) catch unreachable;

    const position = zmath.f32x4(-@as(f32, @floatFromInt(game.state.final_output.image.width)) / 2, -@as(f32, @floatFromInt(game.state.final_output.image.height)) / 2, 0, 0);

    const scanner_time = @mod(game.state.game_time / 4, 1);
    game.state.batcher.texture(position, &game.state.diffuse_output, .{ .data_2 = scanner_time }) catch unreachable;

    game.state.batcher.end(final_uniforms, game.state.uniform_buffer_final) catch unreachable;

    const post_uniforms = game.gfx.UniformBufferObject{ .mvp = zmath.transpose(game.state.camera.frameBufferMatrix()) };

    game.state.batcher.begin(.{
        .pipeline_handle = game.state.pipeline_post,
        .bind_group_handle = game.state.bind_group_post,
        .clear_color = game.math.Color.initBytes(0, 0, 0, 255).toGpuColor(),
    }) catch unreachable;

    game.state.batcher.texture(zmath.f32x4s(0), &game.state.final_output, .{}) catch unreachable;

    game.state.batcher.end(post_uniforms, game.state.uniform_buffer_default) catch unreachable;
}
