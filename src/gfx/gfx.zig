const std = @import("std");
const zmath = @import("zmath");
const core = @import("mach-core");
const gpu = core.gpu;
const game = @import("../aftersun.zig");

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

// Constants from the blur.wgsl shader
pub const tile_dimension: u32 = 128;
pub const batch: [2]u32 = .{ 4, 4 };

// Currently hardcoded
pub const filter_size: u32 = 15;
pub const iterations: u32 = 2;
pub var block_dimension: u32 = tile_dimension - (filter_size - 1);

/// Initializes and creates all needed buffers, shaders, bind groups and pipelines.
pub fn init(state: *game.GameState) !void {
    const default_shader_module = core.device.createShaderModuleWGSL("default.wgsl", game.shaders.default);
    const diffuse_shader_module = core.device.createShaderModuleWGSL("diffuse.wgsl", game.shaders.diffuse);
    const environment_shader_module = core.device.createShaderModuleWGSL("environment.wgsl", game.shaders.environment);
    const final_shader_module = core.device.createShaderModuleWGSL("final.wgsl", game.shaders.final);
    // const bloom_shader_module = core.device.createShaderModuleWGSL("bloom.wgsl", game.shaders.bloom);
    // const bloom_h_shader_module = core.device.createShaderModuleWGSL("bloom_h.wgsl", game.shaders.bloom_h);
    const blur_shader_module = core.device.createShaderModuleWGSL("blur.wgsl", game.shaders.blur);
    const glow_shader_module = core.device.createShaderModuleWGSL("glow.wgsl", game.shaders.glow);
    const height_shader_module = core.device.createShaderModuleWGSL("height.wgsl", game.shaders.height);
    const post_shader_module = core.device.createShaderModuleWGSL("default.wgsl", game.shaders.post);

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

    const post_fragment = gpu.FragmentState.init(.{
        .module = post_shader_module,
        .entry_point = "frag_main",
        .targets = &.{color_target},
    });

    const post_vertex = gpu.VertexState.init(.{
        .module = post_shader_module,
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

    const bloom_pipeline_descriptor = gpu.ComputePipeline.Descriptor{
        .compute = gpu.ProgrammableStageDescriptor{
            .module = blur_shader_module,
            .entry_point = "main",
        },
    };

    const environment_pipeline_descriptor = gpu.RenderPipeline.Descriptor{
        .fragment = &environment_fragment,
        .vertex = environment_vertex,
    };

    const final_pipeline_descriptor = gpu.RenderPipeline.Descriptor{
        .fragment = &final_fragment,
        .vertex = final_vertex,
    };

    const post_pipeline_descriptor = gpu.RenderPipeline.Descriptor{
        .fragment = &post_fragment,
        .vertex = post_vertex,
    };

    state.pipeline_default = core.device.createRenderPipeline(&default_pipeline_descriptor);
    state.pipeline_diffuse = core.device.createRenderPipeline(&diffuse_pipeline_descriptor);
    state.pipeline_height = core.device.createRenderPipeline(&height_pipeline_descriptor);
    state.pipeline_environment = core.device.createRenderPipeline(&environment_pipeline_descriptor);
    state.pipeline_glow = core.device.createRenderPipeline(&glow_pipeline_descriptor);
    state.pipeline_bloom = core.device.createComputePipeline(&bloom_pipeline_descriptor);
    //state.pipeline_bloom_h = core.device.createRenderPipeline(&bloom_h_pipeline_descriptor);
    state.pipeline_final = core.device.createRenderPipeline(&final_pipeline_descriptor);
    state.pipeline_post = core.device.createRenderPipeline(&post_pipeline_descriptor);

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
                gpu.BindGroup.Entry.buffer(0, state.uniform_buffer_default, 0, @sizeOf(UniformBufferObject), 0),
                gpu.BindGroup.Entry.textureView(1, state.diffusemap.view_handle),
                gpu.BindGroup.Entry.sampler(2, state.diffusemap.sampler_handle),
            },
        }),
    );

    state.bind_group_reflection = core.device.createBindGroup(
        &gpu.BindGroup.Descriptor.init(.{
            .layout = state.pipeline_default.getBindGroupLayout(0),
            .entries = &.{
                gpu.BindGroup.Entry.buffer(0, state.uniform_buffer_default, 0, @sizeOf(UniformBufferObject), 0),
                gpu.BindGroup.Entry.textureView(1, state.reflection_output.view_handle),
                gpu.BindGroup.Entry.sampler(2, state.reflection_output.sampler_handle),
            },
        }),
    );

    state.bind_group_diffuse = core.device.createBindGroup(
        &gpu.BindGroup.Descriptor.init(.{
            .layout = state.pipeline_diffuse.getBindGroupLayout(0),
            .entries = &.{
                gpu.BindGroup.Entry.buffer(0, state.uniform_buffer_default, 0, @sizeOf(UniformBufferObject), 0),
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
                gpu.BindGroup.Entry.buffer(0, state.uniform_buffer_default, 0, @sizeOf(UniformBufferObject), 0),
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
                gpu.BindGroup.Entry.buffer(0, state.uniform_buffer_default, 0, @sizeOf(UniformBufferObject), 0),
                gpu.BindGroup.Entry.textureView(1, state.lightmap.view_handle),
                gpu.BindGroup.Entry.sampler(2, state.lightmap.sampler_handle),
            },
        }),
    );

    state.bind_group_environment = core.device.createBindGroup(
        &gpu.BindGroup.Descriptor.init(.{
            .layout = state.pipeline_environment.getBindGroupLayout(0),
            .entries = &.{
                gpu.BindGroup.Entry.buffer(0, state.uniform_buffer_environment, 0, @sizeOf(EnvironmentUniformObject), 0),
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
                gpu.BindGroup.Entry.buffer(0, state.uniform_buffer_default, 0, @sizeOf(UniformBufferObject), 0),
                gpu.BindGroup.Entry.textureView(1, state.height_output.view_handle),
                gpu.BindGroup.Entry.textureView(2, state.diffuse_output.view_handle),
                gpu.BindGroup.Entry.sampler(3, state.height_output.sampler_handle),
            },
        }),
    );

    const sampler = core.device.createSampler(&.{
        .mag_filter = .linear,
        .min_filter = .linear,
    });

    // the shader blurs the input texture in one direction,
    // depending on whether flip value is 0 or 1
    var flip: [2]*gpu.Buffer = undefined;
    for (flip, 0..) |_, i| {
        const buffer = core.device.createBuffer(&.{
            .usage = .{ .uniform = true },
            .size = @sizeOf(u32),
            .mapped_at_creation = .true,
        });

        const buffer_mapped = buffer.getMappedRange(u32, 0, 1);
        buffer_mapped.?[0] = @as(u32, @intCast(i));
        buffer.unmap();

        flip[i] = buffer;
    }

    const blur_params_buffer = core.device.createBuffer(&.{
        .size = 8,
        .usage = .{ .copy_dst = true, .uniform = true },
    });

    const blur_bind_group_layout0 = state.pipeline_bloom.getBindGroupLayout(0);
    const blur_bind_group_layout1 = state.pipeline_bloom.getBindGroupLayout(1);

    const compute_constants = core.device.createBindGroup(&gpu.BindGroup.Descriptor.init(.{
        .layout = blur_bind_group_layout0,
        .entries = &.{
            gpu.BindGroup.Entry.sampler(0, sampler),
            gpu.BindGroup.Entry.buffer(1, blur_params_buffer, 0, 8, 0),
        },
    }));

    const compute_bind_group_0 = core.device.createBindGroup(&gpu.BindGroup.Descriptor.init(.{
        .layout = blur_bind_group_layout1,
        .entries = &.{
            gpu.BindGroup.Entry.textureView(1, state.glow_output.view_handle),
            gpu.BindGroup.Entry.textureView(2, state.bloom_h_output.view_handle),
            gpu.BindGroup.Entry.buffer(3, flip[0], 0, 4, 0),
        },
    }));

    const compute_bind_group_1 = core.device.createBindGroup(&gpu.BindGroup.Descriptor.init(.{
        .layout = blur_bind_group_layout1,
        .entries = &.{
            gpu.BindGroup.Entry.textureView(1, state.bloom_h_output.view_handle),
            gpu.BindGroup.Entry.textureView(2, state.bloom_output.view_handle),
            gpu.BindGroup.Entry.buffer(3, flip[1], 0, 4, 0),
        },
    }));

    const compute_bind_group_2 = core.device.createBindGroup(&gpu.BindGroup.Descriptor.init(.{
        .layout = blur_bind_group_layout1,
        .entries = &.{
            gpu.BindGroup.Entry.textureView(1, state.bloom_output.view_handle),
            gpu.BindGroup.Entry.textureView(2, state.bloom_h_output.view_handle),
            gpu.BindGroup.Entry.buffer(3, flip[0], 0, 4, 0),
        },
    }));

    state.compute_constants = compute_constants;
    state.bind_group_compute_0 = compute_bind_group_0;
    state.bind_group_compute_1 = compute_bind_group_1;
    state.bind_group_compute_2 = compute_bind_group_2;

    blur_bind_group_layout0.release();
    blur_bind_group_layout1.release();
    sampler.release();
    flip[0].release();
    flip[1].release();

    const blur_params_buffer_data = [_]u32{ filter_size, block_dimension };
    core.queue.writeBuffer(blur_params_buffer, 0, &blur_params_buffer_data);

    state.bind_group_final = core.device.createBindGroup(
        &gpu.BindGroup.Descriptor.init(.{
            .layout = state.pipeline_final.getBindGroupLayout(0),
            .entries = &.{
                gpu.BindGroup.Entry.buffer(0, state.uniform_buffer_final, 0, @sizeOf(FinalUniformObject), 0),
                gpu.BindGroup.Entry.textureView(1, state.diffuse_output.view_handle),
                gpu.BindGroup.Entry.sampler(2, state.diffuse_output.sampler_handle),
                gpu.BindGroup.Entry.textureView(3, state.environment_output.view_handle),
                gpu.BindGroup.Entry.textureView(4, state.height_output.view_handle),
                gpu.BindGroup.Entry.textureView(5, state.glow_output.view_handle),
                gpu.BindGroup.Entry.textureView(6, state.reverse_height_output.view_handle),
                gpu.BindGroup.Entry.textureView(7, state.light_output.view_handle),
                gpu.BindGroup.Entry.textureView(8, state.bloom_output.view_handle),
                gpu.BindGroup.Entry.textureView(9, state.reflection_output.view_handle),
                gpu.BindGroup.Entry.sampler(10, state.light_output.sampler_handle),
            },
        }),
    );

    state.bind_group_post = core.device.createBindGroup(
        &gpu.BindGroup.Descriptor.init(.{
            .layout = state.pipeline_default.getBindGroupLayout(0),
            .entries = &.{
                gpu.BindGroup.Entry.buffer(0, state.uniform_buffer_default, 0, @sizeOf(UniformBufferObject), 0),
                gpu.BindGroup.Entry.textureView(1, state.final_output.view_handle),
                gpu.BindGroup.Entry.sampler(2, state.final_output.sampler_handle),
            },
        }),
    );
}
