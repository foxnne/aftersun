const std = @import("std");
const ecs = @import("zflecs");
const mach = @import("mach-core");
const game = @import("../aftersun.zig");
const components = game.components;
const assets = game.assets;
const math = game.math;

const Self = @This();

entity_pool: std.ArrayList(ecs.entity_t),

pub fn init(allocator: std.mem.Allocator) Self {
    var pool = std.ArrayList(ecs.entity_t).init(allocator);

    return .{
        .entity_pool = pool,
    };
}

pub fn loadCell(self: *Self, cell: components.Cell) void {
    var cell_entity: ecs.entity_t = 0;
    if (game.state.cells.get(cell)) |c| {
        cell_entity = c;
    } else {
        cell_entity = ecs.new_id(game.state.world);
        _ = ecs.set(game.state.world, cell_entity, components.Cell, cell);
        game.state.cells.put(cell, cell_entity) catch unreachable;
    }

    var hash = std.hash.Fnv1a_64.init();
    hash.update(std.mem.asBytes(&cell.x));
    hash.update(std.mem.asBytes(&cell.y));
    hash.update(std.mem.asBytes(&cell.z));
    const seed = hash.final();

    var rand = std.rand.DefaultPrng.init(seed);
    var random = rand.random();

    const cell_density = random.float(f32) * 0.15;

    for (0..game.settings.cell_size) |x_i| {
        for (0..game.settings.cell_size) |y_i| {
            var x_tile: i32 = @intCast(x_i);
            var y_tile: i32 = @intCast(y_i);

            const tile: components.Tile = .{
                .x = x_tile + (cell.x * game.settings.cell_size),
                .y = y_tile + (cell.y * game.settings.cell_size),
                .z = cell.z,
                .counter = 0,
                .kind = .ground,
            };

            const position = tile.toPosition();

            const tile_entity = if (self.entity_pool.items.len > 0) self.entity_pool.pop() else ecs.new_id(game.state.world);

            const water = assets.aftersun_atlas.Water_full_0_Layer_0;
            const grass: usize = if (random.boolean()) assets.aftersun_atlas.Grass_full_0_Layer_0 else assets.aftersun_atlas.Grass_full_4_0_Layer_0;
            const edge = assets.aftersun_atlas.Grass_Water_S_0_Layer_0;

            _ = ecs.set(game.state.world, tile_entity, components.Tile, tile);
            _ = ecs.set(game.state.world, tile_entity, components.Position, position);
            _ = ecs.set(game.state.world, tile_entity, components.SpriteRenderer, .{
                .index = if (tile.y < -3) water else if (tile.y == -3) edge else grass,
            });
            _ = ecs.set_pair(game.state.world, tile_entity, ecs.id(components.Cell), cell_entity, components.Cell, cell);
            _ = ecs.set(game.state.world, tile_entity, components.MapTile, if (tile.y < -3) .water else .ground);
            _ = ecs.add(game.state.world, tile_entity, components.Unloadable);

            if (tile.y > -2) {
                if (random.float(f32) > 1.0 - cell_density) {
                    {
                        const reflect = true;

                        const tree = if (self.entity_pool.items.len > 0) self.entity_pool.pop() else ecs.new_id(game.state.world);
                        _ = ecs.set(game.state.world, tree, components.Position, position);
                        _ = ecs.set(game.state.world, tree, components.Tile, position.toTile(game.state.counter.count()));
                        _ = ecs.set(game.state.world, tree, components.SpriteRenderer, .{
                            .index = assets.aftersun_atlas.Oak_0_Trunk,
                            .reflect = reflect,
                        });
                        _ = ecs.set(game.state.world, tree, components.Collider, .{});
                        _ = ecs.set_pair(game.state.world, tree, ecs.id(components.Cell), cell_entity, components.Cell, cell);

                        const rand_f = random.float(f32);
                        const leaf_color = math.Color.initBytes(if (rand_f <= 0.25) 14 else if (rand_f <= 0.5) 15 else if (rand_f <= 0.75) 16 else 15, 0, 0, 255).toSlice();

                        const tree_leaves_01 = if (self.entity_pool.items.len > 0) self.entity_pool.pop() else ecs.new_id(game.state.world);
                        _ = ecs.set(game.state.world, tree_leaves_01, components.Position, position);
                        _ = ecs.set(game.state.world, tree_leaves_01, components.Tile, position.toTile(game.state.counter.count()));
                        _ = ecs.set(game.state.world, tree_leaves_01, components.SpriteRenderer, .{
                            .index = assets.aftersun_atlas.Oak_0_Leaves04,
                            .color = leaf_color,
                            .frag_mode = .palette,
                            .vert_mode = .top_sway,
                            .reflect = reflect,
                        });
                        _ = ecs.set_pair(game.state.world, tree_leaves_01, ecs.id(components.Cell), cell_entity, components.Cell, cell);

                        const tree_leaves_02 = if (self.entity_pool.items.len > 0) self.entity_pool.pop() else ecs.new_id(game.state.world);
                        _ = ecs.set(game.state.world, tree_leaves_02, components.Position, position);
                        _ = ecs.set(game.state.world, tree_leaves_02, components.Tile, position.toTile(game.state.counter.count()));
                        _ = ecs.set(game.state.world, tree_leaves_02, components.SpriteRenderer, .{
                            .index = assets.aftersun_atlas.Oak_0_Leaves03,
                            .color = leaf_color,
                            .frag_mode = .palette,
                            .vert_mode = .top_sway,
                            .reflect = reflect,
                        });

                        _ = ecs.set_pair(game.state.world, tree_leaves_02, ecs.id(components.Cell), cell_entity, components.Cell, cell);

                        const tree_leaves_03 = if (self.entity_pool.items.len > 0) self.entity_pool.pop() else ecs.new_id(game.state.world);
                        _ = ecs.set(game.state.world, tree_leaves_03, components.Position, position);
                        _ = ecs.set(game.state.world, tree_leaves_03, components.Tile, position.toTile(game.state.counter.count()));
                        _ = ecs.set(game.state.world, tree_leaves_03, components.SpriteRenderer, .{
                            .index = assets.aftersun_atlas.Oak_0_Leaves02,
                            .color = leaf_color,
                            .frag_mode = .palette,
                            .vert_mode = .top_sway,
                            .reflect = reflect,
                        });
                        _ = ecs.set_pair(game.state.world, tree_leaves_03, ecs.id(components.Cell), cell_entity, components.Cell, cell);

                        const tree_leaves_04 = if (self.entity_pool.items.len > 0) self.entity_pool.pop() else ecs.new_id(game.state.world);
                        _ = ecs.set(game.state.world, tree_leaves_04, components.Position, position);
                        _ = ecs.set(game.state.world, tree_leaves_04, components.Tile, position.toTile(game.state.counter.count()));
                        _ = ecs.set(game.state.world, tree_leaves_04, components.SpriteRenderer, .{
                            .index = assets.aftersun_atlas.Oak_0_Leaves01,
                            .color = leaf_color,
                            .frag_mode = .palette,
                            .vert_mode = .top_sway,
                            .reflect = reflect,
                        });
                        _ = ecs.set_pair(game.state.world, tree_leaves_04, ecs.id(components.Cell), cell_entity, components.Cell, cell);

                        _ = ecs.add(game.state.world, tree, components.Unloadable);
                        _ = ecs.add(game.state.world, tree_leaves_01, components.Unloadable);
                        _ = ecs.add(game.state.world, tree_leaves_02, components.Unloadable);
                        _ = ecs.add(game.state.world, tree_leaves_03, components.Unloadable);
                        _ = ecs.add(game.state.world, tree_leaves_04, components.Unloadable);
                    }
                } else if (random.float(f32) < cell_density * 0.4) {
                    const reflect = true;

                    const tree = if (self.entity_pool.items.len > 0) self.entity_pool.pop() else ecs.new_id(game.state.world);
                    _ = ecs.set(game.state.world, tree, components.Position, position);
                    _ = ecs.set(game.state.world, tree, components.Tile, position.toTile(game.state.counter.count()));
                    _ = ecs.set(game.state.world, tree, components.SpriteRenderer, .{
                        .index = assets.aftersun_atlas.Pine_0_Trunk,
                        .reflect = reflect,
                        .vert_mode = .top_sway,
                    });
                    _ = ecs.set(game.state.world, tree, components.Collider, .{});
                    _ = ecs.set_pair(game.state.world, tree, ecs.id(components.Cell), cell_entity, components.Cell, cell);

                    const tree_leaves_01 = if (self.entity_pool.items.len > 0) self.entity_pool.pop() else ecs.new_id(game.state.world);
                    _ = ecs.set(game.state.world, tree_leaves_01, components.Position, position);
                    _ = ecs.set(game.state.world, tree_leaves_01, components.Tile, position.toTile(game.state.counter.count()));
                    _ = ecs.set(game.state.world, tree_leaves_01, components.SpriteRenderer, .{
                        .index = assets.aftersun_atlas.Pine_0_Needles,
                        .vert_mode = .top_sway,
                        .reflect = reflect,
                    });
                    _ = ecs.set_pair(game.state.world, tree_leaves_01, ecs.id(components.Cell), cell_entity, components.Cell, cell);

                    _ = ecs.add(game.state.world, tree, components.Unloadable);
                    _ = ecs.add(game.state.world, tree_leaves_01, components.Unloadable);
                } else {
                    _ = ecs.add(game.state.world, tile_entity, components.Walkable);
                }
            }
        }
    }
}

pub fn unloadCell(self: *Self, cell: components.Cell, query_it: *ecs.iter_t) void {
    if (game.state.cells.get(cell)) |cell_entity| {
        ecs.query_set_group(query_it, cell_entity);
        while (ecs.iter_next(query_it)) {
            for (query_it.entities()) |entity| {
                //ecs.delete(game.state.world, entity);

                ecs.clear(game.state.world, entity);

                self.entity_pool.append(entity) catch unreachable;
                //ecs.enable(game.state.world, entity, false);
            }
        }
    }
}
