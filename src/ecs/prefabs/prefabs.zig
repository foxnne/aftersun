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
pear: flecs.EcsEntity = 0,
plum: flecs.EcsEntity = 0,
torch: flecs.EcsEntity = 0,
lit_torch: flecs.EcsEntity = 0,

pub const id_start: u64 = 6000;

pub fn init(world: *flecs.EcsWorld) Prefabs {
    var prefabs: Prefabs = .{};
    const fields = comptime std.meta.fieldNames(Prefabs);
    inline for (fields) |field_name| {
        @field(prefabs, field_name) = flecs.ecs_new_prefab(world, field_name[0.. :0]);
    }
    return prefabs;
}

pub fn create(prefabs: *Prefabs, world: *flecs.EcsWorld) void {
    // Base item
    flecs.ecs_add(world, prefabs._item, components.Position);
    flecs.ecs_override(world, prefabs._item, components.Position);
    flecs.ecs_add(world, prefabs._item, components.Tile);
    flecs.ecs_override(world, prefabs._item, components.Tile);
    flecs.ecs_add(world, prefabs._item, components.Moveable);
    flecs.ecs_add(world, prefabs._item, components.SpriteRenderer);
    flecs.ecs_override(world, prefabs._item, components.SpriteRenderer);

    // Stackable item
    flecs.ecs_add_pair(world, prefabs._stackable, flecs.Constants.EcsIsA, prefabs._item);
    flecs.ecs_set(world, prefabs._stackable, &components.Stack{ .max = 100 });
    flecs.ecs_override(world, prefabs._stackable, components.Stack);

    // Ham
    flecs.ecs_add_pair(world, prefabs.ham, flecs.Constants.EcsIsA, prefabs._stackable);
    flecs.ecs_set(world, prefabs.ham, &components.Stack{ .max = 5 });
    flecs.ecs_set(world, prefabs.ham, &components.StackAnimator{
        .animation = &game.animations.Ham_Layer,
        .counts = &[_]usize{ 1, 2, 3, 4, 5 },
    });
    flecs.ecs_set(world, prefabs.ham, &components.SpriteRenderer{
        .index = game.assets.aftersun_atlas.Ham_0_Layer,
    });
    flecs.ecs_set(world, prefabs.ham, &components.Raw{ .cooked_prefab = prefabs.cooked_ham });

    // Cooked ham
    flecs.ecs_add_pair(world, prefabs.cooked_ham, flecs.Constants.EcsIsA, prefabs._stackable);
    flecs.ecs_set(world, prefabs.cooked_ham, &components.Stack{ .max = 5 });
    flecs.ecs_set(world, prefabs.cooked_ham, &components.StackAnimator{
        .animation = &game.animations.Cooked_Ham_Layer,
        .counts = &[_]usize{ 1, 2, 3, 4, 5 },
    });
    flecs.ecs_set(world, prefabs.cooked_ham, &components.SpriteRenderer{
        .index = game.assets.aftersun_atlas.Cooked_Ham_0_Layer,
    });
    flecs.ecs_add(world, prefabs.cooked_ham, components.Consumeable);
    flecs.ecs_add(world, prefabs.cooked_ham, components.Useable);

    // Apple
    flecs.ecs_add_pair(world, prefabs.apple, flecs.Constants.EcsIsA, prefabs._stackable);
    flecs.ecs_set(world, prefabs.apple, &components.Stack{ .max = 5 });
    flecs.ecs_set(world, prefabs.apple, &components.StackAnimator{
        .animation = &game.animations.Apple_Layer,
        .counts = &[_]usize{ 1, 2, 3, 4, 5 },
    });
    flecs.ecs_set(world, prefabs.apple, &components.SpriteRenderer{
        .index = game.assets.aftersun_atlas.Apple_0_Layer,
    });
    flecs.ecs_add(world, prefabs.apple, components.Consumeable);
    flecs.ecs_add(world, prefabs.apple, components.Useable);

    // Plum
    flecs.ecs_add_pair(world, prefabs.plum, flecs.Constants.EcsIsA, prefabs._stackable);
    flecs.ecs_set(world, prefabs.plum, &components.Stack{ .max = 5 });
    flecs.ecs_set(world, prefabs.plum, &components.StackAnimator{
        .animation = &game.animations.Plum_Layer,
        .counts = &[_]usize{ 1, 2, 3, 4, 5 },
    });
    flecs.ecs_set(world, prefabs.plum, &components.SpriteRenderer{
        .index = game.assets.aftersun_atlas.Plum_0_Layer,
    });
    flecs.ecs_add(world, prefabs.plum, components.Consumeable);
    flecs.ecs_add(world, prefabs.plum, components.Useable);

    // Pear
    flecs.ecs_add_pair(world, prefabs.pear, flecs.Constants.EcsIsA, prefabs._stackable);
    flecs.ecs_set(world, prefabs.pear, &components.Stack{ .max = 5 });
    flecs.ecs_set(world, prefabs.pear, &components.StackAnimator{
        .animation = &game.animations.Pear_Layer,
        .counts = &[_]usize{ 1, 2, 3, 4, 5 },
    });
    flecs.ecs_set(world, prefabs.pear, &components.SpriteRenderer{
        .index = game.assets.aftersun_atlas.Pear_0_Layer,
    });
    flecs.ecs_add(world, prefabs.pear, components.Consumeable);
    flecs.ecs_add(world, prefabs.pear, components.Useable);

    // Lit torch
    flecs.ecs_add_pair(world, prefabs.lit_torch, flecs.Constants.EcsIsA, prefabs._item);
    flecs.ecs_set(world, prefabs.lit_torch, &components.SpriteAnimator{
        .animation = &game.animations.Torch_Flame_Layer,
        .state = .play,
        .fps = 16,
    });
    flecs.ecs_override(world, prefabs.lit_torch, components.SpriteAnimator);
    flecs.ecs_set(world, prefabs.lit_torch, &components.SpriteRenderer{
        .index = game.assets.aftersun_atlas.Torch_Flame_0_Layer,
    });
    flecs.ecs_add(world, prefabs.lit_torch, components.Useable);
    flecs.ecs_set(world, prefabs.lit_torch, &components.Toggleable{
        .state = true,
        .on_prefab = prefabs.lit_torch,
        .off_prefab = prefabs.torch,
    });

    // Torch
    flecs.ecs_add_pair(world, prefabs.torch, flecs.Constants.EcsIsA, prefabs._item);
    flecs.ecs_set(world, prefabs.torch, &components.SpriteRenderer{
        .index = game.assets.aftersun_atlas.Torch_0_Layer,
    });
    flecs.ecs_add(world, prefabs.torch, components.Useable);
    flecs.ecs_set(world, prefabs.torch, &components.Toggleable{
        .state = false,
        .on_prefab = prefabs.lit_torch,
        .off_prefab = prefabs.torch,
    });
}
