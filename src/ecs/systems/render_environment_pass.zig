const std = @import("std");
const zm = @import("zmath");
const flecs = @import("flecs");
const game = @import("root");
const gfx = game.gfx;
const components = game.components;

pub fn system() flecs.EcsSystemDesc {
    var desc = std.mem.zeroes(flecs.EcsSystemDesc);
    desc.callback = callback;
    return desc;
}

// ! Custom uniforms are automatically aligned by zgpu to 256 bytes,
// ! but arrays and vectors need to be manually aligned to 16 bytes.
// ! https://gpuweb.github.io/gpuweb/wgsl/#alignment-and-size
pub const EnvironmentUniforms = extern struct {
    mvp: zm.Mat,
    ambient_xy_angle: f32 = 45,
    ambient_z_angle: f32 = 82,
    _pad0: f64 = 0,
    shadow_color: [3]f32 = [_]f32{ 0.7, 0.7, 1.0 },
    shadow_steps: i32 = 150,
};

pub fn callback(it: *flecs.EcsIter) callconv(.C) void {
    if (it.count > 0) return;

    const shadow_color = game.state.environment.shadowColor().toSlice();
    const uniforms = EnvironmentUniforms{
        .mvp = zm.transpose(zm.orthographicLh(game.state.camera.design_size[0], game.state.camera.design_size[1], -100, 100)),
        .ambient_xy_angle = game.state.environment.ambientXYAngle(),
        .ambient_z_angle = game.state.environment.ambientZAngle(),
        .shadow_color = .{ shadow_color[0], shadow_color[1], shadow_color[2] },
        .shadow_steps = 150,
    };

    game.state.batcher.begin(.{
        .pipeline_handle = game.state.pipeline_environment,
        .bind_group_handle = game.state.bind_group_environment,
        .output_handle = game.state.environment_output.view_handle,
        .clear_color = game.math.Colors.white.value,
    }) catch unreachable;

    const position = zm.f32x4(-@intToFloat(f32, game.state.environment_output.width) / 2, -@intToFloat(f32, game.state.environment_output.height) / 2, 0, 0);

    game.state.batcher.texture(position, game.state.environment_output, .{ .color = game.state.environment.ambientColor().value }) catch unreachable;

    game.state.batcher.end(uniforms) catch unreachable;
}
