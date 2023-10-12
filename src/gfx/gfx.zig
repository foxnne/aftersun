const std = @import("std");
const zmath = @import("zmath");
const core = @import("mach-core");
const gpu = core.gpu;
const game = @import("../aftersun.zig");

pub const utils = @import("utils.zig");

pub const Animation = @import("animation.zig").Animation;
pub const Atlas = @import("atlas.zig").Atlas;
pub const Sprite = @import("sprite.zig").Sprite;
pub const Quad = @import("quad.zig").Quad;
pub const Batcher = @import("batcher.zig").Batcher;
pub const Texture = @import("texture.zig").Texture;
pub const Camera = @import("camera.zig").Camera;

pub const Vertex = struct {
    position: [3]f32 = [_]f32{ 0.0, 0.0, 0.0 },
    uv: [2]f32 = [_]f32{ 0.0, 0.0 },
    color: [4]f32 = [_]f32{ 1.0, 1.0, 1.0, 1.0 },
    data: [3]f32 = [_]f32{ 0.0, 0.0, 0.0 },
};

pub const UniformBufferObject = struct {
    mvp: zmath.Mat,
};

pub const FinalUniformObject = @import("../ecs/systems/render_final_pass.zig").FinalUniforms;
pub const EnvironmentUniformObject = @import("../ecs/systems/render_environment_pass.zig").EnvironmentUniforms;

/// Initializes and creates all needed buffers, shaders, bind groups and pipelines.
pub fn init(state: *game.GameState) !void {
    const default_shader_module = core.device.createShaderModuleWGSL("default.wgsl", game.shaders.default);
    const diffuse_shader_module = core.device.createShaderModuleWGSL("diffuse.wgsl", game.shaders.diffuse);
    const environment_shader_module = core.device.createShaderModuleWGSL("environment.wgsl", game.shaders.environment);
    const final_shader_module = core.device.createShaderModuleWGSL("final.wgsl", game.shaders.final);
    const bloom_shader_module = core.device.createShaderModuleWGSL("bloom.wgsl", game.shaders.bloom);
    const bloom_h_shader_module = core.device.createShaderModuleWGSL("bloom_h.wgsl", game.shaders.bloom_h);
    const glow_shader_module = core.device.createShaderModuleWGSL("glow.wgsl", game.shaders.glow);
    const height_shader_module = core.device.createShaderModuleWGSL("height.wgsl", game.shaders.height);

    const vertex_attributes = [_]gpu.VertexAttribute{
        .{ .format = .float32x3, .offset = @offsetOf(Vertex, "position"), .shader_location = 0 },
        .{ .format = .float32x2, .offset = @offsetOf(Vertex, "uv"), .shader_location = 1 },
        .{ .format = .float32x4, .offset = @offsetOf(Vertex, "color"), .shader_location = 2 },
        .{ .format = .float32x3, .offset = @offsetOf(Vertex, "data"), .shader_location = 3 },
    };
    const vertex_buffer_layout = gpu.VertexBufferLayout.init(.{
        .array_stride = @sizeOf(Vertex),
        .step_mode = .vertex,
        .attributes = &vertex_attributes,
    });

    const blend = gpu.BlendState{
        .color = .{
            .operation = .add,
            .src_factor = .src_alpha,
            .dst_factor = .one_minus_src_alpha,
        },
        .alpha = .{
            .operation = .add,
            .src_factor = .src_alpha,
            .dst_factor = .one_minus_src_alpha,
        },
    };

    const color_target = gpu.ColorTargetState{
        .format = core.descriptor.format,
        .blend = &blend,
        .write_mask = gpu.ColorWriteMaskFlags.all,
    };

    const default_fragment = gpu.FragmentState.init(.{
        .module = default_shader_module,
        .entry_point = "frag_main",
        .targets = &.{color_target},
    });

    const default_vertex = gpu.VertexState.init(.{
        .module = default_shader_module,
        .entry_point = "vert_main",
        .buffers = &.{vertex_buffer_layout},
    });

    const diffuse_fragment = gpu.FragmentState.init(.{
        .module = diffuse_shader_module,
        .entry_point = "frag_main",
        .targets = &.{color_target},
    });

    const diffuse_vertex = gpu.VertexState.init(.{
        .module = diffuse_shader_module,
        .entry_point = "vert_main",
        .buffers = &.{vertex_buffer_layout},
    });

    const height_fragment = gpu.FragmentState.init(.{
        .module = height_shader_module,
        .entry_point = "frag_main",
        .targets = &.{color_target},
    });

    const environment_fragment = gpu.FragmentState.init(.{
        .module = environment_shader_module,
        .entry_point = "frag_main",
        .targets = &.{color_target},
    });

    const environment_vertex = gpu.VertexState.init(.{
        .module = environment_shader_module,
        .entry_point = "vert_main",
        .buffers = &.{vertex_buffer_layout},
    });

    const bloom_fragment = gpu.FragmentState.init(.{
        .module = bloom_shader_module,
        .entry_point = "frag_main",
        .targets = &.{color_target},
    });

    const bloom_h_fragment = gpu.FragmentState.init(.{
        .module = bloom_h_shader_module,
        .entry_point = "frag_main",
        .targets = &.{color_target},
    });

    const glow_fragment = gpu.FragmentState.init(.{
        .module = glow_shader_module,
        .entry_point = "frag_main",
        .targets = &.{color_target},
    });

    const final_fragment = gpu.FragmentState.init(.{
        .module = final_shader_module,
        .entry_point = "frag_main",
        .targets = &.{color_target},
    });

    const final_vertex = gpu.VertexState.init(.{
        .module = final_shader_module,
        .entry_point = "vert_main",
        .buffers = &.{vertex_buffer_layout},
    });

    const default_pipeline_descriptor = gpu.RenderPipeline.Descriptor{
        .fragment = &default_fragment,
        .vertex = default_vertex,
    };

    const diffuse_pipeline_descriptor = gpu.RenderPipeline.Descriptor{
        .fragment = &diffuse_fragment,
        .vertex = diffuse_vertex,
    };

    const height_pipeline_descriptor = gpu.RenderPipeline.Descriptor{
        .fragment = &height_fragment,
        .vertex = diffuse_vertex,
    };

    const glow_pipeline_descriptor = gpu.RenderPipeline.Descriptor{
        .fragment = &glow_fragment,
        .vertex = diffuse_vertex,
    };

    const bloom_pipeline_descriptor = gpu.RenderPipeline.Descriptor{
        .fragment = &bloom_fragment,
        .vertex = default_vertex,
    };

    const bloom_h_pipeline_descriptor = gpu.RenderPipeline.Descriptor{
        .fragment = &bloom_h_fragment,
        .vertex = default_vertex,
    };

    const environment_pipeline_descriptor = gpu.RenderPipeline.Descriptor{
        .fragment = &environment_fragment,
        .vertex = environment_vertex,
    };

    const final_pipeline_descriptor = gpu.RenderPipeline.Descriptor{
        .fragment = &final_fragment,
        .vertex = final_vertex,
    };

    state.pipeline_default = core.device.createRenderPipeline(&default_pipeline_descriptor);
    state.pipeline_diffuse = core.device.createRenderPipeline(&diffuse_pipeline_descriptor);
    state.pipeline_height = core.device.createRenderPipeline(&height_pipeline_descriptor);
    state.pipeline_environment = core.device.createRenderPipeline(&environment_pipeline_descriptor);
    state.pipeline_glow = core.device.createRenderPipeline(&glow_pipeline_descriptor);
    state.pipeline_bloom = core.device.createRenderPipeline(&bloom_pipeline_descriptor);
    state.pipeline_bloom_h = core.device.createRenderPipeline(&bloom_h_pipeline_descriptor);
    state.pipeline_final = core.device.createRenderPipeline(&final_pipeline_descriptor);

    state.uniform_buffer_default = core.device.createBuffer(&.{
        .usage = .{ .copy_dst = true, .uniform = true },
        .size = @sizeOf(UniformBufferObject),
        .mapped_at_creation = .false,
    });

    state.uniform_buffer_environment = core.device.createBuffer(&.{
        .usage = .{ .copy_dst = true, .uniform = true },
        .size = @sizeOf(EnvironmentUniformObject),
        .mapped_at_creation = .false,
    });

    state.uniform_buffer_final = core.device.createBuffer(&.{
        .usage = .{ .copy_dst = true, .uniform = true },
        .size = @sizeOf(FinalUniformObject),
        .mapped_at_creation = .false,
    });

    state.bind_group_default = core.device.createBindGroup(
        &gpu.BindGroup.Descriptor.init(.{
            .layout = state.pipeline_default.getBindGroupLayout(0),
            .entries = &.{
                gpu.BindGroup.Entry.buffer(0, state.uniform_buffer_default, 0, @sizeOf(UniformBufferObject)),
                gpu.BindGroup.Entry.textureView(1, state.diffusemap.view_handle),
                gpu.BindGroup.Entry.sampler(2, state.diffusemap.sampler_handle),
            },
        }),
    );

    state.bind_group_diffuse = core.device.createBindGroup(
        &gpu.BindGroup.Descriptor.init(.{
            .layout = state.pipeline_diffuse.getBindGroupLayout(0),
            .entries = &.{
                gpu.BindGroup.Entry.buffer(0, state.uniform_buffer_default, 0, @sizeOf(UniformBufferObject)),
                gpu.BindGroup.Entry.textureView(1, state.diffusemap.view_handle),
                gpu.BindGroup.Entry.textureView(2, state.palettemap.view_handle),
                gpu.BindGroup.Entry.sampler(3, state.diffusemap.sampler_handle),
            },
        }),
    );

    state.bind_group_height = core.device.createBindGroup(
        &gpu.BindGroup.Descriptor.init(.{
            .layout = state.pipeline_height.getBindGroupLayout(0),
            .entries = &.{
                gpu.BindGroup.Entry.buffer(0, state.uniform_buffer_default, 0, @sizeOf(UniformBufferObject)),
                gpu.BindGroup.Entry.textureView(1, state.heightmap.view_handle),
                gpu.BindGroup.Entry.textureView(2, state.diffusemap.view_handle),
                gpu.BindGroup.Entry.sampler(3, state.heightmap.sampler_handle),
            },
        }),
    );

    state.bind_group_light = core.device.createBindGroup(
        &gpu.BindGroup.Descriptor.init(.{
            .layout = state.pipeline_default.getBindGroupLayout(0),
            .entries = &.{
                gpu.BindGroup.Entry.buffer(0, state.uniform_buffer_default, 0, @sizeOf(UniformBufferObject)),
                gpu.BindGroup.Entry.textureView(1, state.lightmap.view_handle),
                gpu.BindGroup.Entry.sampler(2, state.lightmap.sampler_handle),
            },
        }),
    );

    state.bind_group_environment = core.device.createBindGroup(
        &gpu.BindGroup.Descriptor.init(.{
            .layout = state.pipeline_environment.getBindGroupLayout(0),
            .entries = &.{
                gpu.BindGroup.Entry.buffer(0, state.uniform_buffer_environment, 0, @sizeOf(EnvironmentUniformObject)),
                gpu.BindGroup.Entry.textureView(1, state.height_output.view_handle),
                gpu.BindGroup.Entry.sampler(2, state.height_output.sampler_handle),
                gpu.BindGroup.Entry.textureView(3, state.reverse_height_output.view_handle),
                gpu.BindGroup.Entry.textureView(4, state.light_output.view_handle),
            },
        }),
    );

    state.bind_group_glow = core.device.createBindGroup(
        &gpu.BindGroup.Descriptor.init(.{
            .layout = state.pipeline_diffuse.getBindGroupLayout(0),
            .entries = &.{
                gpu.BindGroup.Entry.buffer(0, state.uniform_buffer_default, 0, @sizeOf(UniformBufferObject)),
                gpu.BindGroup.Entry.textureView(1, state.height_output.view_handle),
                gpu.BindGroup.Entry.textureView(2, state.diffuse_output.view_handle),
                gpu.BindGroup.Entry.sampler(3, state.height_output.sampler_handle),
            },
        }),
    );

    state.bind_group_bloom_h = core.device.createBindGroup(
        &gpu.BindGroup.Descriptor.init(.{
            .layout = state.pipeline_default.getBindGroupLayout(0),
            .entries = &.{
                gpu.BindGroup.Entry.buffer(0, state.uniform_buffer_default, 0, @sizeOf(UniformBufferObject)),
                gpu.BindGroup.Entry.textureView(1, state.glow_output.view_handle),
                gpu.BindGroup.Entry.sampler(2, state.glow_output.sampler_handle),
            },
        }),
    );

    state.bind_group_bloom = core.device.createBindGroup(
        &gpu.BindGroup.Descriptor.init(.{
            .layout = state.pipeline_default.getBindGroupLayout(0),
            .entries = &.{
                gpu.BindGroup.Entry.buffer(0, state.uniform_buffer_default, 0, @sizeOf(UniformBufferObject)),
                gpu.BindGroup.Entry.textureView(1, state.bloom_h_output.view_handle),
                gpu.BindGroup.Entry.sampler(2, state.bloom_h_output.sampler_handle),
            },
        }),
    );

    state.bind_group_final = core.device.createBindGroup(
        &gpu.BindGroup.Descriptor.init(.{
            .layout = state.pipeline_final.getBindGroupLayout(0),
            .entries = &.{
                gpu.BindGroup.Entry.buffer(0, state.uniform_buffer_final, 0, @sizeOf(FinalUniformObject)),
                gpu.BindGroup.Entry.textureView(1, state.diffuse_output.view_handle),
                gpu.BindGroup.Entry.sampler(2, state.diffuse_output.sampler_handle),
                gpu.BindGroup.Entry.textureView(3, state.environment_output.view_handle),
                gpu.BindGroup.Entry.textureView(4, state.height_output.view_handle),
                gpu.BindGroup.Entry.textureView(5, state.glow_output.view_handle),
                gpu.BindGroup.Entry.textureView(6, state.reverse_height_output.view_handle),
                gpu.BindGroup.Entry.textureView(7, state.light_output.view_handle),
                gpu.BindGroup.Entry.textureView(8, state.bloom_output.view_handle),
                gpu.BindGroup.Entry.sampler(9, state.light_output.sampler_handle),
            },
        }),
    );
}
