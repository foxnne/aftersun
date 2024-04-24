const std = @import("std");
const imgui = @import("zig-imgui");
const imgui_mach = imgui.backends.mach;
const build_options = @import("build-options");
const zmath = @import("zmath");
const core = @import("mach").core;
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
pub const filter_size: u32 = 10;
pub const iterations: u32 = 1;
pub var block_dimension: u32 = tile_dimension - (filter_size - 1);

/// Initializes and creates all needed buffers, shaders, bind groups and pipelines.
pub fn init(state: *game.GameState) !void {
    const default_shader_module = core.device.createShaderModuleWGSL("default.wgsl", game.shaders.default);
    const diffuse_shader_module = core.device.createShaderModuleWGSL("diffuse.wgsl", game.shaders.diffuse);
    const environment_shader_module = core.device.createShaderModuleWGSL("environment.wgsl", game.shaders.environment);
    const final_shader_module = core.device.createShaderModuleWGSL("final.wgsl", game.shaders.final);
    const blur_shader_module = core.device.createShaderModuleWGSL("blur.wgsl", game.shaders.blur);
    const glow_shader_module = core.device.createShaderModuleWGSL("glow.wgsl", game.shaders.glow);
    const height_shader_module = core.device.createShaderModuleWGSL("height.wgsl", game.shaders.height);
    const post_low_res_shader_module = core.device.createShaderModuleWGSL("post_low_res.wgsl", game.shaders.post_low_res);
    const post_high_res_shader_module = core.device.createShaderModuleWGSL("post_high_res.wgsl", game.shaders.post_high_res);

    defer default_shader_module.release();
    defer diffuse_shader_module.release();
    defer environment_shader_module.release();
    defer final_shader_module.release();
    defer blur_shader_module.release();
    defer glow_shader_module.release();
    defer height_shader_module.release();
    defer post_high_res_shader_module.release();
    defer post_low_res_shader_module.release();

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

    const post_low_res_fragment = gpu.FragmentState.init(.{
        .module = post_low_res_shader_module,
        .entry_point = "frag_main",
        .targets = &.{color_target},
    });

    const post_low_res_vertex = gpu.VertexState.init(.{
        .module = post_low_res_shader_module,
        .entry_point = "vert_main",
        .buffers = &.{vertex_buffer_layout},
    });

    const post_high_res_fragment = gpu.FragmentState.init(.{
        .module = post_high_res_shader_module,
        .entry_point = "frag_main",
        .targets = &.{color_target},
    });

    const post_high_res_vertex = gpu.VertexState.init(.{
        .module = post_high_res_shader_module,
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

    const post_low_res_pipeline_descriptor = gpu.RenderPipeline.Descriptor{
        .fragment = &post_low_res_fragment,
        .vertex = post_low_res_vertex,
    };

    const post_high_res_pipeline_descriptor = gpu.RenderPipeline.Descriptor{
        .fragment = &post_high_res_fragment,
        .vertex = post_high_res_vertex,
    };

    state.pipeline_default = core.device.createRenderPipeline(&default_pipeline_descriptor);
    state.pipeline_diffuse = core.device.createRenderPipeline(&diffuse_pipeline_descriptor);
    state.pipeline_height = core.device.createRenderPipeline(&height_pipeline_descriptor);
    state.pipeline_environment = core.device.createRenderPipeline(&environment_pipeline_descriptor);
    state.pipeline_glow = core.device.createRenderPipeline(&glow_pipeline_descriptor);
    state.pipeline_bloom = core.device.createComputePipeline(&bloom_pipeline_descriptor);
    state.pipeline_final = core.device.createRenderPipeline(&final_pipeline_descriptor);
    state.pipeline_post_low_res = core.device.createRenderPipeline(&post_low_res_pipeline_descriptor);
    state.pipeline_post_high_res = core.device.createRenderPipeline(&post_high_res_pipeline_descriptor);

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

    const pipeline_layout_default = state.pipeline_default.getBindGroupLayout(0);
    const pipeline_layout_diffuse = state.pipeline_diffuse.getBindGroupLayout(0);
    const pipeline_layout_height = state.pipeline_height.getBindGroupLayout(0);
    const pipeline_layout_environment = state.pipeline_environment.getBindGroupLayout(0);
    const pipeline_layout_final = state.pipeline_final.getBindGroupLayout(0);
    defer pipeline_layout_final.release();
    defer pipeline_layout_height.release();
    defer pipeline_layout_environment.release();
    defer pipeline_layout_default.release();
    defer pipeline_layout_diffuse.release();

    state.bind_group_default = core.device.createBindGroup(
        &gpu.BindGroup.Descriptor.init(.{
            .layout = pipeline_layout_default,
            .entries = &.{
                if (build_options.use_sysgpu)
                    gpu.BindGroup.Entry.buffer(0, state.uniform_buffer_default, 0, @sizeOf(UniformBufferObject), 0)
                else
                    gpu.BindGroup.Entry.buffer(0, state.uniform_buffer_default, 0, @sizeOf(UniformBufferObject)),
                gpu.BindGroup.Entry.textureView(1, state.diffusemap.view_handle),
                gpu.BindGroup.Entry.sampler(2, state.diffusemap.sampler_handle),
            },
        }),
    );

    state.bind_group_reflection = core.device.createBindGroup(
        &gpu.BindGroup.Descriptor.init(.{
            .layout = pipeline_layout_default,
            .entries = &.{
                if (build_options.use_sysgpu)
                    gpu.BindGroup.Entry.buffer(0, state.uniform_buffer_default, 0, @sizeOf(UniformBufferObject), 0)
                else
                    gpu.BindGroup.Entry.buffer(0, state.uniform_buffer_default, 0, @sizeOf(UniformBufferObject)),
                gpu.BindGroup.Entry.textureView(1, state.reflection_output.view_handle),
                gpu.BindGroup.Entry.sampler(2, state.reflection_output.sampler_handle),
            },
        }),
    );

    state.bind_group_diffuse = core.device.createBindGroup(
        &gpu.BindGroup.Descriptor.init(.{
            .layout = pipeline_layout_diffuse,
            .entries = &.{
                if (build_options.use_sysgpu)
                    gpu.BindGroup.Entry.buffer(0, state.uniform_buffer_default, 0, @sizeOf(UniformBufferObject), 0)
                else
                    gpu.BindGroup.Entry.buffer(0, state.uniform_buffer_default, 0, @sizeOf(UniformBufferObject)),
                gpu.BindGroup.Entry.textureView(1, state.diffusemap.view_handle),
                gpu.BindGroup.Entry.textureView(2, state.palettemap.view_handle),
                gpu.BindGroup.Entry.sampler(3, state.diffusemap.sampler_handle),
            },
        }),
    );

    state.bind_group_height = core.device.createBindGroup(
        &gpu.BindGroup.Descriptor.init(.{
            .layout = pipeline_layout_height,
            .entries = &.{
                if (build_options.use_sysgpu)
                    gpu.BindGroup.Entry.buffer(0, state.uniform_buffer_default, 0, @sizeOf(UniformBufferObject), 0)
                else
                    gpu.BindGroup.Entry.buffer(0, state.uniform_buffer_default, 0, @sizeOf(UniformBufferObject)),
                gpu.BindGroup.Entry.textureView(1, state.heightmap.view_handle),
                gpu.BindGroup.Entry.textureView(2, state.diffusemap.view_handle),
                gpu.BindGroup.Entry.sampler(3, state.heightmap.sampler_handle),
            },
        }),
    );

    state.bind_group_light = core.device.createBindGroup(
        &gpu.BindGroup.Descriptor.init(.{
            .layout = pipeline_layout_default,
            .entries = &.{
                if (build_options.use_sysgpu)
                    gpu.BindGroup.Entry.buffer(0, state.uniform_buffer_default, 0, @sizeOf(UniformBufferObject), 0)
                else
                    gpu.BindGroup.Entry.buffer(0, state.uniform_buffer_default, 0, @sizeOf(UniformBufferObject)),
                gpu.BindGroup.Entry.textureView(1, state.lightmap.view_handle),
                gpu.BindGroup.Entry.sampler(2, state.lightmap.sampler_handle),
            },
        }),
    );

    state.bind_group_environment = core.device.createBindGroup(
        &gpu.BindGroup.Descriptor.init(.{
            .layout = pipeline_layout_environment,
            .entries = &.{
                if (build_options.use_sysgpu)
                    gpu.BindGroup.Entry.buffer(0, state.uniform_buffer_environment, 0, @sizeOf(EnvironmentUniformObject), 0)
                else
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
            .layout = pipeline_layout_diffuse,
            .entries = &.{
                if (build_options.use_sysgpu)
                    gpu.BindGroup.Entry.buffer(0, state.uniform_buffer_default, 0, @sizeOf(UniformBufferObject), 0)
                else
                    gpu.BindGroup.Entry.buffer(0, state.uniform_buffer_default, 0, @sizeOf(UniformBufferObject)),
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
    defer blur_params_buffer.release();

    const blur_bind_group_layout0 = state.pipeline_bloom.getBindGroupLayout(0);
    const blur_bind_group_layout1 = state.pipeline_bloom.getBindGroupLayout(1);

    const compute_constants = core.device.createBindGroup(&gpu.BindGroup.Descriptor.init(.{
        .layout = blur_bind_group_layout0,
        .entries = &.{
            gpu.BindGroup.Entry.sampler(0, sampler),
            if (build_options.use_sysgpu) gpu.BindGroup.Entry.buffer(1, blur_params_buffer, 0, 8, 0) else gpu.BindGroup.Entry.buffer(1, blur_params_buffer, 0, 8),
        },
    }));

    const compute_bind_group_0 = core.device.createBindGroup(&gpu.BindGroup.Descriptor.init(.{
        .layout = blur_bind_group_layout1,
        .entries = &.{
            gpu.BindGroup.Entry.textureView(1, state.glow_output.view_handle),
            gpu.BindGroup.Entry.textureView(2, state.bloom_h_output.view_handle),
            if (build_options.use_sysgpu)
                gpu.BindGroup.Entry.buffer(3, flip[0], 0, 4, 0)
            else
                gpu.BindGroup.Entry.buffer(3, flip[0], 0, 4),
        },
    }));

    const compute_bind_group_1 = core.device.createBindGroup(&gpu.BindGroup.Descriptor.init(.{
        .layout = blur_bind_group_layout1,
        .entries = &.{
            gpu.BindGroup.Entry.textureView(1, state.bloom_h_output.view_handle),
            gpu.BindGroup.Entry.textureView(2, state.bloom_output.view_handle),
            if (build_options.use_sysgpu) gpu.BindGroup.Entry.buffer(3, flip[1], 0, 4, 0) else gpu.BindGroup.Entry.buffer(3, flip[1], 0, 4),
        },
    }));

    const compute_bind_group_2 = core.device.createBindGroup(&gpu.BindGroup.Descriptor.init(.{
        .layout = blur_bind_group_layout1,
        .entries = &.{
            gpu.BindGroup.Entry.textureView(1, state.bloom_output.view_handle),
            gpu.BindGroup.Entry.textureView(2, state.bloom_h_output.view_handle),
            if (build_options.use_sysgpu) gpu.BindGroup.Entry.buffer(3, flip[0], 0, 4, 0) else gpu.BindGroup.Entry.buffer(3, flip[0], 0, 4),
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
            .layout = pipeline_layout_final,
            .entries = &.{
                if (build_options.use_sysgpu)
                    gpu.BindGroup.Entry.buffer(0, state.uniform_buffer_final, 0, @sizeOf(FinalUniformObject), 0)
                else
                    gpu.BindGroup.Entry.buffer(0, state.uniform_buffer_final, 0, @sizeOf(FinalUniformObject)),
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

    state.bind_group_framebuffer = core.device.createBindGroup(
        &gpu.BindGroup.Descriptor.init(.{
            .layout = pipeline_layout_default,
            .entries = &.{
                if (build_options.use_sysgpu)
                    gpu.BindGroup.Entry.buffer(0, state.uniform_buffer_default, 0, @sizeOf(UniformBufferObject), 0)
                else
                    gpu.BindGroup.Entry.buffer(0, state.uniform_buffer_default, 0, @sizeOf(UniformBufferObject)),
                gpu.BindGroup.Entry.textureView(1, state.final_output.view_handle),
                gpu.BindGroup.Entry.sampler(2, state.final_output.sampler_handle),
            },
        }),
    );

    state.bind_group_post = core.device.createBindGroup(
        &gpu.BindGroup.Descriptor.init(.{
            .layout = pipeline_layout_default,
            .entries = &.{
                if (build_options.use_sysgpu)
                    gpu.BindGroup.Entry.buffer(0, state.uniform_buffer_default, 0, @sizeOf(UniformBufferObject), 0)
                else
                    gpu.BindGroup.Entry.buffer(0, state.uniform_buffer_default, 0, @sizeOf(UniformBufferObject)),
                gpu.BindGroup.Entry.textureView(1, state.framebuffer_output.view_handle),
                gpu.BindGroup.Entry.sampler(2, state.framebuffer_output.sampler_handle),
            },
        }),
    );

    imgui.setZigAllocator(&state.allocator);
    _ = imgui.createContext(null);
    try imgui_mach.init(state.allocator, core.device, .{
        .mag_filter = .nearest,
        .min_filter = .nearest,
        .mipmap_filter = .nearest,
    });

    var io = imgui.getIO();
    io.config_flags |= imgui.ConfigFlags_NavEnableKeyboard;
    io.font_global_scale = 1.0 / io.display_framebuffer_scale.y;
    var cozette_config: imgui.FontConfig = std.mem.zeroes(imgui.FontConfig);
    cozette_config.font_data_owned_by_atlas = true;
    cozette_config.oversample_h = 2;
    cozette_config.oversample_v = 1;
    cozette_config.glyph_max_advance_x = std.math.floatMax(f32);
    cozette_config.rasterizer_multiply = 1.0;
    cozette_config.rasterizer_density = 1.0;
    cozette_config.ellipsis_char = imgui.UNICODE_CODEPOINT_MAX;

    _ = io.fonts.?.addFontFromFileTTF(game.assets.root ++ "fonts/CozetteVector.ttf", game.settings.font_size * game.content_scale[1], &cozette_config, null);

    var fa_config: imgui.FontConfig = std.mem.zeroes(imgui.FontConfig);
    fa_config.merge_mode = true;
    fa_config.font_data_owned_by_atlas = true;
    fa_config.oversample_h = 2;
    fa_config.oversample_v = 1;
    fa_config.glyph_max_advance_x = std.math.floatMax(f32);
    fa_config.rasterizer_multiply = 1.0;
    fa_config.rasterizer_density = 1.0;
    fa_config.ellipsis_char = imgui.UNICODE_CODEPOINT_MAX;
    const ranges: []const u16 = &.{ 0xf000, 0xf976, 0 };

    state.fonts.fa_standard_solid = io.fonts.?.addFontFromFileTTF(game.assets.root ++ "fonts/fa-solid-900.ttf", game.settings.font_size * game.content_scale[1], &fa_config, @ptrCast(ranges.ptr)).?;
    state.fonts.fa_standard_regular = io.fonts.?.addFontFromFileTTF(game.assets.root ++ "fonts/fa-regular-400.ttf", game.settings.font_size * game.content_scale[1], &fa_config, @ptrCast(ranges.ptr)).?;

    var style = imgui.getStyle();
    style.window_rounding = 2.0;
    style.popup_rounding = 2.0;
    style.tab_rounding = 2.0;
    style.frame_rounding = 2.0;
    style.grab_rounding = 4.0;
    style.window_padding = .{ .x = 5.0, .y = 5.0 };
    style.item_spacing = .{ .x = 4.0, .y = 4.0 };
    style.item_inner_spacing = .{ .x = 3.0, .y = 3.0 };
    style.window_menu_button_position = 0;
    style.window_title_align = .{ .x = 0.0, .y = 0.5 };
    style.grab_min_size = 6.5;
    style.scrollbar_size = 12;
    style.frame_padding = .{ .x = 2.0, .y = 2.0 };
    style.hover_stationary_delay = 0.35;
    style.hover_delay_normal = 0.5;
    style.hover_delay_short = 0.25;
    style.separator_text_align = .{ .x = 0.2, .y = 0.5 };
    style.separator_text_border_size = 1.0;
    style.separator_text_padding = .{ .x = 20.0, .y = 10.0 };
    style.window_border_size = 0.0;
    style.frame_border_size = 0.0;
    style.tab_border_size = 0.0;
    style.child_border_size = 0.0;
    style.tab_bar_border_size = 0.0;

    const bg = game.settings.colors.background.toImguiVec4();
    const fg = game.settings.colors.foreground.toImguiVec4();
    const text = game.settings.colors.text.toImguiVec4();
    const bg_text = game.settings.colors.text_background.toImguiVec4();
    const highlight_primary = game.settings.colors.highlight_primary.toImguiVec4();
    const hover_primary = game.settings.colors.hover_primary.toImguiVec4();
    const highlight_secondary = game.settings.colors.highlight_secondary.toImguiVec4();
    _ = highlight_secondary; // autofix
    const hover_secondary = game.settings.colors.hover_secondary.toImguiVec4();
    _ = hover_secondary; // autofix

    style.colors[imgui.Col_WindowBg] = bg;
    style.colors[imgui.Col_Border] = bg;
    style.colors[imgui.Col_MenuBarBg] = text;
    style.colors[imgui.Col_Separator] = bg_text;
    style.colors[imgui.Col_TitleBg] = text;
    style.colors[imgui.Col_TitleBgActive] = text;
    style.colors[imgui.Col_Tab] = fg;
    style.colors[imgui.Col_TabUnfocused] = fg;
    style.colors[imgui.Col_TabUnfocusedActive] = fg;
    style.colors[imgui.Col_TabActive] = fg;
    style.colors[imgui.Col_TabHovered] = fg;
    style.colors[imgui.Col_PopupBg] = bg;
    style.colors[imgui.Col_FrameBg] = bg;
    style.colors[imgui.Col_FrameBgHovered] = bg;
    style.colors[imgui.Col_Text] = text;
    style.colors[imgui.Col_ResizeGrip] = highlight_primary;
    style.colors[imgui.Col_ScrollbarGrabActive] = highlight_primary;
    style.colors[imgui.Col_ScrollbarGrabHovered] = hover_primary;
    style.colors[imgui.Col_ScrollbarBg] = bg;
    style.colors[imgui.Col_ScrollbarGrab] = fg;
    style.colors[imgui.Col_Header] = text;
    style.colors[imgui.Col_HeaderHovered] = text;
    style.colors[imgui.Col_HeaderActive] = text;
    style.colors[imgui.Col_Button] = text;
    style.colors[imgui.Col_ButtonHovered] = text;
    style.colors[imgui.Col_ButtonActive] = text;
}
