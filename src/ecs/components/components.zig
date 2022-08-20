const std = @import("std");
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

pub const Position = struct { x: f32 = 0, y: f32 = 0, z: f32 = 0 };
pub const Tile = struct { x: i32 = 0, y: i32 = 0, z: i32 = 0, counter: u64 = 0 };
pub const Direction = struct { value: game.math.Direction = .none };
pub const Rotation = struct { value: f32 = 0 };

pub const Request = struct {};
pub const Cooldown = struct { current: f32 = -1.0, end: f32 = 0.0 };
pub const Movement = struct { start: Tile, end: Tile };

pub const Camera = struct {};
pub const Target = struct {};
