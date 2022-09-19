const std = @import("std");
const zm = @import("zmath");
const game = @import("game");
const components = game.components;
const flecs = @import("flecs");

const Prefabs = @This();

_item: flecs.EcsEntity = 0,
_stackable: flecs.EcsEntity = 0,
apple: flecs.EcsEntity = 0,
cooked_ham: flecs.EcsEntity = 0,
ham: flecs.EcsEntity = 0,
torch: flecs.EcsEntity = 0,

pub const id_start: u64 = 6000;

pub fn init() Prefabs {
    comptime {
        var prefabs: Prefabs = .{};
        const fields = std.meta.fieldNames(Prefabs);
        inline for (fields) |field_name, i| {
            @field(prefabs, field_name) = id_start + @as(u64, i);
        }
        return prefabs;
    }
}

pub fn create(prefabs: *Prefabs, world: *flecs.EcsWorld) void {
    flecs.ecs_add_id(world, prefabs._item, flecs.Constants.EcsPrefab);
    flecs.ecs_add(world, prefabs._item, components.Position);
    flecs.ecs_override(world, prefabs._item, components.Position);
    flecs.ecs_add(world, prefabs._item, components.Tile);
    flecs.ecs_override(world, prefabs._item, components.Tile);
    flecs.ecs_add(world, prefabs._item, components.Moveable);
    flecs.ecs_add(world, prefabs._item, components.SpriteRenderer);
    flecs.ecs_override(world, prefabs._item, components.SpriteRenderer);

    flecs.ecs_add_id(world, prefabs._stackable, flecs.Constants.EcsPrefab);
    flecs.ecs_add_pair(world, prefabs._stackable, flecs.Constants.EcsIsA, prefabs._item);
    flecs.ecs_set(world, prefabs._stackable, &components.Stack{ .max = 100 });
    flecs.ecs_override(world, prefabs._stackable, components.Stack);

    flecs.ecs_add_id(world, prefabs.ham, flecs.Constants.EcsPrefab);
    flecs.ecs_add_pair(world, prefabs.ham, flecs.Constants.EcsIsA, prefabs._stackable);
    flecs.ecs_set(world, prefabs.ham, &components.Stack{ .max = 5 });
    flecs.ecs_set(world, prefabs.ham, &components.StackAnimator{
        .animation = &game.animations.Ham_Layer,
        .counts = &[_]usize{ 1, 2, 3, 4, 5 },
    });
    flecs.ecs_set(world, prefabs.ham, &components.SpriteRenderer{
        .index = game.assets.aftersun_atlas.Ham_0_Layer,
    });

    flecs.ecs_add_id(world, prefabs.cooked_ham, flecs.Constants.EcsPrefab);
    flecs.ecs_add_pair(world, prefabs.cooked_ham, flecs.Constants.EcsIsA, prefabs._stackable);
    flecs.ecs_set(world, prefabs.cooked_ham, &components.Stack{ .max = 5 });
    flecs.ecs_set(world, prefabs.cooked_ham, &components.StackAnimator{
        .animation = &game.animations.Cooked_Ham_Layer,
        .counts = &[_]usize{ 1, 2, 3, 4, 5 },
    });
    flecs.ecs_set(world, prefabs.cooked_ham, &components.SpriteRenderer{
        .index = game.assets.aftersun_atlas.Cooked_Ham_0_Layer,
    });

    flecs.ecs_add_id(world, prefabs.apple, flecs.Constants.EcsPrefab);
    flecs.ecs_add_pair(world, prefabs.apple, flecs.Constants.EcsIsA, prefabs._stackable);
    flecs.ecs_set(world, prefabs.apple, &components.Stack{ .max = 5 });
    flecs.ecs_set(world, prefabs.apple, &components.StackAnimator{
        .animation = &game.animations.Apple_Layer,
        .counts = &[_]usize{ 1, 2, 3, 4, 5 },
    });
    flecs.ecs_set(world, prefabs.apple, &components.SpriteRenderer{
        .index = game.assets.aftersun_atlas.Apple_0_Layer,
    });

    flecs.ecs_add_id(world, prefabs.torch, flecs.Constants.EcsPrefab);
    flecs.ecs_add_pair(world, prefabs.torch, flecs.Constants.EcsIsA, prefabs._item);
    flecs.ecs_set(world, prefabs.torch, &components.SpriteAnimator{
        .animation = &game.animations.Torch_Flame_Layer,
        .state = .play,
        .fps = 16,
    });
    flecs.ecs_set(world, prefabs.torch, &components.SpriteRenderer{
        .index = game.assets.aftersun_atlas.Torch_Flame_0_Layer,
    });
    flecs.ecs_override(world, prefabs.torch, components.SpriteAnimator);
}
