struct EnvironmentUniforms {
    mvp: mat4x4<f32>,
    ambient_xy_angle: f32,
    ambient_z_angle: f32,
    shadow_color: vec3<f32>,
    shadow_steps: i32,
}
@group(0) @binding(0) var<uniform> uniforms: EnvironmentUniforms;

@group(0) @binding(1) var height_texture: texture_2d<f32>;
@group(0) @binding(2) var height_sampler: sampler;
@group(0) @binding(3) var reverse_height_texture: texture_2d<f32>;
@group(0) @binding(4) var light_texture: texture_2d<f32>;
@group(0) @binding(5) var light_sampler: sampler;

fn approx(a: f32, b: f32) -> bool {
    return abs(b-a) < 0.01;
}

// Finds the findTarget uv of the given step
fn findTarget(x_step: f32, y_step: f32, step: i32) -> vec2<f32> {
    let x_steps = cos(radians(uniforms.ambient_xy_angle)) * f32(step) * x_step;
    let y_steps = sin(radians(uniforms.ambient_xy_angle)) * f32(step) * y_step;

    return vec2(x_steps, y_steps);
}

// Finds the shadow color for the given uv
fn findShadow(x_step: f32, y_step: f32, uv: vec2<f32>, ambient_color: vec4<f32>) -> vec4<f32> {
    let light_color = textureSampleLevel(light_texture, height_sampler, uv, 0.0);
    let shadow_color = vec4(uniforms.shadow_color, 1.0) * ambient_color;
    let height_sample = textureSampleLevel(height_texture, height_sampler, uv, 0.0);
    let height = height_sample.r + (height_sample.g * 255.0);

    for(var i: i32 = 0; i < uniforms.shadow_steps; i++) {
        let other_uv = uv + findTarget(x_step, y_step, i);
        let distance = distance(other_uv, uv);
        var other_height_sample = textureSampleLevel(height_texture, height_sampler, other_uv, 0.0);
        var other_height = other_height_sample.r + (other_height_sample.g * 255.0);

        if (other_height > height) {
            let luminosity_ambient = dot(vec3(0.30, 0.59, 0.11), ambient_color.rgb);
            let luminosity_light = dot(vec3(0.30, 0.59, 0.11), light_color.rgb);
            let luminosity_difference = abs(luminosity_ambient - luminosity_light);
            let shadow_color_adjust = shadow_color + (1.0 - luminosity_difference) * light_color;
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

@stage(fragment) fn main(
    @location(0) uv: vec2<f32>,
    @location(1) color: vec4<f32>,
    @location(2) data: vec3<f32>,
) -> @location(0) vec4<f32> {
    
    let ambient_color = color;
    let tex_size = textureDimensions(height_texture);
    let tex_step_x = 1.0 / f32(tex_size.x);
    let tex_step_y = 1.0 / f32(tex_size.y);

    let shadow_color = findShadow(tex_step_x, tex_step_y, uv, ambient_color);

    return shadow_color;
}