const std = @import("std");
const zm = @import("zmath");
const game = @import("game");
const components = game.components;
const flecs = @import("flecs");

const Prefabs = @This();

item: flecs.EcsEntity = 0,
stackable: flecs.EcsEntity = 0,
ham: flecs.EcsEntity = 0,

pub fn init(world: *flecs.EcsWorld) Prefabs {
    var prefabs: Prefabs = .{};

    prefabs.item = flecs.ecs_new_prefab(world, "item");
    flecs.ecs_add(world, prefabs.item, components.Position);
    flecs.ecs_override(world, prefabs.item, components.Position);
    flecs.ecs_add(world, prefabs.item, components.Tile);
    flecs.ecs_override(world, prefabs.item, components.Tile);
    flecs.ecs_add(world, prefabs.item, components.Moveable);
    flecs.ecs_add(world, prefabs.item, components.SpriteRenderer);
    flecs.ecs_override(world, prefabs.item, components.SpriteRenderer);

    prefabs.stackable = flecs.ecs_new_prefab(world, "stackable");
    flecs.ecs_add_pair(world, prefabs.stackable, flecs.Constants.EcsIsA, prefabs.item);
    flecs.ecs_set(world, prefabs.stackable, &components.Stack{ .max = 100 });
    flecs.ecs_override(world, prefabs.stackable, components.Stack);

    prefabs.ham = flecs.ecs_new_prefab(world, "ham");
    flecs.ecs_add_pair(world, prefabs.ham, flecs.Constants.EcsIsA, prefabs.stackable);
    flecs.ecs_set(world, prefabs.ham, &components.Stack{ .max = 5 });
    flecs.ecs_set(world, prefabs.ham, &components.StackAnimator{
        .animation = &game.animations.Ham_Layer,
        .counts = &[_]usize{ 1, 2, 3, 4, 5 },
    });
    flecs.ecs_set(world, prefabs.ham, &components.SpriteRenderer{
        .index = game.assets.aftersun_atlas.Ham_0_Layer,
    });

    return prefabs;
}
