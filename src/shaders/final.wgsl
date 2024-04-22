struct FinalUniforms {
    mvp: mat4x4<f32>,
    inverse_mvp: mat4x4<f32>,
    output_channel: i32,
    mouse: vec2<f32>,
}
@group(0) @binding(0) var<uniform> uniforms: FinalUniforms;

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
    output.position_clip = vec4(position.xy, 0.0, 1.0) * uniforms.mvp;
    output.uv = uv;
    output.color = color;
    output.data = data;
    return output;
}

@group(0) @binding(1) var diffuse: texture_2d<f32>;
@group(0) @binding(2) var diffuse_sampler: sampler;
@group(0) @binding(3) var environment: texture_2d<f32>;
@group(0) @binding(4) var height: texture_2d<f32>;
@group(0) @binding(5) var glow: texture_2d<f32>;
@group(0) @binding(6) var reverse_height: texture_2d<f32>;
@group(0) @binding(7) var light: texture_2d<f32>;
@group(0) @binding(8) var bloom: texture_2d<f32>;
@group(0) @binding(9) var reflection: texture_2d<f32>;
@group(0) @binding(10) var light_sampler: sampler;
@fragment fn frag_main(
    @location(0) uv: vec2<f32>,
    @location(1) color: vec4<f32>,
    @location(2) data: vec3<f32>,
) -> @location(0) vec4<f32> {
    if (uniforms.output_channel == 1) {
        return textureSample(diffuse, diffuse_sampler, uv);
    } else if (uniforms.output_channel == 2) {
        return textureSample(height, diffuse_sampler, uv);
    } else if ( uniforms.output_channel == 3) {
        return textureSample(reverse_height, diffuse_sampler, uv);
    } else if ( uniforms.output_channel == 4) {
        return textureSample(environment, diffuse_sampler, uv);
    } else if ( uniforms.output_channel == 5) {
        return textureSample(light, light_sampler, uv);
    } else if ( uniforms.output_channel == 6) {
        return textureSample(glow, diffuse_sampler, uv);
    } else if ( uniforms.output_channel == 7) {
        return textureSample(bloom, diffuse_sampler, uv);
    } 

    var diffuse = textureSample(diffuse, diffuse_sampler, uv);
    var reflection = textureSample(reflection, diffuse_sampler, uv) * (1.0 - diffuse.a);
    var environment = textureSample(environment, diffuse_sampler, uv);
    var bloom_mask = 1.0 - textureSample(height, diffuse_sampler, uv).bbbb;
    var bloom = textureSample(bloom, light_sampler, uv) * bloom_mask;

    var tex_size = textureDimensions(height);
    var tex_size_f32 = vec2(f32(tex_size.x), f32(tex_size.y));
    var tex_step_x = 1.0 / f32(tex_size.x);
    var tex_step_y = 1.0 / f32(tex_size.y);

    var bottom_uv = vec2(uv.x, uv.y + tex_step_y);
    var right_uv = vec2(uv.x + tex_step_x, uv.y);
    var left_uv = vec2(uv.x - tex_step_x, uv.y);

    var middle = textureSample(height, diffuse_sampler, uv);
    var bottom = textureSample(height, diffuse_sampler, bottom_uv);
    var right = textureSample(height, diffuse_sampler, right_uv);
    var left = textureSample(height, diffuse_sampler, left_uv);

    var highlight = vec4(0.0, 0.0, 0.0, 1.0 ); 
    var dist = abs(distance(uv, uniforms.mouse));

    var radius = 0.05 * data.z;
    
    if (dist < radius) {

        var bottom_check = bottom.r * 255.0 - middle.r * 255.0 >= 2.0;
        var left_check = left.r * 255.0 - middle.r * 255.0 >= 2.0;
        var right_check = right.r * 255.0 - middle.r * 255.0 >= 2.0;
    
        if (bottom_check || right_check || left_check) { 
            var fade = (1.0 - dist / radius ) * data.z;
            //highlight = environment * (1.0 - dist / radius ) * data.z;
            highlight = (vec4(255, 82, 83, 255) / vec4(255.0, 255.0, 255.0, 255.0)) * (environment + vec4(0.2, 0.2, 0.2, 1.0));
            return (highlight * fade) + ((reflection + diffuse * (1.0 - reflection.a)) * environment * color + bloom) * (1.0 - fade);
        } 
    }

    var render = (reflection + diffuse * (1.0 - reflection.a)) * environment * color + bloom;
    return render;
}
