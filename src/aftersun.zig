const std = @import("std");
const zglfw = @import("zglfw");
const zgpu = @import("zgpu");
const wgpu = zgpu.wgpu;
const zgui = @import("zgui");
const zstbi = @import("zstbi");
const zm = @import("zmath");
const ecs = @import("zflecs");

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

// TODO: Find somewhere to keep track of the characters outfit and choices.
var top: u32 = 1;
var bottom: u32 = 1;

pub var state: *GameState = undefined;

/// Holds the global game state.
pub const GameState = struct {
    allocator: std.mem.Allocator,
    gctx: *zgpu.GraphicsContext,
    world: *ecs.world_t,
    entities: Entities = .{},
    prefabs: Prefabs,
    camera: gfx.Camera,
    controls: input.Controls = .{},
    time: time.Time = .{},
    environment: environment.Environment = .{},
    counter: Counter = .{},
    cells: std.AutoArrayHashMap(components.Cell, ecs.entity_t),
    output_channel: Channel = .final,
    pipeline_default: zgpu.RenderPipelineHandle = .{},
    pipeline_diffuse: zgpu.RenderPipelineHandle = .{},
    pipeline_height: zgpu.RenderPipelineHandle = .{},
    pipeline_glow: zgpu.RenderPipelineHandle = .{},
    pipeline_bloom_h: zgpu.RenderPipelineHandle = .{},
    pipeline_bloom: zgpu.RenderPipelineHandle = .{},
    pipeline_environment: zgpu.RenderPipelineHandle = .{},
    pipeline_final: zgpu.RenderPipelineHandle = .{},
    bind_group_default: zgpu.BindGroupHandle,
    bind_group_diffuse: zgpu.BindGroupHandle,
    bind_group_height: zgpu.BindGroupHandle,
    bind_group_glow: zgpu.BindGroupHandle,
    bind_group_bloom_h: zgpu.BindGroupHandle,
    bind_group_bloom: zgpu.BindGroupHandle,
    bind_group_environment: zgpu.BindGroupHandle,
    bind_group_light: zgpu.BindGroupHandle,
    bind_group_final: zgpu.BindGroupHandle,
    batcher: gfx.Batcher,
    cursor_drag: *zglfw.Cursor,
    diffusemap: gfx.Texture,
    palettemap: gfx.Texture,
    heightmap: gfx.Texture,
    lightmap: gfx.Texture,
    diffuse_output: gfx.Texture,
    height_output: gfx.Texture,
    glow_output: gfx.Texture,
    bloom_h_output: gfx.Texture,
    bloom_output: gfx.Texture,
    reverse_height_output: gfx.Texture,
    environment_output: gfx.Texture,
    light_output: gfx.Texture,
    atlas: gfx.Atlas,
    light_atlas: gfx.Atlas,
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

/// Registers all public declarations within the passed type
/// as components.
fn register(world: *ecs.world_t, comptime T: type) void {
    const decls = comptime std.meta.declarations(T);
    inline for (decls) |decl| {
        const Type = @field(T, decl.name);
        if (@TypeOf(Type) == type) {
            if (@sizeOf(Type) > 0) {
                ecs.COMPONENT(world, Type);
            } else ecs.TAG(world, Type);
        }
    }
}

fn init(allocator: std.mem.Allocator, window: *zglfw.Window) !*GameState {
    const world = ecs.init();
    // Ensure that auto-generated IDs are well above anything we will need.
    ecs.set_entity_range(world, 8000, 0);

    register(world, components);

    //Create all of our prefabs.
    var prefabs = Prefabs.init(world);
    prefabs.create(world);

    const gctx = try zgpu.GraphicsContext.create(allocator, window, .{});

    var arena_state = std.heap.ArenaAllocator.init(allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    zstbi.init(arena);
    defer zstbi.deinit();

    const batcher = try gfx.Batcher.init(allocator, gctx, settings.batcher_max_sprites);

    const atlas = try gfx.Atlas.initFromFile(allocator, assets.aftersun_atlas.path);
    const light_atlas = try gfx.Atlas.initFromFile(allocator, assets.aftersun_lights_atlas.path);

    // Load game textures.
    const diffusemap = try gfx.Texture.loadFromFile(gctx, assets.aftersun_png.path, .{});
    const palettemap = try gfx.Texture.loadFromFile(gctx, assets.aftersun_palette_png.path, .{});
    const heightmap = try gfx.Texture.loadFromFile(gctx, assets.aftersun_h_png.path, .{});
    const lightmap = try gfx.Texture.loadFromFile(gctx, assets.aftersun_lights_png.path, .{
        .filter = wgpu.FilterMode.linear,
    });

    // Create textures to render to.
    const diffuse_output = gfx.Texture.init(gctx, settings.design_width, settings.design_height, .{});
    const height_output = gfx.Texture.init(gctx, settings.design_width, settings.design_height, .{});
    const glow_output = gfx.Texture.init(gctx, settings.design_width, settings.design_height, .{});
    const bloom_h_output = gfx.Texture.init(gctx, settings.design_width, settings.design_height, .{
        .filter = wgpu.FilterMode.linear,
    });
    const bloom_output = gfx.Texture.init(gctx, settings.design_width, settings.design_height, .{
        .filter = wgpu.FilterMode.linear,
    });
    const reverse_height_output = gfx.Texture.init(gctx, settings.design_width, settings.design_height, .{});
    const environment_output = gfx.Texture.init(gctx, settings.design_width, settings.design_height, .{});
    const light_output = gfx.Texture.init(gctx, settings.design_width, settings.design_height, .{
        .filter = wgpu.FilterMode.linear,
    });

    // Create cursors
    const cursor_drag = try zglfw.Cursor.createStandard(.hand);

    const window_size = gctx.window.getSize();
    var camera = gfx.Camera.init(settings.design_size, .{ .w = window_size[0], .h = window_size[1] }, zm.f32x4(0, 0, 0, 0));

    const bind_group_layout_default = gctx.createBindGroupLayout(&.{
        zgpu.bufferEntry(0, .{ .vertex = true }, .uniform, true, 0),
        zgpu.textureEntry(1, .{ .fragment = true }, .float, .tvdim_2d, false),
        zgpu.samplerEntry(2, .{ .fragment = true }, .filtering),
    });
    defer gctx.releaseResource(bind_group_layout_default);

    const bind_group_default = gctx.createBindGroup(bind_group_layout_default, &[_]zgpu.BindGroupEntryInfo{
        .{ .binding = 0, .buffer_handle = gctx.uniforms.buffer, .offset = 0, .size = @sizeOf(gfx.Uniforms) },
        .{ .binding = 1, .texture_view_handle = diffusemap.view_handle },
        .{ .binding = 2, .sampler_handle = diffusemap.sampler_handle },
    });

    const bind_group_light = gctx.createBindGroup(bind_group_layout_default, &[_]zgpu.BindGroupEntryInfo{
        .{ .binding = 0, .buffer_handle = gctx.uniforms.buffer, .offset = 0, .size = @sizeOf(gfx.Uniforms) },
        .{ .binding = 1, .texture_view_handle = lightmap.view_handle },
        .{ .binding = 2, .sampler_handle = lightmap.sampler_handle },
    });

    const bind_group_bloom_h = gctx.createBindGroup(bind_group_layout_default, &[_]zgpu.BindGroupEntryInfo{
        .{ .binding = 0, .buffer_handle = gctx.uniforms.buffer, .offset = 0, .size = @sizeOf(gfx.Uniforms) },
        .{ .binding = 1, .texture_view_handle = glow_output.view_handle },
        .{ .binding = 2, .sampler_handle = glow_output.sampler_handle },
    });

    const bind_group_bloom = gctx.createBindGroup(bind_group_layout_default, &[_]zgpu.BindGroupEntryInfo{
        .{ .binding = 0, .buffer_handle = gctx.uniforms.buffer, .offset = 0, .size = @sizeOf(gfx.Uniforms) },
        .{ .binding = 1, .texture_view_handle = bloom_h_output.view_handle },
        .{ .binding = 2, .sampler_handle = bloom_h_output.sampler_handle },
    });

    const bind_group_layout_diffuse = gctx.createBindGroupLayout(&.{
        zgpu.bufferEntry(0, .{ .vertex = true }, .uniform, true, 0),
        zgpu.textureEntry(1, .{ .fragment = true }, .float, .tvdim_2d, false),
        zgpu.textureEntry(2, .{ .fragment = true }, .float, .tvdim_2d, false),
        zgpu.samplerEntry(3, .{ .fragment = true }, .filtering),
    });
    defer gctx.releaseResource(bind_group_layout_diffuse);

    const bind_group_diffuse = gctx.createBindGroup(bind_group_layout_diffuse, &[_]zgpu.BindGroupEntryInfo{
        .{ .binding = 0, .buffer_handle = gctx.uniforms.buffer, .offset = 0, .size = @sizeOf(gfx.Uniforms) },
        .{ .binding = 1, .texture_view_handle = diffusemap.view_handle },
        .{ .binding = 2, .texture_view_handle = palettemap.view_handle },
        .{ .binding = 3, .sampler_handle = diffusemap.sampler_handle },
    });

    const bind_group_height = gctx.createBindGroup(bind_group_layout_diffuse, &[_]zgpu.BindGroupEntryInfo{
        .{ .binding = 0, .buffer_handle = gctx.uniforms.buffer, .offset = 0, .size = @sizeOf(gfx.Uniforms) },
        .{ .binding = 1, .texture_view_handle = heightmap.view_handle },
        .{ .binding = 2, .texture_view_handle = diffusemap.view_handle },
        .{ .binding = 3, .sampler_handle = heightmap.sampler_handle },
    });

    const bind_group_glow = gctx.createBindGroup(bind_group_layout_diffuse, &[_]zgpu.BindGroupEntryInfo{
        .{ .binding = 0, .buffer_handle = gctx.uniforms.buffer, .offset = 0, .size = @sizeOf(gfx.Uniforms) },
        .{ .binding = 1, .texture_view_handle = height_output.view_handle },
        .{ .binding = 2, .texture_view_handle = diffuse_output.view_handle },
        .{ .binding = 3, .sampler_handle = heightmap.sampler_handle },
    });

    const bind_group_layout_environment = gctx.createBindGroupLayout(&.{
        zgpu.bufferEntry(0, .{ .vertex = true, .fragment = true }, .uniform, true, 0),
        zgpu.textureEntry(1, .{ .fragment = true }, .float, .tvdim_2d, false),
        zgpu.samplerEntry(2, .{ .fragment = true }, .filtering),
        zgpu.textureEntry(3, .{ .fragment = true }, .float, .tvdim_2d, false),
        zgpu.textureEntry(4, .{ .fragment = true }, .float, .tvdim_2d, false),
        zgpu.samplerEntry(5, .{ .fragment = true }, .filtering),
    });
    defer gctx.releaseResource(bind_group_layout_environment);

    const EnvironmentUniforms = @import("ecs/systems/render_environment_pass.zig").EnvironmentUniforms;
    const bind_group_environment = gctx.createBindGroup(bind_group_layout_environment, &[_]zgpu.BindGroupEntryInfo{
        .{ .binding = 0, .buffer_handle = gctx.uniforms.buffer, .offset = 0, .size = @sizeOf(EnvironmentUniforms) },
        .{ .binding = 1, .texture_view_handle = height_output.view_handle },
        .{ .binding = 2, .sampler_handle = height_output.sampler_handle },
        .{ .binding = 3, .texture_view_handle = reverse_height_output.view_handle },
        .{ .binding = 4, .texture_view_handle = light_output.view_handle },
        .{ .binding = 5, .sampler_handle = light_output.sampler_handle },
    });

    const bind_group_layout_final = gctx.createBindGroupLayout(&.{
        zgpu.bufferEntry(0, .{ .vertex = true, .fragment = true }, .uniform, true, 0),
        zgpu.textureEntry(1, .{ .fragment = true }, .float, .tvdim_2d, false),
        zgpu.samplerEntry(2, .{ .fragment = true }, .filtering),
        zgpu.textureEntry(3, .{ .fragment = true }, .float, .tvdim_2d, false),
        zgpu.textureEntry(4, .{ .fragment = true }, .float, .tvdim_2d, false),
        zgpu.textureEntry(5, .{ .fragment = true }, .float, .tvdim_2d, false),
        zgpu.textureEntry(6, .{ .fragment = true }, .float, .tvdim_2d, false),
        zgpu.textureEntry(7, .{ .fragment = true }, .float, .tvdim_2d, false),
        zgpu.textureEntry(8, .{ .fragment = true }, .float, .tvdim_2d, false),
        zgpu.samplerEntry(9, .{ .fragment = true }, .filtering),
    });
    defer gctx.releaseResource(bind_group_layout_diffuse);

    const FinalUniforms = @import("ecs/systems/render_final_pass.zig").FinalUniforms;
    const bind_group_final = gctx.createBindGroup(bind_group_layout_final, &[_]zgpu.BindGroupEntryInfo{
        .{ .binding = 0, .buffer_handle = gctx.uniforms.buffer, .offset = 0, .size = @sizeOf(FinalUniforms) },
        .{ .binding = 1, .texture_view_handle = diffuse_output.view_handle },
        .{ .binding = 2, .sampler_handle = diffuse_output.sampler_handle },
        .{ .binding = 3, .texture_view_handle = environment_output.view_handle },
        .{ .binding = 4, .texture_view_handle = height_output.view_handle },
        .{ .binding = 5, .texture_view_handle = glow_output.view_handle },
        .{ .binding = 6, .texture_view_handle = reverse_height_output.view_handle },
        .{ .binding = 7, .texture_view_handle = light_output.view_handle },
        .{ .binding = 8, .texture_view_handle = bloom_output.view_handle },
        .{ .binding = 9, .sampler_handle = light_output.sampler_handle },
    });

    state = try allocator.create(GameState);
    state.* = .{
        .allocator = allocator,
        .gctx = gctx,
        .world = world,
        .prefabs = prefabs,
        .camera = camera,
        .batcher = batcher,
        .cells = std.AutoArrayHashMap(components.Cell, ecs.entity_t).init(allocator),
        .atlas = atlas,
        .light_atlas = light_atlas,
        .diffusemap = diffusemap,
        .palettemap = palettemap,
        .heightmap = heightmap,
        .lightmap = lightmap,
        .diffuse_output = diffuse_output,
        .height_output = height_output,
        .glow_output = glow_output,
        .bloom_h_output = bloom_h_output,
        .bloom_output = bloom_output,
        .reverse_height_output = reverse_height_output,
        .environment_output = environment_output,
        .light_output = light_output,
        .bind_group_default = bind_group_default,
        .bind_group_diffuse = bind_group_diffuse,
        .bind_group_height = bind_group_height,
        .bind_group_glow = bind_group_glow,
        .bind_group_bloom_h = bind_group_bloom_h,
        .bind_group_bloom = bind_group_bloom,
        .bind_group_environment = bind_group_environment,
        .bind_group_light = bind_group_light,
        .bind_group_final = bind_group_final,
        .cursor_drag = cursor_drag,
    };

    // Create render pipelines.
    {
        // (Async) Create default render pipeline.
        gfx.utils.createPipelineAsync(allocator, bind_group_layout_default, .{}, &state.pipeline_default);

        // (Async) Create diffuse render pipeline.
        gfx.utils.createPipelineAsync(allocator, bind_group_layout_diffuse, .{
            .vertex_shader = shaders.diffuse_vs,
            .fragment_shader = shaders.diffuse_fs,
        }, &state.pipeline_diffuse);

        // (Async) Create height render pipeline.
        gfx.utils.createPipelineAsync(allocator, bind_group_layout_diffuse, .{
            .vertex_shader = shaders.diffuse_vs,
            .fragment_shader = shaders.height_fs,
        }, &state.pipeline_height);

        // (Async) Create glow render pipeline.
        gfx.utils.createPipelineAsync(allocator, bind_group_layout_diffuse, .{
            .vertex_shader = shaders.diffuse_vs,
            .fragment_shader = shaders.glow_fs,
        }, &state.pipeline_glow);

        // (Async) Create bloom_h render pipeline.
        gfx.utils.createPipelineAsync(allocator, bind_group_layout_default, .{
            .vertex_shader = shaders.default_vs,
            .fragment_shader = shaders.bloom_h_fs,
        }, &state.pipeline_bloom_h);

        // (Async) Create bloom render pipeline.
        gfx.utils.createPipelineAsync(allocator, bind_group_layout_default, .{
            .vertex_shader = shaders.default_vs,
            .fragment_shader = shaders.bloom_fs,
        }, &state.pipeline_bloom);

        // (Async) Create environment render pipeline.
        gfx.utils.createPipelineAsync(allocator, bind_group_layout_environment, .{
            .vertex_shader = shaders.environment_vs,
            .fragment_shader = shaders.environment_fs,
        }, &state.pipeline_environment);

        // (Async) Create final render pipeline.
        gfx.utils.createPipelineAsync(allocator, bind_group_layout_final, .{
            .vertex_shader = shaders.final_vs,
            .fragment_shader = shaders.final_fs,
        }, &state.pipeline_final);
    }

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
    var inspect_system = @import("ecs/systems/inspect.zig").system();
    ecs.SYSTEM(world, "InspectSystem", ecs.OnUpdate, &inspect_system);
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
        .top_index = assets.aftersun_atlas.Idle_SE_0_TopF02,
        .hair_index = assets.aftersun_atlas.Idle_SE_0_HairF01,
        .body_color = math.Color.initBytes(5, 0, 0, 255).toSlice(),
        .head_color = math.Color.initBytes(5, 0, 0, 255).toSlice(),
        .bottom_color = math.Color.initBytes(2, 0, 0, 255).toSlice(),
        .top_color = math.Color.initBytes(3, 0, 0, 255).toSlice(),
        .hair_color = math.Color.initBytes(1, 0, 0, 255).toSlice(),
        .flip_head = true,
    });
    _ = ecs.set(world, player, components.CharacterAnimator, .{
        .head_set = animation_sets.head,
        .body_set = animation_sets.body,
        .top_set = animation_sets.top_f_02,
        .bottom_set = animation_sets.bottom_f_02,
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
            .offset = zm.f32x4(0, settings.pixels_per_unit / 1.5, 0, 0),
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

    return state;
}

fn deinit(allocator: std.mem.Allocator) void {
    // Remove all particle renderers so observer can free particles.
    ecs.remove_all(state.world, ecs.id(components.ParticleRenderer));

    allocator.free(state.atlas.sprites);
    allocator.free(state.atlas.animations);

    allocator.free(state.light_atlas.sprites);
    allocator.free(state.light_atlas.animations);

    state.batcher.deinit();
    state.cells.deinit();
    zgui.backend.deinit();
    zgui.deinit();
    state.gctx.destroy(allocator);
    allocator.destroy(state);
}

fn update() void {
    zgui.backend.newFrame(state.gctx.swapchain_descriptor.width, state.gctx.swapchain_descriptor.height);

    // Handle setting mouse cursor as with imgui we need to each frame.
    switch (state.controls.mouse.cursor) {
        .standard => {
            zgui.setMouseCursor(.arrow);
        },
        .drag => {
            zgui.setMouseCursor(.hand);
        },
    }

    _ = ecs.progress(state.world, 0);

    if (zgui.begin("Prefabs", .{})) {
        const prefab_names = comptime std.meta.fieldNames(Prefabs);
        inline for (prefab_names) |n| {
            if (n[0] != '_') {
                if (zgui.button(zgui.formatZ("{s}", .{n}), .{ .w = -1 })) {
                    if (ecs.get(state.world, state.entities.player, components.Tile)) |tile| {
                        if (ecs.get(state.world, state.entities.player, components.Position)) |position| {
                            const new = ecs.new_w_id(state.world, ecs.pair(ecs.IsA, ecs.lookup(state.world, n ++ &[_:0]u8{})));
                            _ = ecs.set(state.world, new, components.Position, position.*);
                            const end = tile.*;
                            const start: components.Tile = .{ .x = end.x, .y = end.y, .z = end.z + 1 };
                            _ = ecs.set(state.world, new, components.Tile, start);
                            _ = ecs.set_pair(state.world, new, ecs.id(components.Request), ecs.id(components.Movement), components.Movement, .{ .start = start, .end = end, .curve = .sin });
                            _ = ecs.set_pair(state.world, new, ecs.id(components.Cooldown), ecs.id(components.Movement), components.Cooldown, .{ .end = settings.movement_cooldown / 2 });
                        }
                    }
                }
            }
        }
    }
    zgui.end();

    if (zgui.begin("Game Settings", .{})) {
        zgui.bulletText(
            "Average :  {d:.3} ms/frame ({d:.1} fps)",
            .{ state.gctx.stats.average_cpu_time, state.gctx.stats.fps },
        );

        zgui.bulletText("Channel:", .{});
        if (zgui.radioButton("Final", .{ .active = state.output_channel == .final })) state.output_channel = .final;
        zgui.sameLine(.{});
        if (zgui.radioButton("Diffuse", .{ .active = state.output_channel == .diffuse })) state.output_channel = .diffuse;
        if (zgui.radioButton("Height##1", .{ .active = state.output_channel == .height })) state.output_channel = .height;
        zgui.sameLine(.{});
        if (zgui.radioButton("Reverse Height", .{ .active = state.output_channel == .reverse_height })) state.output_channel = .reverse_height;
        if (zgui.radioButton("Environment", .{ .active = state.output_channel == .environment })) state.output_channel = .environment;
        zgui.sameLine(.{});
        if (zgui.radioButton("Light", .{ .active = state.output_channel == .light })) state.output_channel = .light;
        if (zgui.radioButton("Glow", .{ .active = state.output_channel == .glow })) state.output_channel = .glow;
        zgui.sameLine(.{});
        if (zgui.radioButton("Bloom", .{ .active = state.output_channel == .bloom })) state.output_channel = .bloom;

        _ = zgui.sliderFloat("Timescale", .{ .v = &state.time.scale, .min = 0.1, .max = 2400.0 });
        zgui.bulletText("Day: {d:.4}, Hour: {d:.4}", .{ state.time.day(), state.time.hour() });
        zgui.bulletText("Phase: {s}, Next Phase: {s}", .{ state.environment.phase().name, state.environment.nextPhase().name });
        zgui.bulletText("Ambient XY Angle: {d:.4}", .{state.environment.ambientXYAngle()});
        zgui.bulletText("Ambient Z Angle: {d:.4}", .{state.environment.ambientZAngle()});

        zgui.bulletText("Movement Input: {s}", .{state.controls.movement().fmt()});

        if (ecs.get(state.world, state.entities.player, components.Velocity)) |velocity| {
            zgui.bulletText("Velocity: x: {d} y: {d}", .{ velocity.x, velocity.y });
        }

        if (ecs.get(state.world, state.entities.player, components.Tile)) |tile| {
            zgui.bulletText("Tile: x: {d}, y: {d}, z: {d}", .{ tile.x, tile.y, tile.z });
        }

        if (ecs.get_id(state.world, state.entities.player, ecs.pair(ecs.id(components.Cell), ecs.Wildcard))) |cell_ptr| {
            const cell = ecs.cast(components.Cell, cell_ptr);
            zgui.bulletText("Cell: x: {d}, y: {d}, z: {d}", .{ cell.x, cell.y, cell.z });
        }

        if (ecs.get_id(state.world, state.entities.player, ecs.pair(ecs.id(components.Direction), ecs.id(components.Movement)))) |direction_ptr| {
            const direction = ecs.cast(components.Direction, direction_ptr);
            zgui.bulletText("Movement Direction: {s}", .{direction.fmt()});
        }

        if (ecs.get_id(state.world, state.entities.player, ecs.pair(ecs.id(components.Direction), ecs.id(components.Head)))) |direction_ptr| {
            const direction = ecs.cast(components.Direction, direction_ptr);
            zgui.bulletText("Head Direction: {s}", .{direction.fmt()});
        }

        if (ecs.get_id(state.world, state.entities.player, ecs.pair(ecs.id(components.Direction), ecs.id(components.Body)))) |direction_ptr| {
            const direction = ecs.cast(components.Direction, direction_ptr);
            zgui.bulletText("Body Direction: {s}", .{direction.fmt()});
        }

        if (ecs.get_mut(state.world, state.entities.player, components.Position)) |position| {
            var z = position.z;
            _ = zgui.sliderFloat("Height##2", .{ .v = &z, .min = 0.0, .max = 128.0 });
            position.z = z;
        }

        if (ecs.get_mut(state.world, state.entities.player, components.CharacterAnimator)) |animator| {
            zgui.bulletText("Player Clothing:", .{});
            if (zgui.radioButton("TopF01", .{ .active = top == 0 })) {
                top = 0;
                animator.top_set = animation_sets.top_f_01;
            }
            zgui.sameLine(.{});
            if (zgui.radioButton("TopF02", .{ .active = top == 1 })) {
                top = 1;
                animator.top_set = animation_sets.top_f_02;
            }
            if (zgui.radioButton("BottomF01", .{ .active = bottom == 0 })) {
                bottom = 0;
                animator.bottom_set = animation_sets.bottom_f_01;
            }
            zgui.sameLine(.{});
            if (zgui.radioButton("BottomF02", .{ .active = bottom == 1 })) {
                bottom = 1;
                animator.bottom_set = animation_sets.bottom_f_02;
            }
        }
    }
    zgui.end();
}

fn draw() void {
    const swapchain_texv = state.gctx.swapchain.getCurrentTextureView();
    defer swapchain_texv.release();

    const zgui_commands = commands: {
        const encoder = state.gctx.device.createCommandEncoder(null);
        defer encoder.release();

        // Gui pass.
        {
            const pass = zgpu.beginRenderPassSimple(encoder, .load, swapchain_texv, null, null, null);
            defer zgpu.endReleasePass(pass);
            zgui.backend.draw(pass);
        }

        break :commands encoder.finish(null);
    };
    defer zgui_commands.release();

    const batcher_commands = state.batcher.finish() catch unreachable;
    defer batcher_commands.release();

    state.gctx.submit(&.{ batcher_commands, zgui_commands });

    if (state.gctx.present() == .swap_chain_resized) {
        state.camera.setWindow(state.gctx.window);
    }
}

pub fn main() !void {
    // Change current working directory to where the executable is located.
    {
        var buffer: [1024]u8 = undefined;
        const path = std.fs.selfExeDirPath(buffer[0..]) catch ".";
        std.os.chdir(path) catch {};
    }

    try zglfw.init();
    defer zglfw.terminate();

    // Create window
    const window = try zglfw.Window.create(settings.design_width, settings.design_height, name, null);
    defer window.destroy();
    window.setSizeLimits(400, 400, -1, -1);

    // Set callbacks
    _ = window.setCursorPosCallback(input.callbacks.cursor);
    _ = window.setScrollCallback(input.callbacks.scroll);
    _ = window.setKeyCallback(input.callbacks.key);
    _ = window.setMouseButtonCallback(input.callbacks.button);

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    state = try init(allocator, window);
    defer deinit(allocator);

    const scale_factor = scale_factor: {
        const scale = window.getContentScale();
        break :scale_factor @max(scale[0], scale[1]);
    };

    zgui.init(allocator);
    zgui.io.setIniFilename(assets.root ++ "imgui.ini");
    _ = zgui.io.addFontFromFile(assets.root ++ "fonts/CozetteVector.ttf", settings.zgui_font_size * scale_factor);
    zgui.backend.init(window, state.gctx.device, @intFromEnum(zgpu.GraphicsContext.swapchain_format));

    // TODO: Move GUI styling and color to its own file
    // Base style
    var style = zgui.getStyle();
    style.window_rounding = 10.0 * scale_factor;
    style.frame_rounding = 10.0 * scale_factor;
    style.window_padding = .{ 4.0 * scale_factor, 4.0 * scale_factor };
    style.item_spacing = .{ 4.0 * scale_factor, 4.0 * scale_factor };
    style.window_title_align = .{ 0.5, 0.5 };
    style.window_menu_button_position = zgui.Direction.none;

    const bg = math.Color.initBytes(225, 225, 225, 225).toSlice();
    const fg = math.Color.initBytes(245, 245, 245, 225).toSlice();
    const text = math.Color.initBytes(0, 0, 0, 225).toSlice();
    const text_disabled = math.Color.initBytes(80, 80, 80, 255).toSlice();

    // Base colors
    style.setColor(zgui.StyleCol.text, text);
    style.setColor(zgui.StyleCol.text_disabled, text_disabled);
    style.setColor(zgui.StyleCol.border, .{ 0.0, 0.0, 0.0, 0.0 });
    style.setColor(zgui.StyleCol.menu_bar_bg, bg);
    style.setColor(zgui.StyleCol.header, bg);
    style.setColor(zgui.StyleCol.title_bg, bg);
    style.setColor(zgui.StyleCol.title_bg_active, bg);
    style.setColor(zgui.StyleCol.window_bg, bg);
    style.setColor(zgui.StyleCol.frame_bg, .{ bg[0] * 0.8, bg[1] * 0.8, bg[2] * 0.8, 0.6 });
    style.setColor(zgui.StyleCol.frame_bg_hovered, .{ bg[0] * 0.6, bg[1] * 0.6, bg[2] * 0.6, 0.8 });
    style.setColor(zgui.StyleCol.frame_bg_active, .{ bg[0] * 0.6, bg[1] * 0.6, bg[2] * 0.6, 1.0 });
    style.setColor(zgui.StyleCol.button, fg);
    style.setColor(zgui.StyleCol.button_hovered, bg);
    style.setColor(zgui.StyleCol.button_active, .{ bg[0] * 0.8, bg[1] * 0.8, bg[2] * 0.8, 0.8 });
    style.setColor(zgui.StyleCol.slider_grab, text);
    style.setColor(zgui.StyleCol.slider_grab_active, text);
    style.setColor(zgui.StyleCol.child_bg, bg);
    style.setColor(zgui.StyleCol.resize_grip, text);
    style.setColor(zgui.StyleCol.resize_grip_active, text);
    style.setColor(zgui.StyleCol.resize_grip_hovered, text);
    style.setColor(zgui.StyleCol.check_mark, text);

    while (!window.shouldClose()) {
        zglfw.pollEvents();
        update();
        draw();
    }
}
