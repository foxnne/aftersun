const std = @import("std");
const zm = @import("zmath");
const game = @import("root");
const components = game.components;
const ecs = @import("zflecs");

const Prefabs = @This();

_item: ecs.entity_t = 0,
_stackable: ecs.entity_t = 0,
apple: ecs.entity_t = 0,
cooked_ham: ecs.entity_t = 0,
ham: ecs.entity_t = 0,
pear: ecs.entity_t = 0,
plum: ecs.entity_t = 0,
torch: ecs.entity_t = 0,
lit_torch: ecs.entity_t = 0,

pub fn init(world: *ecs.world_t) Prefabs {
    var prefabs: Prefabs = .{};
    const fields = comptime std.meta.fieldNames(Prefabs);
    inline for (fields) |field_name| {
        @field(prefabs, field_name) = ecs.new_prefab(world, field_name[0.. :0]);
    }
    return prefabs;
}

pub fn create(prefabs: *Prefabs, world: *ecs.world_t) void {
    ecs.add(world, prefabs._item, components.Position);

    // Base item
    ecs.add(world, prefabs._item, components.Position);
    ecs.override(world, prefabs._item, components.Position);
    ecs.add(world, prefabs._item, components.Tile);
    ecs.override(world, prefabs._item, components.Tile);
    ecs.add(world, prefabs._item, components.Moveable);
    ecs.add(world, prefabs._item, components.SpriteRenderer);
    ecs.override(world, prefabs._item, components.SpriteRenderer);

    // Stackable item
    ecs.add_pair(world, prefabs._stackable, ecs.EcsIsA, prefabs._item);
    _ = ecs.set(world, prefabs._stackable, components.Stack, .{ .max = 100 });
    ecs.override(world, prefabs._stackable, components.Stack);

    // Ham
    ecs.add_pair(world, prefabs.ham, ecs.EcsIsA, prefabs._stackable);
    _ = ecs.set(world, prefabs.ham, components.Stack, .{ .max = 5 });
    _ = ecs.set(world, prefabs.ham, components.StackAnimator, .{
        .animation = &game.animations.Ham_Layer,
        .counts = &[_]usize{ 1, 2, 3, 4, 5 },
    });
    _ = ecs.set(world, prefabs.ham, components.SpriteRenderer, .{
        .index = game.assets.aftersun_atlas.Ham_0_Layer,
    });
    _ = ecs.set(world, prefabs.ham, components.Raw, .{ .cooked_prefab = prefabs.cooked_ham });

    // Cooked ham
    ecs.add_pair(world, prefabs.cooked_ham, ecs.EcsIsA, prefabs._stackable);
    _ = ecs.set(world, prefabs.cooked_ham, components.Stack, .{ .max = 5 });
    _ = ecs.set(world, prefabs.cooked_ham, components.StackAnimator, .{
        .animation = &game.animations.Cooked_Ham_Layer,
        .counts = &[_]usize{ 1, 2, 3, 4, 5 },
    });
    _ = ecs.set(world, prefabs.cooked_ham, components.SpriteRenderer, .{
        .index = game.assets.aftersun_atlas.Cooked_Ham_0_Layer,
    });
    _ = ecs.add(world, prefabs.cooked_ham, components.Consumeable);
    _ = ecs.add(world, prefabs.cooked_ham, components.Useable);

    // Apple
    ecs.add_pair(world, prefabs.apple, ecs.EcsIsA, prefabs._stackable);
    _ = ecs.set(world, prefabs.apple, components.Stack, .{ .max = 5 });
    _ = ecs.set(world, prefabs.apple, components.StackAnimator, .{
        .animation = &game.animations.Apple_Layer,
        .counts = &[_]usize{ 1, 2, 3, 4, 5 },
    });
    _ = ecs.set(world, prefabs.apple, components.SpriteRenderer, .{
        .index = game.assets.aftersun_atlas.Apple_0_Layer,
    });
    ecs.add(world, prefabs.apple, components.Consumeable);
    ecs.add(world, prefabs.apple, components.Useable);

    // Plum
    ecs.add_pair(world, prefabs.plum, ecs.EcsIsA, prefabs._stackable);
    _ = ecs.set(world, prefabs.plum, components.Stack, .{ .max = 5 });
    _ = ecs.set(world, prefabs.plum, components.StackAnimator, .{
        .animation = &game.animations.Plum_Layer,
        .counts = &[_]usize{ 1, 2, 3, 4, 5 },
    });
    _ = ecs.set(world, prefabs.plum, components.SpriteRenderer, .{
        .index = game.assets.aftersun_atlas.Plum_0_Layer,
    });
    ecs.add(world, prefabs.plum, components.Consumeable);
    ecs.add(world, prefabs.plum, components.Useable);

    // Pear
    ecs.add_pair(world, prefabs.pear, ecs.EcsIsA, prefabs._stackable);
    _ = ecs.set(world, prefabs.pear, components.Stack, .{ .max = 5 });
    _ = ecs.set(world, prefabs.pear, components.StackAnimator, .{
        .animation = &game.animations.Pear_Layer,
        .counts = &[_]usize{ 1, 2, 3, 4, 5 },
    });
    _ = ecs.set(world, prefabs.pear, components.SpriteRenderer, .{
        .index = game.assets.aftersun_atlas.Pear_0_Layer,
    });
    ecs.add(world, prefabs.pear, components.Consumeable);
    ecs.add(world, prefabs.pear, components.Useable);

    // Lit torch
    ecs.add_pair(world, prefabs.lit_torch, ecs.EcsIsA, prefabs._item);
    _ = ecs.set(world, prefabs.lit_torch, components.SpriteAnimator, .{
        .animation = &game.animations.Torch_Flame_Layer,
        .state = .play,
        .fps = 16,
    });
    ecs.override(world, prefabs.lit_torch, components.SpriteAnimator);
    _ = ecs.set(world, prefabs.lit_torch, components.SpriteRenderer, .{
        .index = game.assets.aftersun_atlas.Torch_Flame_0_Layer,
    });
    ecs.add(world, prefabs.lit_torch, components.Useable);
    _ = ecs.set(world, prefabs.lit_torch, components.Toggleable, .{
        .state = true,
        .on_prefab = prefabs.lit_torch,
        .off_prefab = prefabs.torch,
    });
    _ = ecs.set(world, prefabs.lit_torch, components.LightRenderer, .{
        .index = game.assets.aftersun_lights_atlas.point128_png,
        .color = game.math.Color.initFloats(0.6, 0.4, 0.1, 1.0).toSlice(),
    });
    ecs.override(world, prefabs.lit_torch, components.LightRenderer);

    // Torch
    ecs.add_pair(world, prefabs.torch, ecs.EcsIsA, prefabs._item);
    _ = ecs.set(world, prefabs.torch, components.SpriteRenderer, .{
        .index = game.assets.aftersun_atlas.Torch_0_Layer,
    });
    ecs.add(world, prefabs.torch, components.Useable);
    _ = ecs.set(world, prefabs.torch, components.Toggleable, .{
        .state = false,
        .on_prefab = prefabs.lit_torch,
        .off_prefab = prefabs.torch,
    });
}
