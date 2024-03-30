const std = @import("std");
const zmath = @import("zmath");
const ecs = @import("zflecs");
const game = @import("../../aftersun.zig");
const components = game.components;

const imgui = @import("zig-imgui");

pub fn system() ecs.system_desc_t {
    var desc: ecs.system_desc_t = .{};
    desc.run = run;
    return desc;
}

pub fn run(it: *ecs.iter_t) callconv(.C) void {
    const scaled_size: [2]f32 = .{ game.settings.design_width * game.state.camera.zoom, game.settings.design_height * game.state.camera.zoom };
    const size_diff: [2]f32 = .{ @abs(scaled_size[0] - game.window_size[0]), @abs(scaled_size[1] - game.window_size[1]) };
    const offset: [2]f32 = .{ size_diff[0] / scaled_size[0] / 2.0, size_diff[1] / scaled_size[1] / 2.0 };

    const remaining: [2]f32 = .{ 1.0 - offset[0] * 2.0, 1.0 - offset[1] * 2.0 };

    const mouse_x: f32 = game.math.lerp(offset[0], offset[0] + remaining[0], game.state.mouse.position[0] / game.window_size[0]);
    const mouse_y: f32 = game.math.lerp(offset[1], offset[1] + remaining[1], game.state.mouse.position[1] / game.window_size[1]);

    game.state.scanner_position[0] = mouse_x;
    game.state.scanner_position[1] = mouse_y;

    if (game.state.scanner_state) {
        if (game.state.scanner_time < 1.0) {
            game.state.scanner_time = @min(1.0, game.state.scanner_time + it.delta_time);
        } else {
            //game.state.scanner_time = 0.0;
        }
    } else {
        if (game.state.scanner_time > 0.0)
            game.state.scanner_time = @max(0.0, game.state.scanner_time - it.delta_time);
    }
}
