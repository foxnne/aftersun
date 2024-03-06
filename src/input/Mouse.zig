const std = @import("std");
const zmath = @import("zmath");
const math = @import("../math/math.zig");
const game = @import("../aftersun.zig");
const core = @import("mach").core;

const ecs = @import("zflecs");

const builtin = @import("builtin");

const Mods = core.KeyMods;
const MouseButton = core.MouseButton;

const Self = @This();

pub const ButtonState = enum {
    press,
    release,
};

pub const Button = struct {
    button: MouseButton,
    mods: ?Mods = null,
    action: Action,
    state: bool = false,
    previous_state: bool = false,
    pressed_tile: [2]i32 = .{ 0, 0 },
    released_tile: [2]i32 = .{ 0, 0 },
    pressed_mods: Mods = std.mem.zeroes(Mods),
    released_mods: Mods = std.mem.zeroes(Mods),

    /// Returns true the frame the key was pressed.
    pub fn pressed(self: Button) bool {
        return (self.state == true and self.state != self.previous_state);
    }

    /// Returns true while the key is pressed down.
    pub fn down(self: Button) bool {
        return self.state == true;
    }

    /// Returns true the frame the key was released.
    pub fn released(self: Button) bool {
        return (self.state == false and self.state != self.previous_state);
    }

    /// Returns true while the key is released.
    pub fn up(self: Button) bool {
        return self.state == false;
    }
};

pub const Action = enum {
    primary,
    secondary,
};

buttons: []Button,
position: [2]f32 = .{ 0.0, 0.0 },
previous_position: [2]f32 = .{ 0.0, 0.0 },
scroll_x: ?f32 = null,
scroll_y: ?f32 = null,

pub fn button(self: *Self, action: Action) ?*Button {
    for (self.buttons) |*bt| {
        if (bt.action == action)
            return bt;
    }
    return null;
}

pub fn setButtonState(self: *Self, b: MouseButton, mods: Mods, state: ButtonState) void {
    for (self.buttons) |*bt| {
        if (bt.button == b) {
            const world_position = game.state.camera.screenToWorld(zmath.f32x4(self.position[0], self.position[1], 0, 0));
            if (state == .release or bt.mods == null) {
                bt.previous_state = bt.state;
                switch (state) {
                    .press => {
                        bt.state = true;
                        bt.pressed_mods = mods;
                        bt.pressed_tile[0] = game.math.tile(world_position[0]);
                        bt.pressed_tile[1] = game.math.tile(world_position[1]);
                    },
                    else => {
                        bt.state = false;
                        bt.released_mods = mods;
                        bt.released_tile[0] = game.math.tile(world_position[0]);
                        bt.released_tile[1] = game.math.tile(world_position[1]);
                    },
                }
            } else if (bt.mods) |md| {
                if (@as(u8, @bitCast(md)) == @as(u8, @bitCast(mods))) {
                    bt.previous_state = bt.state;
                    switch (state) {
                        .press => {
                            bt.state = true;
                            bt.pressed_mods = mods;
                            bt.pressed_tile[0] = game.math.tile(world_position[0]);
                            bt.pressed_tile[1] = game.math.tile(world_position[1]);
                        },
                        else => {
                            bt.state = false;
                            bt.released_mods = mods;
                            bt.released_tile[0] = game.math.tile(world_position[0]);
                            bt.released_tile[1] = game.math.tile(world_position[1]);
                        },
                    }
                }
            }
        }
    }
}

pub fn setScrollState(self: *Self, x: f32, y: f32) void {
    self.scroll_x = x;
    self.scroll_y = y;

    if (y > game.settings.zoom_scroll_tolerance and game.state.camera.zoom_progress < 0.0) {
        const max_zoom = game.gfx.Camera.maxZoom();
        game.state.camera.zoom_step = @round(game.state.camera.zoom);
        if (game.state.camera.zoom_step + 1.0 <= max_zoom) {
            game.state.camera.zoom_progress = 0.0;
            game.state.camera.zoom_step_next = game.state.camera.zoom_step + 1.0;
        }
    }
    if (y < -game.settings.zoom_scroll_tolerance and game.state.camera.zoom_progress < 0.0) {
        const min_zoom = game.gfx.Camera.minZoom();
        game.state.camera.zoom_step = @round(game.state.camera.zoom);
        if (game.state.camera.zoom_step - 1.0 >= min_zoom) {
            game.state.camera.zoom_progress = 0.0;
            game.state.camera.zoom_step_next = game.state.camera.zoom_step - 1.0;
        }
    }
}

pub fn initDefault(allocator: std.mem.Allocator) !Self {
    var buttons = std.ArrayList(Button).init(allocator);

    {
        try buttons.append(.{
            .button = MouseButton.left,
            .action = Action.primary,
        });

        try buttons.append(.{
            .button = MouseButton.right,
            .action = Action.secondary,
        });
    }

    return .{ .buttons = try buttons.toOwnedSlice() };
}
