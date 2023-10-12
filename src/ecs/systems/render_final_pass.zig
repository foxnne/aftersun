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

pub const FinalUniforms = extern struct {
    mvp: zmath.Mat,
    output_channel: i32 = 0,
};

pub fn callback(it: *ecs.iter_t) callconv(.C) void {
    if (it.count() > 0) return;

    const uniforms = FinalUniforms{ .mvp = zmath.transpose(game.state.camera.frameBufferMatrix()), .output_channel = @intFromEnum(game.state.output_channel) };

    game.state.batcher.begin(.{
        .pipeline_handle = game.state.pipeline_final,
        .bind_group_handle = game.state.bind_group_final,
    }) catch unreachable;

    game.state.batcher.texture(zmath.f32x4s(0), &game.state.diffuse_output, .{}) catch unreachable;

    game.state.batcher.end(uniforms, game.state.uniform_buffer_final) catch unreachable;
}
