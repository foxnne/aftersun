const std = @import("std");
const zm = @import("zmath");
const game = @import("game");
const components = game.components;
const flecs = @import("flecs");

const Prefabs = @This();

_item: flecs.EcsEntity = 0,
_stackable: flecs.EcsEntity = 0,
ham: flecs.EcsEntity = 0,
apple: flecs.EcsEntity = 0,

pub fn init(world: *flecs.EcsWorld) Prefabs {
    var prefabs: Prefabs = .{};

    prefabs._item = flecs.ecs_new_prefab(world, "item");
    flecs.ecs_add(world, prefabs._item, components.Position);
    flecs.ecs_override(world, prefabs._item, components.Position);
    flecs.ecs_add(world, prefabs._item, components.Tile);
    flecs.ecs_override(world, prefabs._item, components.Tile);
    flecs.ecs_add(world, prefabs._item, components.Moveable);
    flecs.ecs_add(world, prefabs._item, components.SpriteRenderer);
    flecs.ecs_override(world, prefabs._item, components.SpriteRenderer);

    prefabs._stackable = flecs.ecs_new_prefab(world, "stackable");
    flecs.ecs_add_pair(world, prefabs._stackable, flecs.Constants.EcsIsA, prefabs._item);
    flecs.ecs_set(world, prefabs._stackable, &components.Stack{ .max = 100 });
    flecs.ecs_override(world, prefabs._stackable, components.Stack);

    prefabs.ham = flecs.ecs_new_prefab(world, "ham");
    flecs.ecs_add_pair(world, prefabs.ham, flecs.Constants.EcsIsA, prefabs._stackable);
    flecs.ecs_set(world, prefabs.ham, &components.Stack{ .max = 5 });
    flecs.ecs_set(world, prefabs.ham, &components.StackAnimator{
        .animation = &game.animations.Ham_Layer,
        .counts = &[_]usize{ 1, 2, 3, 4, 5 },
    });
    flecs.ecs_set(world, prefabs.ham, &components.SpriteRenderer{
        .index = game.assets.aftersun_atlas.Ham_0_Layer,
    });

    prefabs.apple = flecs.ecs_new_prefab(world, "apple");
    flecs.ecs_add_pair(world, prefabs.apple, flecs.Constants.EcsIsA, prefabs._stackable);
    flecs.ecs_set(world, prefabs.apple, &components.Stack{ .max = 5 });
    flecs.ecs_set(world, prefabs.apple, &components.StackAnimator{
        .animation = &game.animations.Apple_Layer,
        .counts = &[_]usize{ 1, 2, 3, 4, 5 },
    });
    flecs.ecs_set(world, prefabs.apple, &components.SpriteRenderer{
        .index = game.assets.aftersun_atlas.Apple_0_Layer,
    });

    return prefabs;
}

pub fn get(self: Prefabs, index: usize) flecs.EcsEntity {
    return switch (index) {
        0 => self._item,
        1 => self._stackable,
        2 => self.ham,
        3 => self.apple,
        else => unreachable,
    };
}
