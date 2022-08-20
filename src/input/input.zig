const std = @import("std");
const zm = @import("zmath");
const glfw = @import("glfw");
const math = @import("../math/math.zig");
const game = @import("game");

pub const Controls = struct {
    mouse: Mouse = .{},

    // Controls
    movement: Directional = .{
        .name = "Movement",
        .horizontal = .{
            .name = "Horizontal",
            .positive = .{
                .name = "Right",
                .primary = glfw.Key.d,
                .secondary = glfw.Key.right,
                .default_primary = glfw.Key.d,
                .default_secondary = glfw.Key.right,
            },
            .negative = .{
                .name = "Left",
                .primary = glfw.Key.a,
                .secondary = glfw.Key.left,
                .default_primary = glfw.Key.a,
                .default_secondary = glfw.Key.left,
            },
        },
        .vertical = .{
            .name = "Vertical",
            .positive = .{
                .name = "Up",
                .primary = glfw.Key.w,
                .secondary = glfw.Key.up,
                .default_primary = glfw.Key.w,
                .default_secondary = glfw.Key.up,
            },
            .negative = .{
                .name = "Down",
                .primary = glfw.Key.s,
                .secondary = glfw.Key.down,
                .default_primary = glfw.Key.s,
                .default_secondary = glfw.Key.down,
            },
        },
    },
};

pub const Key = struct {
    name: [:0]const u8,
    primary: glfw.Key = glfw.Key.unknown,
    secondary: glfw.Key = glfw.Key.unknown,
    default_primary: glfw.Key = glfw.Key.unknown,
    default_secondary: glfw.Key = glfw.Key.unknown,

    /// Returns true if the key's primary or secondary bindings are pressed.
    pub fn pressed(key: Key) bool {
        const primary = if (key.primary != glfw.Key.unknown) switch (game.state.gctx.window.getKey(key.primary)) {
            .press => true,
            else => false,
        } else false;
        const secondary = if (key.secondary != glfw.Key.unknown) switch (game.state.gctx.window.getKey(key.secondary)) {
            .press => true,
            else => false,
        } else false;

        return primary or secondary;
    }
};

pub const Axis = struct {
    name: [:0]const u8,
    positive: Key = .{ .name = "Positive" },
    negative: Key = .{ .name = "Negative" },
};

pub const Directional = struct {
    name: [:0]const u8,
    horizontal: Axis = .{ .name = "Horizontal" },
    vertical: Axis = .{ .name = "Vertical" },

    /// Returns the current direction of a directional control.
    pub fn direction(directional: Directional) math.Direction {
        return math.Direction.write(
            directional.vertical.positive.pressed(),
            directional.vertical.negative.pressed(),
            directional.horizontal.positive.pressed(),
            directional.horizontal.negative.pressed(),
        );
    }
};

pub const MouseButton = struct {
    name: [:0]const u8,
    button: glfw.MouseButton,

    pub fn pressed(self: MouseButton) bool {
        return game.state.window.getMouseButton(self.button) == .press;
    }
};

pub const Mouse = struct {
    primary: MouseButton = .{ .name = "Primary", .button = glfw.MouseButton.left },
    secondary: MouseButton = .{ .name = "Secondary", .button = glfw.MouseButton.right },

    pub const Position = struct {
        x: f32 = 0,
        y: f32 = 0,
    };

    pub fn position(self: Mouse) Position {
        _ = self;
        const pos = game.state.gctx.window.getCursorPos() catch unreachable;
        return .{ .x = @floatCast(f32, pos.xpos), .y = @floatCast(f32, pos.ypos) };
    }
};
