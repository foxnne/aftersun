const std = @import("std");
const zm = @import("zmath");
const glfw = @import("glfw");
const math = @import("../math/math.zig");
const game = @import("game");

pub const callbacks = @import("callbacks.zig");

pub const Controls = struct {
    mouse: Mouse = .{},

    keys: [6]Key = [_]Key{
        .{
            .name = "Movement - Up",
            .primary = glfw.Key.w,
            .secondary = glfw.Key.up,
            .default_primary = glfw.Key.w,
            .default_secondary = glfw.Key.up,
        },
        .{
            .name = "Movement - Down",
            .primary = glfw.Key.s,
            .secondary = glfw.Key.down,
            .default_primary = glfw.Key.s,
            .default_secondary = glfw.Key.down,
        },
        .{
            .name = "Movement - Right",
            .primary = glfw.Key.d,
            .secondary = glfw.Key.right,
            .default_primary = glfw.Key.d,
            .default_secondary = glfw.Key.right,
        },
        .{
            .name = "Movement - Left",
            .primary = glfw.Key.a,
            .secondary = glfw.Key.left,
            .default_primary = glfw.Key.a,
            .default_secondary = glfw.Key.left,
        },
        .{
            .name = "Camera - Zoom In",
            .primary = glfw.Key.equal,
            .secondary = glfw.Key.unknown,
            .default_primary = glfw.Key.equal,
            .default_secondary = glfw.Key.unknown,
        },
        .{
            .name = "Camera - Zoom Out",
            .primary = glfw.Key.minus,
            .secondary = glfw.Key.unknown,
            .default_primary = glfw.Key.minus,
            .default_secondary = glfw.Key.unknown,
        },
    },

    pub fn movement(self: Controls) Directional {
        return .{
            .name = "Movement",
            .keys = self.keys[0..4],
        };
    }

    pub fn zoom(self: Controls) Axis {
        return .{
            .name = "Zoom",
            .keys = self.keys[4..6],
        };
    }
};

pub const Key = struct {
    name: [:0]const u8,
    primary: glfw.Key = glfw.Key.unknown,
    secondary: glfw.Key = glfw.Key.unknown,
    default_primary: glfw.Key = glfw.Key.unknown,
    default_secondary: glfw.Key = glfw.Key.unknown,
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

pub const Axis = struct {
    name: [:0]const u8,
    keys: []const Key,

    pub fn state(self: Axis) f32 {
        return if (self.keys[0].state) 1.0 else if (self.keys[1].state) -1.0 else 0.0;
    }
};

pub const Directional = struct {
    name: [:0]const u8,
    keys: []const Key,

    /// Returns the current direction of a directional control.
    pub fn direction(self: Directional) math.Direction {
        return math.Direction.write(
            self.keys[0].state,
            self.keys[1].state,
            self.keys[2].state,
            self.keys[3].state,
        );
    }
};

pub const MouseButton = struct {
    name: [:0]const u8,
    button: glfw.MouseButton,
    state: bool = false,
    previous_state: bool = false,

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

pub const Mouse = struct {
    primary: MouseButton = .{ .name = "Primary", .button = glfw.MouseButton.left },
    secondary: MouseButton = .{ .name = "Secondary", .button = glfw.MouseButton.right },
    position: Position = .{},
    previous_position: Position = .{},

    pub const Position = struct {
        x: f32 = 0.0,
        y: f32 = 0.0,

        /// Returns the screen position.
        pub fn screen(self: Position) zm.F32x4 {
            return zm.f32x4(self.x, self.y, 0, 0);
        }

        /// Returns the world position.
        pub fn world(self: Position) zm.F32x4 {
            const fb = game.state.camera.frameBufferMatrix();
            const position = self.screen();
            return game.state.camera.screenToWorld(position, fb);
        }
    };
};
