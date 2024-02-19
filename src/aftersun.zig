const std = @import("std");
const build_options = @import("build-options");

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

pub const Map = @import("map/map.zig");

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

pub const mach_core_options = core.ComptimeOptions{
    .use_wgpu = !build_options.use_sysgpu,
    .use_sysgpu = build_options.use_sysgpu,
};

timer: core.Timer,
title_timer: core.Timer,

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
    map: Map = undefined,
    scanner_time: f32 = 0.0,
    scanner_state: bool = false,
    output_channel: Channel = .final,
    pipeline_default: *gpu.RenderPipeline = undefined,
    pipeline_diffuse: *gpu.RenderPipeline = undefined,
    pipeline_height: *gpu.RenderPipeline = undefined,
    pipeline_glow: *gpu.RenderPipeline = undefined,
    //pipeline_bloom_h: *gpu.RenderPipeline = undefined,
    pipeline_bloom: *gpu.ComputePipeline = undefined,
    pipeline_environment: *gpu.RenderPipeline = undefined,
    pipeline_final: *gpu.RenderPipeline = undefined,
    pipeline_post: *gpu.RenderPipeline = undefined,
    bind_group_default: *gpu.BindGroup = undefined,
    bind_group_reflection: *gpu.BindGroup = undefined,
    bind_group_diffuse: *gpu.BindGroup = undefined,
    bind_group_height: *gpu.BindGroup = undefined,
    bind_group_glow: *gpu.BindGroup = undefined,
    bind_group_bloom_h: *gpu.BindGroup = undefined,
    bind_group_bloom: *gpu.BindGroup = undefined,
    bind_group_environment: *gpu.BindGroup = undefined,
    bind_group_light: *gpu.BindGroup = undefined,
    bind_group_final: *gpu.BindGroup = undefined,
    bind_group_post: *gpu.BindGroup = undefined,
    blur_params_buffer: *gpu.Buffer = undefined,
    compute_constants: *gpu.BindGroup = undefined,
    bind_group_compute_0: *gpu.BindGroup = undefined,
    bind_group_compute_1: *gpu.BindGroup = undefined,
    bind_group_compute_2: *gpu.BindGroup = undefined,
    uniform_buffer_default: *gpu.Buffer = undefined,
    uniform_buffer_environment: *gpu.Buffer = undefined,
    uniform_buffer_final: *gpu.Buffer = undefined,
    batcher: gfx.Batcher = undefined,
    diffusemap: gfx.Texture = undefined,
    palettemap: gfx.Texture = undefined,
    heightmap: gfx.Texture = undefined,
    lightmap: gfx.Texture = undefined,
    diffuse_output: gfx.Texture = undefined,
    reflection_output: gfx.Texture = undefined,
    height_output: gfx.Texture = undefined,
    glow_output: gfx.Texture = undefined,
    bloom_h_output: gfx.Texture = undefined,
    bloom_output: gfx.Texture = undefined,
    reverse_height_output: gfx.Texture = undefined,
    environment_output: gfx.Texture = undefined,
    light_output: gfx.Texture = undefined,
    temp_output: gfx.Texture = undefined,
    final_output: gfx.Texture = undefined,
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
    state.map = Map.init(allocator);
    state.camera = gfx.Camera.init(zmath.f32x4s(0));

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
    state.temp_output = try gfx.Texture.createEmpty(settings.design_width, settings.design_height, .{ .format = core.descriptor.format });
    state.reflection_output = try gfx.Texture.createEmpty(settings.design_width, settings.design_height, .{ .format = core.descriptor.format });
    state.height_output = try gfx.Texture.createEmpty(settings.design_width, settings.design_height, .{ .format = core.descriptor.format });
    state.glow_output = try gfx.Texture.createEmpty(settings.design_width, settings.design_height, .{ .format = core.descriptor.format });
    state.bloom_h_output = try gfx.Texture.createEmpty(settings.design_width, settings.design_height, .{
        .filter = .linear,
        .storage_binding = true,
    });
    state.bloom_output = try gfx.Texture.createEmpty(settings.design_width, settings.design_height, .{
        .filter = .linear,
        .storage_binding = true,
    });
    state.reverse_height_output = try gfx.Texture.createEmpty(settings.design_width, settings.design_height, .{ .format = core.descriptor.format });
    state.environment_output = try gfx.Texture.createEmpty(settings.design_width, settings.design_height, .{ .format = core.descriptor.format });
    state.light_output = try gfx.Texture.createEmpty(settings.design_width, settings.design_height, .{
        .filter = .linear,
        .format = core.descriptor.format,
    });

    state.final_output = try gfx.Texture.createEmpty(settings.design_width, settings.design_height, .{ .format = core.descriptor.format });

    app.* = .{
        .timer = try core.Timer.start(),
        .title_timer = try core.Timer.start(),
    };

    try gfx.init(state);

    // Set up ECS world
    const world = ecs.init();
    state.world = world;

    // Ensure that auto-generated IDs are well above anything we will need.
    //ecs.set_entity_range(world, 8000, std.math.maxInt(u64));

    // Register all components
    components.register(world);

    // Create all of our prefabs
    state.prefabs = Prefabs.init(world);
    state.prefabs.create(world);

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
    var movement_system = @import("ecs/systems/movement.zig").system(world);
    ecs.SYSTEM(world, "MovementSystem", ecs.OnUpdate, &movement_system);

    // - Other
    // var inspect_system = @import("ecs/systems/inspect.zig").system();
    // ecs.SYSTEM(world, "InspectSystem", ecs.OnUpdate, &inspect_system);
    var stack_system = @import("ecs/systems/stack.zig").system();
    ecs.SYSTEM(world, "StackSystem", ecs.OnUpdate, &stack_system);
    var use_system = @import("ecs/systems/use.zig").system(world);
    ecs.SYSTEM(world, "UseSystem", ecs.OnUpdate, &use_system);
    var cook_system = @import("ecs/systems/cook.zig").system();
    ecs.SYSTEM(world, "CookSystem", ecs.OnUpdate, &cook_system);
    var scanner_system = @import("ecs/systems/scanner.zig").system();
    ecs.SYSTEM(world, "ScannerSystem", ecs.OnUpdate, &scanner_system);

    // - Observers
    var tile_observer = @import("ecs/observers/tile.zig").observer();
    ecs.OBSERVER(world, "TileObserver", &tile_observer);
    var stack_observer = @import("ecs/observers/stack.zig").observer();
    ecs.OBSERVER(world, "StackObserver", &stack_observer);
    var free_particles_observer = @import("ecs/observers/free_particles.zig").observer();
    ecs.OBSERVER(world, "FreeParticlesObserver", &free_particles_observer);

    // - Camera
    var camera_inertia_system = @import("ecs/systems/camera_inertia.zig").system();
    ecs.SYSTEM(world, "VelocitySystem", ecs.OnUpdate, &camera_inertia_system);
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
    // var render_culling_system = @import("ecs/systems/render_culling.zig").system();
    // ecs.SYSTEM(world, "RenderCullingSystem", ecs.PostUpdate, &render_culling_system);
    var render_main_system = @import("ecs/systems/render_main_pass.zig").system(world);
    ecs.SYSTEM(world, "RenderDiffuseSystem", ecs.PostUpdate, &render_main_system);
    var render_light_system = @import("ecs/systems/render_light_pass.zig").system();
    ecs.SYSTEM(world, "RenderLightSystem", ecs.PostUpdate, &render_light_system);
    var render_environment_system = @import("ecs/systems/render_environment_pass.zig").system();
    ecs.SYSTEM(world, "RenderEnvironmentSystem", ecs.PostUpdate, &render_environment_system);
    var render_glow_system = @import("ecs/systems/render_glow_pass.zig").system();
    ecs.SYSTEM(world, "RenderGlowSystem", ecs.PostUpdate, &render_glow_system);
    // var render_bloom_h_system = @import("ecs/systems/render_bloom_h_pass.zig").system();
    // ecs.SYSTEM(world, "RenderBloomHSystem", ecs.PostUpdate, &render_bloom_h_system);
    // var render_bloom_system = @import("ecs/systems/render_bloom_pass.zig").system();
    // ecs.SYSTEM(world, "RenderBloomSystem", ecs.PostUpdate, &render_bloom_system);
    var render_final_system = @import("ecs/systems/render_final_pass.zig").system();
    ecs.SYSTEM(world, "RenderFinalSystem", ecs.PostUpdate, &render_final_system);

    const player_tile: components.Tile = .{ .x = 0, .y = -1, .counter = state.counter.count() };
    const player_cell: components.Cell = player_tile.toCell();

    for (player_cell.getAllSurrounding()) |cell| {
        state.map.loadCell(cell);
    }

    state.entities.player = ecs.new_entity(world, "Player");
    const player = state.entities.player;
    ecs.add(world, player, components.Player);
    _ = ecs.set(world, player, components.Position, player_tile.toPosition());
    _ = ecs.set(world, player, components.Tile, player_tile);
    _ = ecs.set(world, player, components.Collider, .{});
    _ = ecs.set(world, player, components.Inertia, .{});
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
        _ = ecs.set(world, campfire, components.SpriteRenderer, .{
            .index = assets.aftersun_atlas.Campfire_0_Layer_0,
            .reflect = true,
        });
        _ = ecs.set(world, campfire, components.SpriteAnimator, .{
            .state = .play,
            .animation = &animations.Campfire_Layer_0,
            .fps = 14,
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
                state.mouse.position = .{ @floatCast(mouse_motion.pos.x), @floatCast(mouse_motion.pos.y) };
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
                framebuffer_size[0] = @floatFromInt(size.width);
                framebuffer_size[1] = @floatFromInt(size.height);
                state.camera.frameBufferResize();
            },
            else => {},
        }
    }

    _ = ecs.progress(state.world, 0);

    const batcher_commands = try state.batcher.finish();
    defer batcher_commands.release();

    const encoder = core.device.createCommandEncoder(null);

    const compute_pass = encoder.beginComputePass(null);
    compute_pass.setPipeline(state.pipeline_bloom);
    compute_pass.setBindGroup(0, state.compute_constants, &.{});

    const width: u32 = settings.design_width;
    const height: u32 = settings.design_height;
    compute_pass.setBindGroup(1, state.bind_group_compute_0, &.{});
    compute_pass.dispatchWorkgroups(try std.math.divCeil(u32, width, gfx.block_dimension), try std.math.divCeil(u32, height, gfx.batch[1]), 1);

    compute_pass.setBindGroup(1, state.bind_group_compute_1, &.{});
    compute_pass.dispatchWorkgroups(try std.math.divCeil(u32, height, gfx.block_dimension), try std.math.divCeil(u32, width, gfx.batch[1]), 1);

    var i: u32 = 0;
    while (i < gfx.iterations - 1) : (i += 1) {
        compute_pass.setBindGroup(1, state.bind_group_compute_2, &.{});
        compute_pass.dispatchWorkgroups(try std.math.divCeil(u32, width, gfx.block_dimension), try std.math.divCeil(u32, height, gfx.batch[1]), 1);

        compute_pass.setBindGroup(1, state.bind_group_compute_1, &.{});
        compute_pass.dispatchWorkgroups(try std.math.divCeil(u32, height, gfx.block_dimension), try std.math.divCeil(u32, width, gfx.batch[1]), 1);
    }
    compute_pass.end();
    compute_pass.release();

    const command = encoder.finish(null);
    encoder.release();

    core.queue.submit(&.{ batcher_commands, command });
    core.swap_chain.present();

    for (state.hotkeys.hotkeys) |*hotkey| {
        hotkey.previous_state = hotkey.state;
    }

    for (state.mouse.buttons) |*button| {
        button.previous_state = button.state;
    }

    state.mouse.previous_position = state.mouse.position;

    // update the window title every second
    if (app.title_timer.read() >= 1.0) {
        app.title_timer.reset();
        try core.printTitle("Aftersun [ {d}fps ] [ Input {d}hz ]", .{
            core.frameRate(),
            core.inputRate(),
        });
    }

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
    //state.pipeline_bloom_h.release();
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
