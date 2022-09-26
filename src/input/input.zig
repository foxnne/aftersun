const std = @import("std");
const zm = @import("zmath");
const zglfw = @import("zglfw");
const math = @import("../math/math.zig");
const game = @import("game");
const components = game.components;

pub const callbacks = @import("callbacks.zig");

pub const Keys = enum(usize) {
    up,
    down,
    right,
    left,
    zoom_in,
    zoom_out,
    inspect,
    toggle_inspect,
};

pub const Controls = struct {
    mouse: Mouse = .{},
    inspecting: bool = false,

    /// Holds all rebindable keys.
    keys: [8]Key = [_]Key{
        .{
            .name = "Movement - Up",
            .primary = zglfw.Key.w,
            .secondary = zglfw.Key.up,
            .default_primary = zglfw.Key.w,
            .default_secondary = zglfw.Key.up,
        },
        .{
            .name = "Movement - Down",
            .primary = zglfw.Key.s,
            .secondary = zglfw.Key.down,
            .default_primary = zglfw.Key.s,
            .default_secondary = zglfw.Key.down,
        },
        .{
            .name = "Movement - Right",
            .primary = zglfw.Key.d,
            .secondary = zglfw.Key.right,
            .default_primary = zglfw.Key.d,
            .default_secondary = zglfw.Key.right,
        },
        .{
            .name = "Movement - Left",
            .primary = zglfw.Key.a,
            .secondary = zglfw.Key.left,
            .default_primary = zglfw.Key.a,
            .default_secondary = zglfw.Key.left,
        },
        .{
            .name = "Camera - Zoom In",
            .primary = zglfw.Key.equal,
            .secondary = zglfw.Key.unknown,
            .default_primary = zglfw.Key.equal,
            .default_secondary = zglfw.Key.unknown,
        },
        .{
            .name = "Camera - Zoom Out",
            .primary = zglfw.Key.minus,
            .secondary = zglfw.Key.unknown,
            .default_primary = zglfw.Key.minus,
            .default_secondary = zglfw.Key.unknown,
        },
        .{
            .name = "Inspect",
            .primary = zglfw.Key.left_shift,
            .secondary = zglfw.Key.right_shift,
            .default_primary = zglfw.Key.left_shift,
            .default_secondary = zglfw.Key.right_shift,
        },
        .{
            .name = "Toggle Inspect",
            .primary = zglfw.Key.tab,
            .secondary = zglfw.Key.unknown,
            .default_primary = zglfw.Key.tab,
            .default_secondary = zglfw.Key.unknown,
        }
    },

    /// Returns the current direction of the movement keys.
    pub fn movement(self: Controls) game.math.Direction {
        return game.math.Direction.write(
            self.keys[@enumToInt(Keys.up)].state,
            self.keys[@enumToInt(Keys.down)].state,
            self.keys[@enumToInt(Keys.right)].state,
            self.keys[@enumToInt(Keys.left)].state,
        );
    }

    /// Returns the current axis state of the zoom keys.
    pub fn zoom(self: Controls) f32 {
        return if (self.keys[@enumToInt(Keys.zoom_in)].state) 1.0 else if (self.keys[@enumToInt(Keys.zoom_out)].state) -1.0 else 0.0;
    }

    /// Returns the current state of the inspect key.
    pub fn inspect(self: Controls) bool {
        return self.keys[@enumToInt(Keys.inspect)].state;
    }
};

pub const Key = struct {
    name: [:0]const u8,
    primary: zglfw.Key = zglfw.Key.unknown,
    secondary: zglfw.Key = zglfw.Key.unknown,
    default_primary: zglfw.Key = zglfw.Key.unknown,
    default_secondary: zglfw.Key = zglfw.Key.unknown,
    state: bool = false,
    previous_state: bool = false,

    /// Returns true the frame the key was pressed.
    pub fn pressed(self: MouseButton) bool {
        return self.state == true and self.state != self.previous_state;
    }

    /// Returns true while the key is pressed down.
    pub fn down(self: MouseButton) bool {
        return self.state == true;
    }

    /// Returns true the frame the key was released.
    pub fn released(self: MouseButton) bool {
        return self.state == false and self.state != self.previous_state;
    }

    /// Returns true while the key is released.
    pub fn up(self: MouseButton) bool {
        return self.state == false;
    }
};

pub const MouseButton = struct {
    name: [:0]const u8,
    button: zglfw.MouseButton,
    state: bool = false,
    previous_state: bool = false,
    down_tile: ?components.Tile = null,
    up_tile: ?components.Tile = null,

    /// Returns true the frame the mouse button was pressed.
    pub fn pressed(self: MouseButton) bool {
        return self.state == true and self.state != self.previous_state;
    }

    /// Returns true while the mouse button is pressed down.
    pub fn down(self: MouseButton) bool {
        return self.state == true;
    }

    /// Returns true the frame the mouse button was released.
    pub fn released(self: MouseButton) bool {
        return self.state == false and self.state != self.previous_state;
    }

    /// Returns true while the mouse button is released.
    pub fn up(self: MouseButton) bool {
        return self.state == false;
    }
};

pub const MousePosition = struct {
    x: f32 = 0.0,
    y: f32 = 0.0,

    /// Returns the screen position.
    pub fn screen(self: MousePosition) zm.F32x4 {
        return zm.f32x4(self.x, self.y, 0, 0);
    }

    /// Returns the world position.
    pub fn world(self: MousePosition) zm.F32x4 {
        const fb = game.state.camera.frameBufferMatrix();
        const position = self.screen();
        return game.state.camera.screenToWorld(position, fb);
    }

    /// Returns the world position as a Tile component.
    pub fn tile(self: MousePosition) components.Tile {
        const world_position = self.world();
        return .{
            .x = game.math.tile(world_position[0]),
            .y = game.math.tile(world_position[1]),
        };
    }
};

pub const MouseCursor = enum {
    standard,
    drag,
};

pub const Mouse = struct {
    primary: MouseButton = .{ .name = "Primary", .button = zglfw.MouseButton.left },
    secondary: MouseButton = .{ .name = "Secondary", .button = zglfw.MouseButton.right },
    position: MousePosition = .{},
    tile: components.Tile = .{},
    tile_timer: f32 = 0.0,
    cursor: MouseCursor = .standard,
};
