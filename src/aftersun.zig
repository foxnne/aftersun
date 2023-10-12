const std = @import("std");
const zstbi = @import("zstbi");
const zmath = @import("zmath");
const ecs = @import("zflecs");

const core = @import("mach-core");
const gpu = core.gpu;

pub const name: [:0]const u8 = "Aftersun";
pub const settings = @import("settings.zig");

pub const assets = @import("assets.zig");
pub const shaders = @import("shaders.zig");
pub const animations = @import("animations.zig");
pub const animation_sets = @import("animation_sets.zig");

pub const components = @import("ecs/components/components.zig");

pub const fs = @import("tools/fs.zig");
pub const math = @import("math/math.zig");
pub const gfx = @import("gfx/gfx.zig");
pub const input = @import("input/input.zig");
pub const time = @import("time/time.zig");
pub const environment = @import("time/environment.zig");

test {
    _ = zstbi;
    _ = math;
    _ = gfx;
    _ = input;
    _ = time;
    _ = environment;
}

const Counter = @import("tools/counter.zig").Counter;
const Prefabs = @import("ecs/prefabs/prefabs.zig");

pub const App = @This();

timer: core.Timer,

pub var state: *GameState = undefined;
pub var content_scale: [2]f32 = undefined;
pub var window_size: [2]f32 = undefined;
pub var framebuffer_size: [2]f32 = undefined;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};

/// Holds the global game state.
pub const GameState = struct {
    allocator: std.mem.Allocator = undefined,
    root_path: [:0]const u8 = undefined,
    delta_time: f32 = 0.0,
    game_time: f32 = 0.0,
    world: *ecs.world_t = undefined,
    entities: Entities = .{},
    prefabs: Prefabs = undefined,
    camera: gfx.Camera = undefined,
    time: time.Time = .{},
    environment: environment.Environment = .{},
    counter: Counter = .{},
    cells: std.AutoArrayHashMap(components.Cell, ecs.entity_t) = undefined,
    output_channel: Channel = .final,
    pipeline_default: *gpu.RenderPipeline = undefined,
    pipeline_diffuse: *gpu.RenderPipeline = undefined,
    pipeline_height: *gpu.RenderPipeline = undefined,
    pipeline_glow: *gpu.RenderPipeline = undefined,
    pipeline_bloom_h: *gpu.RenderPipeline = undefined,
    pipeline_bloom: *gpu.RenderPipeline = undefined,
    pipeline_environment: *gpu.RenderPipeline = undefined,
    pipeline_final: *gpu.RenderPipeline = undefined,
    bind_group_default: *gpu.BindGroup = undefined,
    bind_group_diffuse: *gpu.BindGroup = undefined,
    bind_group_height: *gpu.BindGroup = undefined,
    bind_group_glow: *gpu.BindGroup = undefined,
    bind_group_bloom_h: *gpu.BindGroup = undefined,
    bind_group_bloom: *gpu.BindGroup = undefined,
    bind_group_environment: *gpu.BindGroup = undefined,
    bind_group_light: *gpu.BindGroup = undefined,
    bind_group_final: *gpu.BindGroup = undefined,
    uniform_buffer_default: *gpu.Buffer = undefined,
    uniform_buffer_environment: *gpu.Buffer = undefined,
    uniform_buffer_final: *gpu.Buffer = undefined,
    batcher: gfx.Batcher = undefined,
    diffusemap: gfx.Texture = undefined,
    palettemap: gfx.Texture = undefined,
    heightmap: gfx.Texture = undefined,
    lightmap: gfx.Texture = undefined,
    diffuse_output: gfx.Texture = undefined,
    height_output: gfx.Texture = undefined,
    glow_output: gfx.Texture = undefined,
    bloom_h_output: gfx.Texture = undefined,
    bloom_output: gfx.Texture = undefined,
    reverse_height_output: gfx.Texture = undefined,
    environment_output: gfx.Texture = undefined,
    light_output: gfx.Texture = undefined,
    atlas: gfx.Atlas = undefined,
    light_atlas: gfx.Atlas = undefined,
    mouse: input.Mouse = undefined,
    hotkeys: input.Hotkeys = undefined,
};

pub const Channel = enum(i32) {
    final,
    diffuse,
    height,
    reverse_height,
    environment,
    light,
    glow,
    bloom,
};

/// Holds global entities.
pub const Entities = struct {
    player: ecs.entity_t = 5000,
    debug: ecs.entity_t = 5001,
};

pub fn init(app: *App) !void {
    const allocator = gpa.allocator();

    var buffer: [1024]u8 = undefined;
    const root_path = std.fs.selfExeDirPath(buffer[0..]) catch ".";

    try core.init(.{
        .title = name,
        .size = .{ .width = 1280, .height = 720 },
    });

    const descriptor = core.descriptor;
    window_size = .{ @floatFromInt(core.size().width), @floatFromInt(core.size().height) };
    framebuffer_size = .{ @floatFromInt(descriptor.width), @floatFromInt(descriptor.height) };
    content_scale = .{
        framebuffer_size[0] / window_size[0],
        framebuffer_size[1] / window_size[1],
    };

    state = try allocator.create(GameState);
    state.* = .{ .root_path = try allocator.dupeZ(u8, root_path) };

    state.allocator = allocator;

    state.mouse = try input.Mouse.initDefault(allocator);
    state.hotkeys = try input.Hotkeys.initDefault(allocator);

    state.batcher = try gfx.Batcher.init(allocator, settings.batcher_max_sprites);
    state.cells = std.AutoArrayHashMap(components.Cell, ecs.entity_t).init(allocator);
    state.camera = gfx.Camera.init(settings.design_size, window_size, zmath.f32x4s(0));

    state.atlas = try gfx.Atlas.initFromFile(allocator, assets.aftersun_atlas.path);
    state.light_atlas = try gfx.Atlas.initFromFile(allocator, assets.aftersun_lights_atlas.path);

    zstbi.init(allocator);

    // Load game textures.
    state.diffusemap = try gfx.Texture.loadFromFile(assets.aftersun_png.path, .{});
    state.palettemap = try gfx.Texture.loadFromFile(assets.aftersun_palette_png.path, .{});
    state.heightmap = try gfx.Texture.loadFromFile(assets.aftersun_h_png.path, .{});
    state.lightmap = try gfx.Texture.loadFromFile(assets.aftersun_lights_png.path, .{
        .filter = .linear,
    });

    // Create textures to render to.
    state.diffuse_output = try gfx.Texture.createEmpty(settings.design_width, settings.design_height, .{ .format = core.descriptor.format });
    state.height_output = try gfx.Texture.createEmpty(settings.design_width, settings.design_height, .{ .format = core.descriptor.format });
    state.glow_output = try gfx.Texture.createEmpty(settings.design_width, settings.design_height, .{ .format = core.descriptor.format });
    state.bloom_h_output = try gfx.Texture.createEmpty(settings.design_width, settings.design_height, .{
        .filter = .linear,
        .format = core.descriptor.format,
    });
    state.bloom_output = try gfx.Texture.createEmpty(settings.design_width, settings.design_height, .{
        .filter = .linear,
        .format = core.descriptor.format,
    });
    state.reverse_height_output = try gfx.Texture.createEmpty(settings.design_width, settings.design_height, .{ .format = core.descriptor.format });
    state.environment_output = try gfx.Texture.createEmpty(settings.design_width, settings.design_height, .{ .format = core.descriptor.format });
    state.light_output = try gfx.Texture.createEmpty(settings.design_width, settings.design_height, .{
        .filter = .linear,
        .format = core.descriptor.format,
    });

    app.* = .{
        .timer = try core.Timer.start(),
    };

    try gfx.init(state);

    // Set up ECS world
    const world = ecs.init();
    state.world = world;

    // Ensure that auto-generated IDs are well above anything we will need.
    ecs.set_entity_range(world, 8000, 0);

    // Register all components
    components.register(world);

    // Create all of our prefabs
    var prefabs = Prefabs.init(world);
    prefabs.create(world);

    // - Cooldown
    var cooldown_system = @import("ecs/systems/cooldown.zig").system();
    ecs.SYSTEM(world, "CooldownSystem", ecs.OnUpdate, &cooldown_system);

    // - Input
    var movement_drag_system = @import("ecs/systems/movement_drag.zig").system(world);
    ecs.SYSTEM(world, "MovementDragSystem", ecs.OnUpdate, &movement_drag_system);
    var movement_request_system = @import("ecs/systems/movement_request.zig").system();
    ecs.SYSTEM(world, "MovementRequestSystem", ecs.OnUpdate, &movement_request_system);

    // - Movement
    var movement_collision_system = @import("ecs/systems/movement_collision.zig").system(world);
    ecs.SYSTEM(world, "MovementCollisionSystem", ecs.OnUpdate, &movement_collision_system);
    var movement_system = @import("ecs/systems/movement.zig").system();
    ecs.SYSTEM(world, "MovementSystem", ecs.OnUpdate, &movement_system);
    var velocity_system = @import("ecs/systems/velocity.zig").system();
    ecs.SYSTEM(world, "VelocitySystem", ecs.OnUpdate, &velocity_system);

    // - Other
    // var inspect_system = @import("ecs/systems/inspect.zig").system();
    // ecs.SYSTEM(world, "InspectSystem", ecs.OnUpdate, &inspect_system);
    var stack_system = @import("ecs/systems/stack.zig").system();
    ecs.SYSTEM(world, "StackSystem", ecs.OnUpdate, &stack_system);
    var use_system = @import("ecs/systems/use.zig").system(world);
    ecs.SYSTEM(world, "UseSystem", ecs.OnUpdate, &use_system);
    var cook_system = @import("ecs/systems/cook.zig").system();
    ecs.SYSTEM(world, "CookSystem", ecs.OnUpdate, &cook_system);

    // - Observers
    var tile_observer = @import("ecs/observers/tile.zig").observer();
    ecs.OBSERVER(world, "TileObserver", &tile_observer);
    var stack_observer = @import("ecs/observers/stack.zig").observer();
    ecs.OBSERVER(world, "StackObserver", &stack_observer);
    var free_particles_observer = @import("ecs/observers/free_particles.zig").observer();
    ecs.OBSERVER(world, "FreeParticlesObserver", &free_particles_observer);

    // - Camera
    var camera_follow_system = @import("ecs/systems/camera_follow.zig").system();
    ecs.SYSTEM(world, "CameraFollowSystem", ecs.OnUpdate, &camera_follow_system);
    var camera_zoom_system = @import("ecs/systems/camera_zoom.zig").system();
    ecs.SYSTEM(world, "CameraZoomSystem", ecs.OnUpdate, &camera_zoom_system);

    // - Animation
    var animation_character_system = @import("ecs/systems/animation_character.zig").system();
    ecs.SYSTEM(world, "AnimatorCharacterSystem", ecs.OnUpdate, &animation_character_system);
    var animation_sprite_system = @import("ecs/systems/animation_sprite.zig").system();
    ecs.SYSTEM(world, "AnimatorSpriteSystem", ecs.OnUpdate, &animation_sprite_system);
    var particle_system = @import("ecs/systems/animation_particle.zig").system();
    ecs.SYSTEM(world, "ParticleSystem", ecs.OnUpdate, &particle_system);

    // - Render
    var render_culling_system = @import("ecs/systems/render_culling.zig").system();
    ecs.SYSTEM(world, "RenderCullingSystem", ecs.PostUpdate, &render_culling_system);
    var render_diffuse_system = @import("ecs/systems/render_diffuse_pass.zig").system();
    ecs.SYSTEM(world, "RenderDiffuseSystem", ecs.PostUpdate, &render_diffuse_system);
    var render_light_system = @import("ecs/systems/render_light_pass.zig").system();
    ecs.SYSTEM(world, "RenderLightSystem", ecs.PostUpdate, &render_light_system);
    var render_height_system = @import("ecs/systems/render_height_pass.zig").system();
    ecs.SYSTEM(world, "RenderHeightSystem", ecs.PostUpdate, &render_height_system);
    var render_reverse_height_system = @import("ecs/systems/render_reverse_height_pass.zig").system();
    ecs.SYSTEM(world, "RenderReverseHeightSystem", ecs.PostUpdate, &render_reverse_height_system);
    var render_environment_system = @import("ecs/systems/render_environment_pass.zig").system();
    ecs.SYSTEM(world, "RenderEnvironmentSystem", ecs.PostUpdate, &render_environment_system);
    var render_glow_system = @import("ecs/systems/render_glow_pass.zig").system();
    ecs.SYSTEM(world, "RenderGlowSystem", ecs.PostUpdate, &render_glow_system);
    var render_bloom_h_system = @import("ecs/systems/render_bloom_h_pass.zig").system();
    ecs.SYSTEM(world, "RenderBloomHSystem", ecs.PostUpdate, &render_bloom_h_system);
    var render_bloom_system = @import("ecs/systems/render_bloom_pass.zig").system();
    ecs.SYSTEM(world, "RenderBloomSystem", ecs.PostUpdate, &render_bloom_system);
    var render_final_system = @import("ecs/systems/render_final_pass.zig").system();
    ecs.SYSTEM(world, "RenderFinalSystem", ecs.PostUpdate, &render_final_system);

    state.entities.player = ecs.new_entity(world, "Player");
    const player = state.entities.player;
    ecs.add(world, player, components.Player);
    _ = ecs.set(world, player, components.Position, .{ .x = 0.0, .y = -32.0 });
    _ = ecs.set(world, player, components.Tile, .{ .x = 0, .y = -1, .counter = state.counter.count() });
    _ = ecs.set(world, player, components.Collider, .{});
    _ = ecs.set(world, player, components.Velocity, .{});
    _ = ecs.set(world, player, components.CharacterRenderer, .{
        .body_index = assets.aftersun_atlas.Idle_SE_0_Body,
        .head_index = assets.aftersun_atlas.Idle_SE_0_Head,
        .bottom_index = assets.aftersun_atlas.Idle_SE_0_BottomF02,
        .feet_index = assets.aftersun_atlas.Idle_SE_0_FeetF01,
        .top_index = assets.aftersun_atlas.Idle_SE_0_TopF02,
        .back_index = assets.aftersun_atlas.Idle_SE_0_Back,
        .hair_index = assets.aftersun_atlas.Idle_SE_0_HairF01,
        .body_color = math.Color.initBytes(5, 0, 0, 255).toSlice(),
        .head_color = math.Color.initBytes(5, 0, 0, 255).toSlice(),
        .bottom_color = math.Color.initBytes(2, 0, 0, 255).toSlice(),
        .top_color = math.Color.initBytes(3, 0, 0, 255).toSlice(),
        .hair_color = math.Color.initBytes(1, 0, 0, 255).toSlice(),
        .feet_color = math.Color.initBytes(4, 0, 0, 255).toSlice(),
        .flip_head = true,
    });
    _ = ecs.set(world, player, components.CharacterAnimator, .{
        .head_set = animation_sets.head,
        .body_set = animation_sets.body,
        .top_set = animation_sets.top_f_02,
        .bottom_set = animation_sets.bottom_f_02,
        .feet_set = animation_sets.feet_f_01,
        .back_set = animation_sets.back_f_01,
        .hair_set = animation_sets.hair_f_01,
    });
    _ = ecs.set_pair(world, player, ecs.id(components.Direction), ecs.id(components.Movement), components.Direction, .none);
    _ = ecs.set_pair(world, player, ecs.id(components.Direction), ecs.id(components.Head), components.Direction, .se);
    _ = ecs.set_pair(world, player, ecs.id(components.Direction), ecs.id(components.Body), components.Direction, .se);
    ecs.add_pair(world, player, ecs.id(components.Camera), ecs.id(components.Target));

    state.entities.debug = ecs.new_entity(world, "Debug");
    const debug = state.entities.debug;
    ecs.add_pair(world, debug, ecs.IsA, state.prefabs.ham);
    _ = ecs.set(world, debug, components.Position, .{ .x = 0.0, .y = -64.0 });
    _ = ecs.set(world, debug, components.Tile, .{ .x = 0, .y = -2, .counter = state.counter.count() });

    const ham = ecs.new_id(world);
    ecs.add_pair(world, ham, ecs.IsA, state.prefabs.ham);
    _ = ecs.set(world, ham, components.Position, .{ .x = 0.0, .y = -96.0 });
    _ = ecs.set(world, ham, components.Tile, .{ .x = 0, .y = -3, .counter = state.counter.count() });
    _ = ecs.set(world, ham, components.Stack, .{ .count = 3, .max = 5 });

    // Create campfire
    {
        const campfire = ecs.new_entity(world, "campfire");
        _ = ecs.set(world, campfire, components.Position, .{ .x = 32.0, .y = -64.0 });
        _ = ecs.set(world, campfire, components.Tile, .{ .x = 1, .y = -2, .counter = state.counter.count() });
        _ = ecs.set(world, campfire, components.SpriteRenderer, .{ .index = assets.aftersun_atlas.Campfire_0_Layer_0 });
        _ = ecs.set(world, campfire, components.SpriteAnimator, .{
            .state = .play,
            .animation = &animations.Campfire_Layer_0,
            .fps = 16,
        });
        _ = ecs.set(world, campfire, components.Collider, .{ .trigger = true });
        ecs.add_pair(world, campfire, ecs.id(components.Trigger), ecs.id(components.Cook));
        _ = ecs.set(world, campfire, components.ParticleRenderer, .{
            .particles = try allocator.alloc(components.ParticleRenderer.Particle, 32),
            .offset = zmath.f32x4(0, settings.pixels_per_unit / 1.5, 0, 0),
        });
        _ = ecs.set(world, campfire, components.ParticleAnimator, .{
            .animation = &animations.Smoke_Layer,
            .rate = 8.0,
            .start_life = 2.0,
            .velocity_min = .{ -12.0, 28.0 },
            .velocity_max = .{ 0.0, 46.0 },
            .start_color = math.Color.initFloats(0.5, 0.5, 0.5, 1.0).toSlice(),
            .end_color = math.Color.initFloats(1.0, 1.0, 1.0, 0.3).toSlice(),
        });
        _ = ecs.set(world, campfire, components.LightRenderer, .{
            .index = assets.aftersun_lights_atlas.point256_png,
            .color = math.Color.initFloats(0.6, 0.4, 0.1, 1.0).toSlice(),
        });
    }

    // Create first tree
    {
        const tree = ecs.new_entity(world, "Tree01");
        _ = ecs.set(world, tree, components.Position, .{});
        _ = ecs.set(world, tree, components.Tile, .{ .counter = state.counter.count() });
        _ = ecs.set(world, tree, components.SpriteRenderer, .{ .index = assets.aftersun_atlas.Oak_0_Trunk });
        _ = ecs.set(world, tree, components.Collider, .{});

        const leaf_color = math.Color.initBytes(16, 0, 0, 255).toSlice();

        const tree_leaves_01 = ecs.new_entity(world, "TreeLeaves01");
        _ = ecs.set(world, tree_leaves_01, components.Position, .{});
        _ = ecs.set(world, tree_leaves_01, components.Tile, .{ .counter = state.counter.count() });
        _ = ecs.set(world, tree_leaves_01, components.SpriteRenderer, .{
            .index = assets.aftersun_atlas.Oak_0_Leaves04,
            .color = leaf_color,
            .frag_mode = .palette,
            .vert_mode = .top_sway,
        });

        const tree_leaves_02 = ecs.new_entity(world, "TreeLeaves02");
        ecs.add(world, tree_leaves_02, components.Position);
        _ = ecs.set(world, tree_leaves_02, components.Tile, .{ .counter = state.counter.count() });
        _ = ecs.set(world, tree_leaves_02, components.SpriteRenderer, .{
            .index = assets.aftersun_atlas.Oak_0_Leaves03,
            .color = leaf_color,
            .frag_mode = .palette,
            .vert_mode = .top_sway,
        });

        const tree_leaves_03 = ecs.new_entity(world, "TreeLeaves03");
        ecs.add(world, tree_leaves_03, components.Position);
        _ = ecs.set(world, tree_leaves_03, components.Tile, .{ .counter = state.counter.count() });
        _ = ecs.set(world, tree_leaves_03, components.SpriteRenderer, .{
            .index = assets.aftersun_atlas.Oak_0_Leaves02,
            .color = leaf_color,
            .frag_mode = .palette,
            .vert_mode = .top_sway,
        });

        const tree_leaves_04 = ecs.new_entity(world, "TreeLeaves04");
        ecs.add(world, tree_leaves_04, components.Position);
        _ = ecs.set(world, tree_leaves_04, components.Tile, .{ .counter = state.counter.count() });
        _ = ecs.set(world, tree_leaves_04, components.SpriteRenderer, .{
            .index = assets.aftersun_atlas.Oak_0_Leaves01,
            .color = leaf_color,
            .frag_mode = .palette,
            .vert_mode = .top_sway,
        });
    }

    // Create second tree
    {
        const position = components.Position{ .x = 64.0, .y = -32.0 };

        const tree = ecs.new_entity(world, "Tree02");
        _ = ecs.set(world, tree, components.Position, position);
        _ = ecs.set(world, tree, components.Tile, position.toTile(state.counter.count()));
        _ = ecs.set(world, tree, components.SpriteRenderer, .{ .index = assets.aftersun_atlas.Oak_0_Trunk });
        _ = ecs.set(world, tree, components.Collider, .{});

        const leaf_color = math.Color.initBytes(15, 0, 0, 255).toSlice();

        const tree_leaves_01 = ecs.new_w_id(world, ecs.pair(ecs.ChildOf, tree));
        _ = ecs.set(world, tree_leaves_01, components.Position, position);
        _ = ecs.set(world, tree_leaves_01, components.Tile, position.toTile(state.counter.count()));
        _ = ecs.set(world, tree_leaves_01, components.SpriteRenderer, .{
            .index = assets.aftersun_atlas.Oak_0_Leaves04,
            .color = leaf_color,
            .frag_mode = .palette,
            .vert_mode = .top_sway,
        });

        const tree_leaves_02 = ecs.new_w_id(world, ecs.pair(ecs.ChildOf, tree));
        _ = ecs.set(world, tree_leaves_02, components.Position, position);
        _ = ecs.set(world, tree_leaves_02, components.Tile, position.toTile(state.counter.count()));
        _ = ecs.set(world, tree_leaves_02, components.SpriteRenderer, .{
            .index = assets.aftersun_atlas.Oak_0_Leaves03,
            .color = leaf_color,
            .frag_mode = .palette,
            .vert_mode = .top_sway,
        });

        const tree_leaves_03 = ecs.new_w_id(world, ecs.pair(ecs.ChildOf, tree));
        _ = ecs.set(world, tree_leaves_03, components.Position, position);
        _ = ecs.set(world, tree_leaves_03, components.Tile, position.toTile(state.counter.count()));
        _ = ecs.set(world, tree_leaves_03, components.SpriteRenderer, .{
            .index = assets.aftersun_atlas.Oak_0_Leaves02,
            .color = leaf_color,
            .frag_mode = .palette,
            .vert_mode = .top_sway,
        });

        const tree_leaves_04 = ecs.new_w_id(world, ecs.pair(ecs.ChildOf, tree));
        _ = ecs.set(world, tree_leaves_04, components.Position, position);
        _ = ecs.set(world, tree_leaves_04, components.Tile, position.toTile(state.counter.count()));
        _ = ecs.set(world, tree_leaves_04, components.SpriteRenderer, .{
            .index = assets.aftersun_atlas.Oak_0_Leaves01,
            .color = leaf_color,
            .frag_mode = .palette,
            .vert_mode = .top_sway,
        });
    }

    // Create third tree
    {
        // Make sure its within another cell
        const position = components.Position{ .x = @as(f32, @floatFromInt(settings.cell_size + 2)) * settings.pixels_per_unit, .y = 0.0 };

        const tree = ecs.new_entity(world, "Tree03");
        _ = ecs.set(world, tree, components.Position, position);
        _ = ecs.set(world, tree, components.Tile, position.toTile(state.counter.count()));
        _ = ecs.set(world, tree, components.SpriteRenderer, .{ .index = assets.aftersun_atlas.Pine_0_Trunk, .vert_mode = .top_sway });
        _ = ecs.set(world, tree, components.Collider, .{});

        const tree_leaves_01 = ecs.new_w_id(world, ecs.pair(ecs.ChildOf, tree));
        _ = ecs.set(world, tree_leaves_01, components.Position, position);
        _ = ecs.set(world, tree_leaves_01, components.Tile, position.toTile(state.counter.count()));
        _ = ecs.set(world, tree_leaves_01, components.SpriteRenderer, .{
            .index = assets.aftersun_atlas.Pine_0_Needles,
            .vert_mode = .top_sway,
        });
    }
}

pub fn updateMainThread(_: *App) !bool {
    return false;
}

pub fn update(app: *App) !bool {
    state.delta_time = app.timer.lap();
    state.game_time += state.delta_time;

    const descriptor = core.descriptor;
    window_size = .{ @floatFromInt(core.size().width), @floatFromInt(core.size().height) };
    framebuffer_size = .{ @floatFromInt(descriptor.width), @floatFromInt(descriptor.height) };
    content_scale = .{
        framebuffer_size[0] / window_size[0],
        framebuffer_size[1] / window_size[1],
    };

    var iter = core.pollEvents();
    while (iter.next()) |event| {
        switch (event) {
            .key_press => |key_press| {
                state.hotkeys.setHotkeyState(key_press.key, key_press.mods, .press);
            },
            .key_repeat => |key_repeat| {
                state.hotkeys.setHotkeyState(key_repeat.key, key_repeat.mods, .repeat);
            },
            .key_release => |key_release| {
                state.hotkeys.setHotkeyState(key_release.key, key_release.mods, .release);
            },
            .mouse_scroll => |mouse_scroll| {
                state.mouse.setScrollState(mouse_scroll.xoffset, mouse_scroll.yoffset);
            },
            .mouse_motion => |mouse_motion| {
                state.mouse.position = .{ @floatCast(mouse_motion.pos.x * content_scale[0]), @floatCast(mouse_motion.pos.y * content_scale[1]) };
            },
            .mouse_press => |mouse_press| {
                state.mouse.setButtonState(mouse_press.button, mouse_press.mods, .press);
            },
            .mouse_release => |mouse_release| {
                state.mouse.setButtonState(mouse_release.button, mouse_release.mods, .release);
            },
            .close => {
                return true;
            },
            .framebuffer_resize => |size| {
                state.camera.frameBufferResize(size);
            },
            else => {},
        }
    }

    _ = ecs.progress(state.world, 0);

    const batcher_commands = try state.batcher.finish();
    defer batcher_commands.release();

    core.queue.submit(&.{batcher_commands});
    core.swap_chain.present();

    for (state.hotkeys.hotkeys) |*hotkey| {
        hotkey.previous_state = hotkey.state;
    }

    for (state.mouse.buttons) |*button| {
        button.previous_state = button.state;
    }

    state.mouse.previous_position = state.mouse.position;

    return false;
}

pub fn deinit(_: *App) void {
    // Remove all particle renderers so observer can free particles.
    ecs.remove_all(state.world, ecs.id(components.ParticleRenderer));

    state.pipeline_default.release();
    state.pipeline_diffuse.release();
    state.pipeline_height.release();
    state.pipeline_glow.release();
    state.pipeline_environment.release();
    state.pipeline_bloom.release();
    state.pipeline_bloom_h.release();
    state.pipeline_final.release();

    state.bind_group_default.release();
    state.bind_group_diffuse.release();
    state.bind_group_height.release();
    state.bind_group_environment.release();
    state.bind_group_glow.release();
    state.bind_group_bloom.release();
    state.bind_group_bloom_h.release();
    state.bind_group_final.release();

    state.diffusemap.deinit();
    state.palettemap.deinit();
    state.lightmap.deinit();
    state.heightmap.deinit();

    state.diffuse_output.deinit();
    state.height_output.deinit();
    state.environment_output.deinit();
    state.glow_output.deinit();
    state.bloom_output.deinit();
    state.bloom_h_output.deinit();
    state.light_output.deinit();
    state.reverse_height_output.deinit();

    state.allocator.free(state.atlas.sprites);
    state.allocator.free(state.atlas.animations);

    state.allocator.free(state.light_atlas.sprites);
    state.allocator.free(state.light_atlas.animations);

    state.allocator.free(state.mouse.buttons);
    state.allocator.free(state.hotkeys.hotkeys);

    state.batcher.deinit();
    state.cells.clearAndFree();
    state.cells.deinit();

    state.allocator.free(state.root_path);

    state.allocator.destroy(state);

    core.deinit();
    // TODO: Figure out why autohashmap is leaking
    //_ = gpa.detectLeaks();
}
