const std = @import("std");
const zglfw = @import("zglfw");
const zgpu = @import("zgpu");
const wgpu = zgpu.wgpu;
const zgui = @import("zgui");
const zstbi = @import("zstbi");
const zm = @import("zmath");
const flecs = @import("flecs");

pub const name: [*:0]const u8 = @typeName(@This())[std.mem.lastIndexOf(u8, @typeName(@This()), ".").? + 1 ..];
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

const Counter = @import("tools/counter.zig").Counter;
const Prefabs = @import("ecs/prefabs/prefabs.zig");

// TODO: Find somewhere to keep track of the characters outfit and choices.
var top: u32 = 1;
var bottom: u32 = 1;

pub var state: *GameState = undefined;

/// Holds the global game state.
pub const GameState = struct {
    gctx: *zgpu.GraphicsContext,
    world: *flecs.EcsWorld,
    entities: Entities = undefined,
    prefabs: Prefabs,
    camera: gfx.Camera,
    controls: input.Controls = .{},
    time: time.Time = .{},
    environment: environment.Environment = .{},
    counter: Counter = .{},
    cells: std.AutoArrayHashMap(components.Cell, flecs.EcsEntity),
    output_channel: Channel = .final,
    pipeline_default: zgpu.RenderPipelineHandle = .{},
    pipeline_diffuse: zgpu.RenderPipelineHandle = .{},
    pipeline_height: zgpu.RenderPipelineHandle = .{},
    pipeline_environment: zgpu.RenderPipelineHandle = .{},
    pipeline_final: zgpu.RenderPipelineHandle = .{},
    bind_group_default: zgpu.BindGroupHandle,
    bind_group_diffuse: zgpu.BindGroupHandle,
    bind_group_height: zgpu.BindGroupHandle,
    bind_group_environment: zgpu.BindGroupHandle,
    bind_group_final: zgpu.BindGroupHandle,
    batcher: gfx.Batcher,
    diffusemap: gfx.Texture,
    palettemap: gfx.Texture,
    heightmap: gfx.Texture,
    diffuse_output: gfx.Texture,
    height_output: gfx.Texture,
    reverse_height_output: gfx.Texture,
    environment_output: gfx.Texture,
    atlas: gfx.Atlas,
};

pub const Channel = enum(i32) {
    final,
    diffuse,
    height,
    reverse_height,
    environment,
};

/// Holds global entities.
pub const Entities = struct {
    player: flecs.EcsEntity,
    debug: flecs.EcsEntity,
};

/// Registers all public declarations within the passed type
/// as components.
fn register(world: *flecs.EcsWorld, comptime T: type) void {
    const decls = @typeInfo(T).Struct.decls;
    inline for (decls) |decl| {
        if (decl.is_pub) {
            const Type = @field(T, decl.name);
            if (@TypeOf(T) == type) {
                flecs.ecs_component(world, Type);
            }
        }
    }
}

fn init(allocator: std.mem.Allocator, window: zglfw.Window) !*GameState {
    const world = flecs.ecs_init().?;
    register(world, components);
    const prefabs = Prefabs.init(world);

    const gctx = try zgpu.GraphicsContext.init(allocator, window);

    const batcher = try gfx.Batcher.init(allocator, gctx, settings.batcher_max_sprites);

    const atlas = try gfx.Atlas.initFromFile(std.heap.c_allocator, assets.aftersun_atlas.path);

    // Load game textures.
    const diffusemap = try gfx.Texture.initFromFile(gctx, assets.aftersun_png.path, .{});
    const palettemap = try gfx.Texture.initFromFile(gctx, assets.aftersun_palette_png.path, .{});
    const heightmap = try gfx.Texture.initFromFile(gctx, assets.aftersun_h_png.path, .{});

    // Create textures to render to.
    const diffuse_output = gfx.Texture.init(gctx, settings.design_width, settings.design_height, .{});
    const height_output = gfx.Texture.init(gctx, settings.design_width, settings.design_height, .{});
    const reverse_height_output = gfx.Texture.init(gctx, settings.design_width, settings.design_height, .{});
    const environment_output = gfx.Texture.init(gctx, settings.design_width, settings.design_height, .{});

    const window_size = gctx.window.getSize();
    var camera = gfx.Camera.init(settings.design_size, .{ .w = window_size.w, .h = window_size.h }, zm.f32x4(0, 0, 0, 0));

    // Build the default bind group.
    const bind_group_layout_default = gctx.createBindGroupLayout(&.{
        zgpu.bglBuffer(0, .{ .vertex = true }, .uniform, true, 0),
        zgpu.bglTexture(1, .{ .fragment = true }, .float, .tvdim_2d, false),
        zgpu.bglSampler(2, .{ .fragment = true }, .filtering),
    });
    defer gctx.releaseResource(bind_group_layout_default);

    const bind_group_default = gctx.createBindGroup(bind_group_layout_default, &[_]zgpu.BindGroupEntryInfo{
        .{ .binding = 0, .buffer_handle = gctx.uniforms.buffer, .offset = 0, .size = @sizeOf(gfx.Uniforms) },
        .{ .binding = 1, .texture_view_handle = diffusemap.view_handle },
        .{ .binding = 2, .sampler_handle = diffusemap.sampler_handle },
    });

    // Build the diffuse bind group.
    const bind_group_layout_diffuse = gctx.createBindGroupLayout(&.{
        zgpu.bglBuffer(0, .{ .vertex = true }, .uniform, true, 0),
        zgpu.bglTexture(1, .{ .fragment = true }, .float, .tvdim_2d, false),
        zgpu.bglSampler(2, .{ .fragment = true }, .filtering),
        zgpu.bglTexture(3, .{ .fragment = true }, .float, .tvdim_2d, false),
        zgpu.bglSampler(4, .{ .fragment = true }, .filtering),
    });
    defer gctx.releaseResource(bind_group_layout_diffuse);

    const bind_group_diffuse = gctx.createBindGroup(bind_group_layout_diffuse, &[_]zgpu.BindGroupEntryInfo{
        .{ .binding = 0, .buffer_handle = gctx.uniforms.buffer, .offset = 0, .size = @sizeOf(gfx.Uniforms) },
        .{ .binding = 1, .texture_view_handle = diffusemap.view_handle },
        .{ .binding = 2, .sampler_handle = diffusemap.sampler_handle },
        .{ .binding = 3, .texture_view_handle = palettemap.view_handle },
        .{ .binding = 4, .sampler_handle = palettemap.sampler_handle },
    });

    // Build the height bind group.
    const bind_group_height = gctx.createBindGroup(bind_group_layout_default, &[_]zgpu.BindGroupEntryInfo{
        .{ .binding = 0, .buffer_handle = gctx.uniforms.buffer, .offset = 0, .size = @sizeOf(gfx.Uniforms) },
        .{ .binding = 1, .texture_view_handle = heightmap.view_handle },
        .{ .binding = 2, .sampler_handle = heightmap.sampler_handle },
    });

    // Build the environment bind group.
    const bind_group_layout_environment = gctx.createBindGroupLayout(&.{
        zgpu.bglBuffer(0, .{ .vertex = true, .fragment = true }, .uniform, true, 0),
        zgpu.bglTexture(1, .{ .fragment = true }, .float, .tvdim_2d, false),
        zgpu.bglSampler(2, .{ .fragment = true }, .filtering),
        zgpu.bglTexture(3, .{ .fragment = true }, .float, .tvdim_2d, false),
        zgpu.bglSampler(4, .{ .fragment = true }, .filtering),
    });
    defer gctx.releaseResource(bind_group_layout_environment);

    const EnvironmentUniforms = @import("ecs/systems/render_environment_pass.zig").EnvironmentUniforms;
    const bind_group_environment = gctx.createBindGroup(bind_group_layout_environment, &[_]zgpu.BindGroupEntryInfo{
        .{ .binding = 0, .buffer_handle = gctx.uniforms.buffer, .offset = 0, .size = @sizeOf(EnvironmentUniforms) },
        .{ .binding = 1, .texture_view_handle = height_output.view_handle },
        .{ .binding = 2, .sampler_handle = height_output.sampler_handle },
        .{ .binding = 3, .texture_view_handle = reverse_height_output.view_handle },
        .{ .binding = 4, .sampler_handle = reverse_height_output.sampler_handle },
    });

    // Build the final bind group.
    const bind_group_layout_final = gctx.createBindGroupLayout(&.{
        zgpu.bglBuffer(0, .{ .vertex = true, .fragment = true }, .uniform, true, 0),
        zgpu.bglTexture(1, .{ .fragment = true }, .float, .tvdim_2d, false),
        zgpu.bglSampler(2, .{ .fragment = true }, .filtering),
        zgpu.bglTexture(3, .{ .fragment = true }, .float, .tvdim_2d, false),
        zgpu.bglSampler(4, .{ .fragment = true }, .filtering),
        zgpu.bglTexture(5, .{ .fragment = true }, .float, .tvdim_2d, false),
        zgpu.bglSampler(6, .{ .fragment = true }, .filtering),
        zgpu.bglTexture(7, .{ .fragment = true }, .float, .tvdim_2d, false),
        zgpu.bglSampler(8, .{ .fragment = true }, .filtering),
    });
    defer gctx.releaseResource(bind_group_layout_diffuse);

    const FinalUniforms = @import("ecs/systems/render_final_pass.zig").FinalUniforms;
    const bind_group_final = gctx.createBindGroup(bind_group_layout_final, &[_]zgpu.BindGroupEntryInfo{
        .{ .binding = 0, .buffer_handle = gctx.uniforms.buffer, .offset = 0, .size = @sizeOf(FinalUniforms) },
        .{ .binding = 1, .texture_view_handle = diffuse_output.view_handle },
        .{ .binding = 2, .sampler_handle = diffuse_output.sampler_handle },
        .{ .binding = 3, .texture_view_handle = environment_output.view_handle },
        .{ .binding = 4, .sampler_handle = environment_output.sampler_handle },
        .{ .binding = 5, .texture_view_handle = height_output.view_handle },
        .{ .binding = 6, .sampler_handle = height_output.sampler_handle },
        .{ .binding = 7, .texture_view_handle = reverse_height_output.view_handle },
        .{ .binding = 8, .sampler_handle = reverse_height_output.sampler_handle },
    });

    state = try allocator.create(GameState);
    state.* = .{
        .gctx = gctx,
        .world = world,
        .prefabs = prefabs,
        .camera = camera,
        .batcher = batcher,
        .cells = std.AutoArrayHashMap(components.Cell, flecs.EcsEntity).init(allocator),
        .atlas = atlas,
        .diffusemap = diffusemap,
        .palettemap = palettemap,
        .heightmap = heightmap,
        .diffuse_output = diffuse_output,
        .height_output = height_output,
        .reverse_height_output = reverse_height_output,
        .environment_output = environment_output,
        .bind_group_default = bind_group_default,
        .bind_group_diffuse = bind_group_diffuse,
        .bind_group_height = bind_group_height,
        .bind_group_environment = bind_group_environment,
        .bind_group_final = bind_group_final,
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
        gfx.utils.createPipelineAsync(allocator, bind_group_layout_default, .{
            .vertex_shader = shaders.diffuse_vs,
            .fragment_shader = shaders.height_fs,
        }, &state.pipeline_height);

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
    flecs.ecs_system(world, "CooldownSystem", flecs.Constants.EcsOnUpdate, &cooldown_system);

    // - Input
    var movement_drag_system = @import("ecs/systems/movement_drag.zig").system(world);
    flecs.ecs_system(world, "MovementDragSystem", flecs.Constants.EcsOnUpdate, &movement_drag_system);
    var movement_request_system = @import("ecs/systems/movement_request.zig").system();
    flecs.ecs_system(world, "MovementRequestSystem", flecs.Constants.EcsOnUpdate, &movement_request_system);

    // - Movement
    var movement_collision_system = @import("ecs/systems/movement_collision.zig").system(world);
    flecs.ecs_system(world, "MovementCollisionSystem", flecs.Constants.EcsOnUpdate, &movement_collision_system);
    var movement_system = @import("ecs/systems/movement.zig").system();
    flecs.ecs_system(world, "MovementSystem", flecs.Constants.EcsOnUpdate, &movement_system);
    var velocity_system = @import("ecs/systems/velocity.zig").system();
    flecs.ecs_system(world, "VelocitySystem", flecs.Constants.EcsOnUpdate, &velocity_system);

    // - Other
    var stack_system = @import("ecs/systems/stack.zig").system();
    flecs.ecs_system(world, "StackSystem", flecs.Constants.EcsOnUpdate, &stack_system);

    // - Observers
    var tile_observer = @import("ecs/observers/tile.zig").observer();
    flecs.ecs_observer(world, "TileObserver", &tile_observer);
    var stack_observer = @import("ecs/observers/stack.zig").observer();
    flecs.ecs_observer(world, "StackObserver", &stack_observer);

    // - Camera
    var camera_follow_system = @import("ecs/systems/camera_follow.zig").system();
    flecs.ecs_system(world, "CameraFollowSystem", flecs.Constants.EcsOnUpdate, &camera_follow_system);
    var camera_zoom_system = @import("ecs/systems/camera_zoom.zig").system();
    flecs.ecs_system(world, "CameraZoomSystem", flecs.Constants.EcsOnUpdate, &camera_zoom_system);

    // - Animation
    var animation_character_system = @import("ecs/systems/animation_character.zig").system();
    flecs.ecs_system(world, "AnimatorCharacterSystem", flecs.Constants.EcsOnUpdate, &animation_character_system);
    var animation_sprite_system = @import("ecs/systems/animation_sprite.zig").system();
    flecs.ecs_system(world, "AnimatorSpriteSystem", flecs.Constants.EcsOnUpdate, &animation_sprite_system);

    // - Render
    var render_culling_system = @import("ecs/systems/render_culling.zig").system();
    flecs.ecs_system(world, "RenderCullingSystem", flecs.Constants.EcsPostUpdate, &render_culling_system);
    var render_diffuse_system = @import("ecs/systems/render_diffuse_pass.zig").system();
    flecs.ecs_system(world, "RenderDiffuseSystem", flecs.Constants.EcsPostUpdate, &render_diffuse_system);
    var render_height_system = @import("ecs/systems/render_height_pass.zig").system();
    flecs.ecs_system(world, "RenderHeightSystem", flecs.Constants.EcsPostUpdate, &render_height_system);
    var render_reverse_height_system = @import("ecs/systems/render_reverse_height_pass.zig").system();
    flecs.ecs_system(world, "RenderReverseHeightSystem", flecs.Constants.EcsPostUpdate, &render_reverse_height_system);
    var render_environment_system = @import("ecs/systems/render_environment_pass.zig").system();
    flecs.ecs_system(world, "RenderEnvironmentSystem", flecs.Constants.EcsPostUpdate, &render_environment_system);
    var render_final_system = @import("ecs/systems/render_final_pass.zig").system();
    flecs.ecs_system(world, "RenderFinalSystem", flecs.Constants.EcsPostUpdate, &render_final_system);

    const player = flecs.ecs_new(world, components.Player);
    flecs.ecs_set(world, player, &components.Position{ .x = 0.0, .y = -32.0 });
    flecs.ecs_set(world, player, &components.Tile{ .x = 0, .y = -1, .counter = state.counter.count() });
    flecs.ecs_set(world, player, &components.Collider{});
    flecs.ecs_set(world, player, &components.Velocity{});
    flecs.ecs_set(world, player, &components.CharacterRenderer{
        .body_index = assets.aftersun_atlas.Idle_SE_0_Body,
        .head_index = assets.aftersun_atlas.Idle_SE_0_Head,
        .bottom_index = assets.aftersun_atlas.Idle_SE_0_BottomF02,
        .top_index = assets.aftersun_atlas.Idle_SE_0_TopF02,
        .hair_index = assets.aftersun_atlas.Idle_SE_0_HairF01,
        .body_color = math.Color.initBytes(5, 0, 0, 255),
        .head_color = math.Color.initBytes(5, 0, 0, 255),
        .bottom_color = math.Color.initBytes(2, 0, 0, 255),
        .top_color = math.Color.initBytes(3, 0, 0, 255),
        .hair_color = math.Color.initBytes(1, 0, 0, 255),
        .flip_head = true,
    });
    flecs.ecs_set(world, player, &components.CharacterAnimator{
        .head_set = animation_sets.head,
        .body_set = animation_sets.body,
        .top_set = animation_sets.top_f_02,
        .bottom_set = animation_sets.bottom_f_02,
        .hair_set = animation_sets.hair_f_01,
    });
    flecs.ecs_set_pair(world, player, &components.Direction{ .value = .none }, components.Movement);
    flecs.ecs_set_pair(world, player, &components.Direction{ .value = .se }, components.Head);
    flecs.ecs_set_pair(world, player, &components.Direction{ .value = .se }, components.Body);
    flecs.ecs_add_pair(world, player, components.Camera, components.Target);

    const debug = flecs.ecs_new(world, null);
    flecs.ecs_add_pair(world, debug, flecs.Constants.EcsIsA, state.prefabs.ham);
    flecs.ecs_set(world, debug, &components.Position{ .x = 0.0, .y = -64.0 });
    flecs.ecs_set(world, debug, &components.Tile{ .x = 0, .y = -2, .counter = state.counter.count() });

    const ham = flecs.ecs_new(world, null);
    flecs.ecs_add_pair(world, ham, flecs.Constants.EcsIsA, state.prefabs.ham);
    flecs.ecs_set(world, ham, &components.Position{ .x = 0.0, .y = -96.0 });
    flecs.ecs_set(world, ham, &components.Tile{ .x = 0, .y = -3, .counter = state.counter.count() });
    flecs.ecs_set(world, ham, &components.Stack{ .count = 3, .max = 5 });

    state.entities = .{ .player = player, .debug = debug };

    // Create campfire
    {
        const campfire = flecs.ecs_new_entity(world, "Campfire");
        flecs.ecs_set(world, campfire, &components.Position{ .x = 32.0, .y = -64.0 });
        flecs.ecs_set(world, campfire, &components.Tile{ .x = 1, .y = -2, .counter = state.counter.count() });
        flecs.ecs_set(world, campfire, &components.SpriteRenderer{ .index = assets.aftersun_atlas.Campfire_0_Layer_0 });
        flecs.ecs_set(world, campfire, &components.SpriteAnimator{
            .state = .play,
            .animation = &animations.Campfire_Layer_0,
            .fps = 16,
        });
        flecs.ecs_set(world, campfire, &components.Collider{ .trigger = true });
    }

    // Create first tree
    {
        const tree = flecs.ecs_new_entity(world, "Tree01");
        flecs.ecs_set(world, tree, &components.Position{});
        flecs.ecs_set(world, tree, &components.Tile{ .counter = state.counter.count() });
        flecs.ecs_set(world, tree, &components.SpriteRenderer{ .index = assets.aftersun_atlas.Oak_0_Trunk });
        flecs.ecs_set(world, tree, &components.Collider{});

        const leaf_color = math.Color.initBytes(16, 0, 0, 255);

        const tree_leaves_01 = flecs.ecs_new_entity(world, "TreeLeaves01");
        flecs.ecs_set(world, tree_leaves_01, &components.Position{});
        flecs.ecs_set(world, tree_leaves_01, &components.Tile{ .counter = state.counter.count() });
        flecs.ecs_set(world, tree_leaves_01, &components.SpriteRenderer{
            .index = assets.aftersun_atlas.Oak_0_Leaves04,
            .color = leaf_color,
            .frag_mode = .palette,
            .vert_mode = .top_sway,
        });

        const tree_leaves_02 = flecs.ecs_new_entity(world, "TreeLeaves02");
        flecs.ecs_set(world, tree_leaves_02, &components.Position{});
        flecs.ecs_set(world, tree_leaves_02, &components.Tile{ .counter = state.counter.count() });
        flecs.ecs_set(world, tree_leaves_02, &components.SpriteRenderer{
            .index = assets.aftersun_atlas.Oak_0_Leaves03,
            .color = leaf_color,
            .frag_mode = .palette,
            .vert_mode = .top_sway,
        });

        const tree_leaves_03 = flecs.ecs_new_entity(world, "TreeLeaves03");
        flecs.ecs_set(world, tree_leaves_03, &components.Position{});
        flecs.ecs_set(world, tree_leaves_03, &components.Tile{ .counter = state.counter.count() });
        flecs.ecs_set(world, tree_leaves_03, &components.SpriteRenderer{
            .index = assets.aftersun_atlas.Oak_0_Leaves02,
            .color = leaf_color,
            .frag_mode = .palette,
            .vert_mode = .top_sway,
        });

        const tree_leaves_04 = flecs.ecs_new_entity(world, "TreeLeaves04");
        flecs.ecs_set(world, tree_leaves_04, &components.Position{});
        flecs.ecs_set(world, tree_leaves_04, &components.Tile{ .counter = state.counter.count() });
        flecs.ecs_set(world, tree_leaves_04, &components.SpriteRenderer{
            .index = assets.aftersun_atlas.Oak_0_Leaves01,
            .color = leaf_color,
            .frag_mode = .palette,
            .vert_mode = .top_sway,
        });
    }

    // Create second tree
    {
        const position = components.Position{ .x = 64.0, .y = -32.0 };

        const tree = flecs.ecs_new_entity(world, "Tree02");
        flecs.ecs_set(world, tree, &position);
        flecs.ecs_set(world, tree, &position.toTile(state.counter.count()));
        flecs.ecs_set(world, tree, &components.SpriteRenderer{ .index = assets.aftersun_atlas.Oak_0_Trunk });
        flecs.ecs_set(world, tree, &components.Collider{});

        const leaf_color = math.Color.initBytes(16, 0, 0, 255);

        const tree_leaves_01 = flecs.ecs_new_w_pair(world, flecs.Constants.EcsChildOf, tree);
        flecs.ecs_set(world, tree_leaves_01, &position);
        flecs.ecs_set(world, tree_leaves_01, &position.toTile(state.counter.count()));
        flecs.ecs_set(world, tree_leaves_01, &components.SpriteRenderer{
            .index = assets.aftersun_atlas.Oak_0_Leaves04,
            .color = leaf_color,
            .frag_mode = .palette,
            .vert_mode = .top_sway,
        });

        const tree_leaves_02 = flecs.ecs_new_w_pair(world, flecs.Constants.EcsChildOf, tree);
        flecs.ecs_set(world, tree_leaves_02, &position);
        flecs.ecs_set(world, tree_leaves_02, &position.toTile(state.counter.count()));
        flecs.ecs_set(world, tree_leaves_02, &components.SpriteRenderer{
            .index = assets.aftersun_atlas.Oak_0_Leaves03,
            .color = leaf_color,
            .frag_mode = .palette,
            .vert_mode = .top_sway,
        });

        const tree_leaves_03 = flecs.ecs_new_w_pair(world, flecs.Constants.EcsChildOf, tree);
        flecs.ecs_set(world, tree_leaves_03, &position);
        flecs.ecs_set(world, tree_leaves_03, &position.toTile(state.counter.count()));
        flecs.ecs_set(world, tree_leaves_03, &components.SpriteRenderer{
            .index = assets.aftersun_atlas.Oak_0_Leaves02,
            .color = leaf_color,
            .frag_mode = .palette,
            .vert_mode = .top_sway,
        });

        const tree_leaves_04 = flecs.ecs_new_w_pair(world, flecs.Constants.EcsChildOf, tree);
        flecs.ecs_set(world, tree_leaves_04, &position);
        flecs.ecs_set(world, tree_leaves_04, &position.toTile(state.counter.count()));
        flecs.ecs_set(world, tree_leaves_04, &components.SpriteRenderer{
            .index = assets.aftersun_atlas.Oak_0_Leaves01,
            .color = leaf_color,
            .frag_mode = .palette,
            .vert_mode = .top_sway,
        });
    }

    // Create third tree
    {
        // Make sure its within another cell
        const position = components.Position{ .x = @intToFloat(f32, settings.cell_size + 2) * settings.pixels_per_unit, .y = 0.0 };

        const tree = flecs.ecs_new_entity(world, "Tree03");
        flecs.ecs_set(world, tree, &position);
        flecs.ecs_set(world, tree, &position.toTile(state.counter.count()));
        flecs.ecs_set(world, tree, &components.SpriteRenderer{ .index = assets.aftersun_atlas.Oak_0_Trunk });
        flecs.ecs_set(world, tree, &components.Collider{});

        const leaf_color = math.Color.initBytes(16, 0, 0, 255);

        const tree_leaves_01 = flecs.ecs_new_w_pair(world, flecs.Constants.EcsChildOf, tree);
        flecs.ecs_set(world, tree_leaves_01, &position);
        flecs.ecs_set(world, tree_leaves_01, &position.toTile(state.counter.count()));
        flecs.ecs_set(world, tree_leaves_01, &components.SpriteRenderer{
            .index = assets.aftersun_atlas.Oak_0_Leaves04,
            .color = leaf_color,
            .frag_mode = .palette,
            .vert_mode = .top_sway,
        });

        const tree_leaves_02 = flecs.ecs_new_w_pair(world, flecs.Constants.EcsChildOf, tree);
        flecs.ecs_set(world, tree_leaves_02, &position);
        flecs.ecs_set(world, tree_leaves_02, &position.toTile(state.counter.count()));
        flecs.ecs_set(world, tree_leaves_02, &components.SpriteRenderer{
            .index = assets.aftersun_atlas.Oak_0_Leaves03,
            .color = leaf_color,
            .frag_mode = .palette,
            .vert_mode = .top_sway,
        });

        const tree_leaves_03 = flecs.ecs_new_w_pair(world, flecs.Constants.EcsChildOf, tree);
        flecs.ecs_set(world, tree_leaves_03, &position);
        flecs.ecs_set(world, tree_leaves_03, &position.toTile(state.counter.count()));
        flecs.ecs_set(world, tree_leaves_03, &components.SpriteRenderer{
            .index = assets.aftersun_atlas.Oak_0_Leaves02,
            .color = leaf_color,
            .frag_mode = .palette,
            .vert_mode = .top_sway,
        });

        const tree_leaves_04 = flecs.ecs_new_w_pair(world, flecs.Constants.EcsChildOf, tree);
        flecs.ecs_set(world, tree_leaves_04, &position);
        flecs.ecs_set(world, tree_leaves_04, &position.toTile(state.counter.count()));
        flecs.ecs_set(world, tree_leaves_04, &components.SpriteRenderer{
            .index = assets.aftersun_atlas.Oak_0_Leaves01,
            .color = leaf_color,
            .frag_mode = .palette,
            .vert_mode = .top_sway,
        });
    }

    return state;
}

fn deinit(allocator: std.mem.Allocator) void {
    state.batcher.deinit();
    state.cells.deinit();
    state.gctx.deinit(allocator);
    allocator.destroy(state);
}

fn update() void {
    _ = flecs.ecs_progress(state.world, 0);

    zgui.backend.newFrame(state.gctx.swapchain_descriptor.width, state.gctx.swapchain_descriptor.height);

    //zgui.showDemoWindow(null);

    if (zgui.begin("Prefabs", .{})) {
        const prefab_names = std.meta.fieldNames(Prefabs);
        for (prefab_names) |n,i| {

            if (std.mem.indexOf(u8, n, "_")) |delimiter| {
                if (delimiter == 0) continue;
            }
            zgui.bulletText("{s}", .{n});

            if (zgui.isItemClicked(.left)) {
                if (flecs.ecs_get(state.world, state.entities.player, components.Tile)) |tile| {
                    if (flecs.ecs_get(state.world, state.entities.player, components.Position)) |position| {
                        const new = flecs.ecs_new_w_pair(state.world, flecs.Constants.EcsIsA, state.prefabs.get(i));
                        flecs.ecs_set(state.world, new, position);
                        flecs.ecs_set(state.world, new, tile);
                        flecs.ecs_set_pair_second(state.world, new, components.Request, &components.Movement{ .start = tile.*, .end = tile.*, .curve = .sin });
                        flecs.ecs_set_pair(state.world, new, &components.Cooldown{ .end = settings.movement_cooldown / 2}, components.Movement);
                    }
                }
            }
        }

        zgui.end();
    }

    if (zgui.begin("Game Settings", .{})) {
        zgui.bulletText(
            "Average :  {d:.3} ms/frame ({d:.1} fps)",
            .{ state.gctx.stats.average_cpu_time, state.gctx.stats.fps },
        );

        zgui.bulletText("Channel:", .{});
        if (zgui.radioButton("Final", .{ .active = state.output_channel == .final })) state.output_channel = .final;
        zgui.sameLine(.{});
        if (zgui.radioButton("Diffusemap", .{ .active = state.output_channel == .diffuse })) state.output_channel = .diffuse;
        if (zgui.radioButton("Heightmap", .{ .active = state.output_channel == .height })) state.output_channel = .height;
        zgui.sameLine(.{});
        if (zgui.radioButton("Reverse Heighmap", .{ .active = state.output_channel == .reverse_height })) state.output_channel = .reverse_height;
        if (zgui.radioButton("Environmentmap", .{ .active = state.output_channel == .environment })) state.output_channel = .environment;

        _ = zgui.sliderFloat("Cam zoom", .{ .v = &state.camera.zoom, .min = 0.1, .max = 10 });

        _ = zgui.sliderFloat("Timescale", .{ .v = &state.time.scale, .min = 0.1, .max = 2400.0 });
        zgui.bulletText("Day: {d:.4}, Hour: {d:.4}", .{ state.time.day(), state.time.hour() });
        zgui.bulletText("Phase: {s}, Next Phase: {s}", .{ state.environment.phase().name, state.environment.nextPhase().name });
        zgui.bulletText("Ambient XY Angle: {d:.4}", .{state.environment.ambientXYAngle()});
        zgui.bulletText("Ambient Z Angle: {d:.4}", .{state.environment.ambientZAngle()});

        zgui.bulletText("Movement Input: {s}", .{state.controls.movement().fmt()});

        if (flecs.ecs_get(state.world, state.entities.player, components.Velocity)) |velocity| {
            zgui.bulletText("Velocity: x: {d} y: {d}", .{ velocity.x, velocity.y });
        }

        if (flecs.ecs_get(state.world, state.entities.player, components.Tile)) |tile| {
            zgui.bulletText("Tile: x: {d}, y: {d}, z: {d}", .{ tile.x, tile.y, tile.z });
        }

        if (flecs.ecs_get_pair(state.world, state.entities.player, components.Cell, flecs.Constants.EcsWildcard)) |cell| {
            zgui.bulletText("Cell: x: {d}, y: {d}, z: {d}", .{ cell.x, cell.y, cell.z });
        }

        if (flecs.ecs_get_pair(state.world, state.entities.player, components.Direction, components.Movement)) |direction| {
            zgui.bulletText("Movement Direction: {s}", .{direction.value.fmt()});
        }

        if (flecs.ecs_get_pair(state.world, state.entities.player, components.Direction, components.Head)) |direction| {
            zgui.bulletText("Head Direction: {s}", .{direction.value.fmt()});
        }

        if (flecs.ecs_get_pair(state.world, state.entities.player, components.Direction, components.Body)) |direction| {
            zgui.bulletText("Body Direction: {s}", .{direction.value.fmt()});
        }

        if (flecs.ecs_get_mut(state.world, state.entities.player, components.Position)) |position| {
            var z = position.z;
            _ = zgui.sliderFloat("Height", .{ .v = &z, .min = 0.0, .max = 128.0 });
            position.z = z;
        }

        if (flecs.ecs_get_mut(state.world, state.entities.player, components.CharacterAnimator)) |animator| {
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
    // Gui pass.
    const encoder = state.gctx.device.createCommandEncoder(null);
    defer encoder.release();

    const back_buffer_view = state.gctx.swapchain.getCurrentTextureView();
    defer back_buffer_view.release();

    {
        const color_attachments = [_]wgpu.RenderPassColorAttachment{.{
            .view = back_buffer_view,
            .load_op = .load,
            .store_op = .store,
        }};
        const render_pass_info = wgpu.RenderPassDescriptor{
            .color_attachment_count = color_attachments.len,
            .color_attachments = &color_attachments,
        };
        const pass = encoder.beginRenderPass(render_pass_info);
        defer {
            pass.end();
            pass.release();
        }

        zgui.backend.draw(pass);
    }

    const batcher_commands = state.batcher.finish() catch unreachable;
    defer batcher_commands.release();

    const zgui_commands = encoder.finish(null);
    defer zgui_commands.release();

    state.gctx.submit(&.{ batcher_commands, zgui_commands });

    if (state.gctx.present() == .swap_chain_resized) {
        state.camera.setWindow(state.gctx.window);
    }
}

pub fn main() !void {
    try zglfw.init();
    defer zglfw.terminate();

    // Create window
    zglfw.defaultWindowHints();
    zglfw.windowHint(.cocoa_retina_framebuffer, 1);
    zglfw.windowHint(.client_api, 0);
    const window = try zglfw.createWindow(settings.design_width, settings.design_height, name, null, null);
    defer window.destroy();
    window.setSizeLimits(400, 400, -1, -1);

    // Set callbacks
    window.setCursorPosCallback(input.callbacks.cursor);
    window.setScrollCallback(input.callbacks.scroll);
    window.setKeyCallback(input.callbacks.key);
    window.setMouseButtonCallback(input.callbacks.button);

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    state = try init(allocator, window);
    defer deinit(allocator);

    const scale_factor = scale_factor: {
        const cs = window.getContentScale();
        break :scale_factor std.math.max(cs.x, cs.y);
    };

    zgui.init();
    defer zgui.deinit();

    zgui.io.setIniFilename(assets.root ++ "imgui.ini");

    _ = zgui.io.addFontFromFile(assets.root ++ "fonts/CozetteVector.ttf", settings.zgui_font_size * scale_factor);

    zgui.backend.init(window, state.gctx.device, @enumToInt(zgpu.GraphicsContext.swapchain_format));

    while (!window.shouldClose()) {
        zglfw.pollEvents();
        update();
        draw();
    }
}
