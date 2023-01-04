struct FinalUniforms {
    mvp: mat4x4<f32>,
    output_channel: i32,
}
@group(0) @binding(0) var<uniform> uniforms: FinalUniforms;

@group(0) @binding(1) var diffuse: texture_2d<f32>;
@group(0) @binding(2) var diffuse_sampler: sampler;
@group(0) @binding(3) var environment: texture_2d<f32>;
@group(0) @binding(4) var height: texture_2d<f32>;
@group(0) @binding(5) var reverse_height: texture_2d<f32>;
@group(0) @binding(6) var light: texture_2d<f32>;
@group(0) @binding(7) var light_sampler: sampler;
@stage(fragment) fn main(
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
    } 
    
    return textureSample(diffuse, diffuse_sampler, uv) * textureSample(environment, diffuse_sampler, uv) * color;
}