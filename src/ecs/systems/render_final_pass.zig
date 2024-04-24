const std = @import("std");
const zmath = @import("zmath");
const ecs = @import("zflecs");
const game = @import("../../aftersun.zig");
const gfx = game.gfx;
const components = game.components;
const core = @import("mach").core;

var scanner_time: f32 = 0.0;
var scanner_state: bool = false;

pub fn system() ecs.system_desc_t {
    var desc: ecs.system_desc_t = .{};
    desc.callback = callback;
    return desc;
}

pub const FinalUniforms = extern struct {
    mvp: zmath.Mat,
    inverse_mvp: zmath.Mat,
    output_channel: i32 = 0,
    _pad: u32 = 0,
    mouse: [2]f32 = .{ 0.0, 0.0 },
};

pub const PostUniforms = extern struct {
    mvp: zmath.Mat,
};

pub fn callback(it: *ecs.iter_t) callconv(.C) void {
    if (it.count() > 0) return;

    const mvp = zmath.transpose(zmath.orthographicLh(game.settings.design_size[0], game.settings.design_size[1], -100, 100));

    const final_uniforms = FinalUniforms{
        .mvp = mvp,
        .inverse_mvp = zmath.inverse(mvp),
        .output_channel = @intFromEnum(game.state.output_channel),
        .mouse = game.state.scanner_position,
    };

    game.state.batcher.begin(.{
        .pipeline_handle = game.state.pipeline_final,
        .bind_group_handle = game.state.bind_group_final,
        .output_handle = game.state.final_output.view_handle,
        .clear_color = game.math.Color.initBytes(50, 60, 200, 255).toGpuColor(),
    }) catch unreachable;

    const position = zmath.f32x4(-@as(f32, @floatFromInt(game.state.final_output.image.width)) / 2, -@as(f32, @floatFromInt(game.state.final_output.image.height)) / 2, 0, 0);

    game.state.batcher.texture(position, &game.state.diffuse_output, .{ .data_2 = game.state.scanner_time }) catch unreachable;

    game.state.batcher.end(final_uniforms, game.state.uniform_buffer_final) catch unreachable;

    const post_uniforms: PostUniforms = .{ .mvp = zmath.transpose(game.state.camera.frameBufferMatrix()) };

    game.state.batcher.begin(.{
        .pipeline_handle = game.state.pipeline_post_low_res,
        .bind_group_handle = game.state.bind_group_framebuffer,
        .clear_color = game.math.Color.initBytes(0, 0, 0, 255).toGpuColor(),
        .output_handle = game.state.framebuffer_output.view_handle,
    }) catch unreachable;

    game.state.batcher.texture(zmath.f32x4s(0), &game.state.final_output, .{}) catch unreachable;

    game.state.batcher.end(post_uniforms, game.state.uniform_buffer_default) catch unreachable;

    const fb_ortho: zmath.Mat = zmath.orthographicLh(game.framebuffer_size[0], game.framebuffer_size[1], -100, 100);
    const fb_translation = zmath.translation(-game.framebuffer_size[0] / 2, -game.framebuffer_size[1] / 2, 1);

    const framebuffer_uniforms: PostUniforms = .{ .mvp = zmath.transpose(zmath.mul(fb_translation, fb_ortho)) };

    game.state.batcher.begin(.{
        .pipeline_handle = game.state.pipeline_post_high_res,
        .bind_group_handle = game.state.bind_group_post,
        .clear_color = game.math.Color.initBytes(0, 0, 0, 255).toGpuColor(),
    }) catch unreachable;

    game.state.batcher.texture(zmath.f32x4s(0), &game.state.framebuffer_output, .{}) catch unreachable;

    game.state.batcher.end(framebuffer_uniforms, game.state.uniform_buffer_default) catch unreachable;
}
