const std = @import("std");
const zm = @import("zmath");
const game = @import("game");
const components = game.components;
const flecs = @import("flecs");

const Prefabs = @This();

pub var item: flecs.EcsEntity = 0;
pub var ham: flecs.EcsEntity = 0;

pub fn init (world: *flecs.EcsWorld) Prefabs {

    item = flecs.ecs_new_prefab(world, "Item");
    flecs.ecs_add(world, item, components.Position);
    flecs.ecs_override(world, item, components.Position);
    flecs.ecs_add(world, item, components.Tile);
    flecs.ecs_override(world, item, components.Tile);
    flecs.ecs_add(world, item, components.Moveable);
    flecs.ecs_add(world, item, components.SpriteRenderer);
    flecs.ecs_override(world, item, components.SpriteRenderer);
    
   
    ham = flecs.ecs_new_prefab(world, "Ham");
    
}