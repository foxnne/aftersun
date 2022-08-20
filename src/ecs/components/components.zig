const std = @import("std");
const game = @import("game");
const flecs = @import("flecs");

const sprites = @import("sprites.zig");
const characters = @import("characters.zig");

pub usingnamespace sprites;
pub usingnamespace characters;

const This = @This();

pub fn register(world: *flecs.EcsWorld) void {
    const decls = @typeInfo(This).Struct.decls;
    inline for (decls) |decl| {
        if (decl.is_pub) {
            const T = @field(This, decl.name);
            if (@TypeOf(T) == type)
                flecs.ecs_component(world, T);
        }
    }
}

pub const Visible = struct {};

pub const Position = struct { x: f32 = 0, y: f32 = 0, z: f32 = 0 };
pub const Tile = struct { x: i32 = 0, y: i32 = 0, z: i32 = 0, counter: u64 = 0 };
pub const Direction = struct { value: game.math.Direction = .none };
pub const Rotation = struct { value: f32 = 0 };

pub const Request = struct {};
pub const Cooldown = struct { current: f32 = -1.0, end: f32 = 0.0 };
pub const Movement = struct { start: Tile, end: Tile };

pub const Camera = struct {};
pub const Target = struct {};
