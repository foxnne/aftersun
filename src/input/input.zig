const std = @import("std");
const zm = @import("zmath");
const glfw = @import("glfw");
const math = @import("../math/math.zig");
const game = @import("game");

pub const callbacks = @import("callbacks.zig");

pub const Controls = struct {
    mouse: Mouse = .{},

    keys: [4]Key = [_]Key{
        .{
            .name = "MovementUp",
            .primary = glfw.Key.w,
            .secondary = glfw.Key.up,
            .default_primary = glfw.Key.w,
            .default_secondary = glfw.Key.up,
        },
        .{
            .name = "MovementDown",
            .primary = glfw.Key.s,
            .secondary = glfw.Key.down,
            .default_primary = glfw.Key.s,
            .default_secondary = glfw.Key.down,
        },
        .{
            .name = "MovementRight",
            .primary = glfw.Key.d,
            .secondary = glfw.Key.right,
            .default_primary = glfw.Key.d,
            .default_secondary = glfw.Key.right,
        },
        .{
            .name = "MovementLeft",
            .primary = glfw.Key.a,
            .secondary = glfw.Key.left,
            .default_primary = glfw.Key.a,
            .default_secondary = glfw.Key.left,
        },
    },

    pub fn movement (self: Controls) Directional {
        return .{
            .name = "Movement",
            .keys = self.keys[0..4],
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
    pub fn pressed (self: MouseButton) bool {
        return self.state == true and self.state != self.previous_state;
    }

    /// Returns true while the key is pressed down.
    pub fn down (self: MouseButton) bool {
        return self.state == true;
    }

    /// Returns true the frame the key was released.
    pub fn released (self: MouseButton) bool {
        return self.state == false and self.state != self.previous_state;
    }

    /// Returns true while the key is released.
    pub fn up (self: MouseButton) bool {
        return self.state == false;
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
    pub fn pressed (self: MouseButton) bool {
        return self.state == true and self.state != self.previous_state;
    }

    /// Returns true while the mouse button is pressed down.
    pub fn down (self: MouseButton) bool {
        return self.state == true;
    }

    /// Returns true the frame the mouse button was released.
    pub fn released (self: MouseButton) bool {
        return self.state == false and self.state != self.previous_state;
    }

    /// Returns true while the mouse button is released.
    pub fn up (self: MouseButton) bool {
        return self.state == false;
    }
};

pub const Mouse = struct {
    primary: MouseButton = .{ .name = "Primary", .button = glfw.MouseButton.left },
    secondary: MouseButton = .{ .name = "Secondary", .button = glfw.MouseButton.right },
    scroll: Scroll = .{},
    position: Position = .{},

    pub const Position = struct {
        x: f32 = 0.0,
        y: f32 = 0.0,

        /// Returns the screen position.
        pub fn screen (self:Position) zm.F32x4 {
            return zm.f32x4(self.x, self.y, 0, 0);
        }

        /// Returns the world position.
        pub fn world (self:Position) zm.F32x4 {
            const fb = game.state.camera.frameBufferMatrix();
            const position = self.screen();
            return game.state.camera.screenToWorld(position, fb);
        }
    };

    pub const Scroll = struct {
        x: f32 = 0.0,
        y: f32 = 0.0,

        pub fn up (self: Scroll) bool {
            return self.y > 0;
        }

        pub fn down (self: Scroll) bool {
            return self.y < 0;
        }
    };
};
