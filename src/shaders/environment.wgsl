struct PackedVec3 { x: f32, y: f32, z: f32 };
struct EnvironmentUniforms {
    mvp: mat4x4<f32>,
    ambient_xy_angle: f32,
    ambient_z_angle: f32,
    padding1: f32,
    padding2: f32,
    shadow_color: PackedVec3,
    shadow_steps: i32,
}
@group(0) @binding(0) var<uniform> uniforms: EnvironmentUniforms;

struct VertexOut {
    @builtin(position) position_clip: vec4<f32>,
    @location(0) uv: vec2<f32>,
    @location(1) color: vec4<f32>,
    @location(2) data: vec3<f32>
}
@vertex fn vert_main(
    @location(0) position: vec3<f32>,
    @location(1) uv: vec2<f32>,
    @location(2) color: vec4<f32>,
    @location(3) data: vec3<f32>
) -> VertexOut {
    var output: VertexOut;
    output.position_clip = vec4(position, 1.0) * uniforms.mvp;
    output.uv = uv;
    output.color = color;
    output.data = data;
    return output;
}

@group(0) @binding(1) var height_texture: texture_2d<f32>;
@group(0) @binding(2) var height_sampler: sampler;
@group(0) @binding(3) var reverse_height_texture: texture_2d<f32>;
@group(0) @binding(4) var light_texture: texture_2d<f32>;

fn approx(a: f32, b: f32) -> bool {
    return abs(b-a) < 0.01;
}

// Finds the findTarget uv of the given step
fn findTarget(x_step: f32, y_step: f32, step: i32) -> vec2<f32> {
    var x_steps = cos(radians(uniforms.ambient_xy_angle)) * f32(step) * x_step;
    var y_steps = sin(radians(uniforms.ambient_xy_angle)) * f32(step) * y_step;

    return vec2(x_steps, y_steps);
}

// Finds the shadow color for the given uv
fn findShadow(x_step: f32, y_step: f32, uv: vec2<f32>, ambient_color: vec4<f32>) -> vec4<f32> {
    var light_color = textureSampleLevel(light_texture, height_sampler, uv, 0.0);
    var shadow_color = vec4(uniforms.shadow_color.x, uniforms.shadow_color.y, uniforms.shadow_color.z, 1.0) * ambient_color;
    var height_sample = textureSampleLevel(height_texture, height_sampler, uv, 0.0);
    var height = height_sample.r + (height_sample.g * 255.0);

    if (height_sample.b > 0.0) { return vec4(1.0); }

    for(var i: i32 = 0; i < uniforms.shadow_steps; i++) {
        var other_uv = uv + findTarget(x_step, y_step, i);
        var distance = distance(other_uv, uv);
        var other_height_sample = textureSampleLevel(height_texture, height_sampler, other_uv, 0.0);
        var other_height = other_height_sample.r + (other_height_sample.g * 255.0);

        if (other_height > height) {
            var luminosity_ambient = dot(vec3(0.30, 0.59, 0.11), ambient_color.rgb);
            var luminosity_light = dot(vec3(0.30, 0.59, 0.11), light_color.rgb);
            var luminosity_difference = abs(luminosity_ambient - luminosity_light);
            var shadow_color_adjust = shadow_color + (1.0 - luminosity_difference) * light_color;
            var trace_height = distance * tan(radians(uniforms.ambient_z_angle)) + height * 1.5;
            if (approx(trace_height, other_height)) {
                return shadow_color_adjust;
            } else {
                other_height_sample = textureSampleLevel(reverse_height_texture, height_sampler, other_uv, 0.0);
                other_height = other_height_sample.r + (other_height_sample.g * 255.0);

                if (other_height > height) {
                    trace_height = distance * tan(radians(uniforms.ambient_z_angle)) + height * 1.5;
                    if (approx(trace_height, other_height)) {
                        return shadow_color_adjust;
                    }
                }
            }
        }
    }
    return ambient_color + light_color;
}

@fragment fn frag_main(
    @location(0) uv: vec2<f32>,
    @location(1) color: vec4<f32>,
    @location(2) data: vec3<f32>,
) -> @location(0) vec4<f32> {
    
    var ambient_color = color;
    var tex_size = textureDimensions(height_texture);
    var tex_step_x = 1.0 / f32(tex_size.x);
    var tex_step_y = 1.0 / f32(tex_size.y);

    var shadow_color = findShadow(tex_step_x, tex_step_y, uv, ambient_color);

    return shadow_color;
}