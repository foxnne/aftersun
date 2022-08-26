const std = @import("std");
const zm = @import("zmath");
const game = @import("game");
const flecs = @import("flecs");

const sprites = @import("sprites.zig");
const characters = @import("characters.zig");

pub const SpriteRenderer = sprites.SpriteRenderer;
pub const SpriteAnimator = sprites.SpriteAnimator;

pub const CharacterRenderer = characters.CharacterRenderer;
pub const CharacterAnimator = characters.CharacterAnimator;

pub const Visible = struct {};
pub const Player = struct {};
pub const Head = struct {};
pub const Body = struct {};

pub const Position = struct {
    x: f32 = 0,
    y: f32 = 0,
    z: f32 = 0,

    /// Converts the position to a tile coordinates.
    pub fn toTile(self: Position, counter: u64) Tile {
        return .{
            .x = game.math.tile(self.x),
            .y = game.math.tile(self.y),
            .z = game.math.tile(self.z),
            .counter = counter,
        };
    }

    /// Returns the position as a vector.
    pub fn toF32x4 (self: Position) zm.F32x4 {
        return zm.f32x4(self.x, self.y, self.z, 0.0);
    }
};

pub const Tile = struct {
    x: i32 = 0,
    y: i32 = 0,
    z: i32 = 0,
    counter: u64 = 0,

    /// Converts the tile to pixel coordinates.
    pub fn toPosition(self: Tile) Position {
        return .{
            .x = game.math.pixel(self.x),
            .y = game.math.pixel(self.y),
            .z = game.math.pixel(self.z),
        };
    }
};

pub const Direction = struct { value: game.math.Direction = .none };
pub const Rotation = struct { value: f32 = 0 };

pub const Request = struct {};
pub const Cooldown = struct { current: f32 = -1.0, end: f32 = 0.0 };
pub const Movement = struct { start: Tile, end: Tile };

pub const Camera = struct {};
pub const Target = struct {};
