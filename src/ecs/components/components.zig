const std = @import("std");
const zmath = @import("zmath");
const game = @import("../../aftersun.zig");
const ecs = @import("zflecs");

const sprites = @import("sprites.zig");
const characters = @import("characters.zig");
const stacks = @import("stacks.zig");
const particles = @import("particles.zig");
const lights = @import("lights.zig");

/// Registers all public declarations.
pub fn register(world: *ecs.world_t) void {
    const T = @This();
    const decls = comptime std.meta.declarations(T);
    inline for (decls) |decl| {
        const Type = @field(T, decl.name);
        if (@TypeOf(Type) == type) {
            if (@sizeOf(Type) > 0) {
                ecs.COMPONENT(world, Type);
            } else ecs.TAG(world, Type);
        }
    }
}

pub const SpriteRenderer = sprites.SpriteRenderer;
pub const SpriteAnimator = sprites.SpriteAnimator;

pub const CharacterRenderer = characters.CharacterRenderer;
pub const CharacterAnimator = characters.CharacterAnimator;

pub const Stack = stacks.Stack;
pub const StackAnimator = stacks.StackAnimator;

pub const ParticleRenderer = particles.ParticleRenderer;
pub const ParticleAnimator = particles.ParticleAnimator;

pub const LightRenderer = lights.LightRenderer;

pub const Visible = struct {};
pub const Player = struct {};
pub const Head = struct {};
pub const Body = struct {};

pub const Position = struct {
    x: f32 = 0.0,
    y: f32 = 0.0,
    z: f32 = 0.0,

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
    pub fn toF32x4(self: Position) zmath.F32x4 {
        return zmath.f32x4(self.x, self.y, self.z, 0.0);
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

    pub fn toCell(self: Tile) Cell {
        return .{
            .x = @divFloor(self.x, game.settings.cell_size),
            .y = @divFloor(self.y, game.settings.cell_size),
            .z = @divFloor(self.z, game.settings.cell_size),
        };
    }
};

pub const MapTile = enum(u8) {
    ground,
    water,
};

pub const EmptyTile = struct {};

pub const Collider = struct {
    trigger: bool = false,
};

pub const Cell = struct {
    x: i32 = 0,
    y: i32 = 0,
    z: i32 = 0,

    pub fn getAllSurrounding(self: Cell) [9]Cell {
        return .{
            self,
            .{ .x = self.x, .y = self.y + 1, .z = self.z },
            .{ .x = self.x + 1, .y = self.y + 1, .z = self.z },
            .{ .x = self.x + 1, .y = self.y, .z = self.z },
            .{ .x = self.x + 1, .y = self.y - 1, .z = self.z },
            .{ .x = self.x, .y = self.y - 1, .z = self.z },
            .{ .x = self.x - 1, .y = self.y - 1, .z = self.z },
            .{ .x = self.x - 1, .y = self.y, .z = self.z },
            .{ .x = self.x - 1, .y = self.y + 1, .z = self.z },
        };
    }
};

/// Values ramp up from 0.0 to 1.0 when movement starts and back down when movement stops.
/// Do not use velocity direction to determine when something stops as it will continue past the moment of stopping.
pub const Inertia = struct {
    x: f32 = 0.0,
    y: f32 = 0.0,

    pub fn direction(self: Inertia) game.math.Direction {
        return game.math.Direction.find(8, self.x, self.y);
    }

    pub fn toF32x4(self: Inertia) zmath.F32x4 {
        return zmath.f32x4(self.x, self.y, 0.0, 0.0);
    }
};

pub const Direction = game.math.Direction;
pub const Rotation = struct { value: f32 = 0 };

pub const Request = struct {};
pub const RequestZeroOther = struct { target: ecs.entity_t };
pub const Cooldown = struct { current: f32 = 0.0, end: f32 = 1.0 };
pub const Movement = struct {
    start: Tile,
    end: Tile,
    curve: Curve = .linear,

    pub const Curve = enum {
        linear,
        sin,
    };
};
pub const Drag = struct {
    start: Tile,
    end: Tile,
    modifier: Modifier = .all,

    pub const Modifier = enum { all, half, one };
};
pub const Moveable = struct {};

pub const Camera = struct {};
pub const Target = struct {};

pub const Useable = struct {};
pub const Toggleable = struct { state: bool = false, on_prefab: ecs.entity_t, off_prefab: ecs.entity_t };
pub const Use = struct { target: Tile };
pub const Consumeable = struct {};
pub const Raw = struct { cooked_prefab: ecs.entity_t };
pub const Cook = struct {};

pub const Trigger = struct {};
